# Corsair NVMe Migration (ulysses)

**Status:** approved, not yet executed
**Scope:** move the `zpool` root pool from the Samsung 990 EVO Plus to the Corsair MP700 PRO XT, live, with no restore step.

This is spec 1 of 3. Spec 2 (`samsung-scratch-pool`) and spec 3 (`secure-boot-windows-dualboot`) are gated on this one landing and being proven.

## Context

| | Samsung 990 EVO Plus 4TB | Corsair MP700 PRO XT 4TB |
|---|---|---|
| Device | `/dev/nvme1n1` | `/dev/nvme0n1` |
| by-id | `nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D` | `nvme-Corsair_MP700_PRO_XT_AD27B6108002KO` |
| Total | 4,000,787,030,016 B | 4,000,787,030,016 B |
| State | live root pool | blank, no partition table |
| LBA | 512 B | 512 B (supports 4096 B, "Best") |

`zpool` is a **single-vdev** pool on `nvme1n1p2`, encrypted (`aes-256-gcm`, passphrase), `ashift=12`, 2.12T allocated. Bootloader is **Limine**, Secure Boot **disabled**, no TPM sealing — so the ESP is ordinary files on FAT, with no PCR policy to re-seal. Impermanence with root rollback is enabled: `/` is disposable, the payload is `/persist` (1.92T) and `/nix` (128G).

**There is no backup of `/persist`.** No sanoid, syncoid, restic, borg, or znapzend anywhere in the config. `zpool/safe` carries `com.sun:auto-snapshot=true` but nothing consumes the tag; the pool holds 3 snapshots, two of which are impermanence `@blank` anchors. This single fact drives every choice below.

## Approach

**Decision revised to fresh pool + `zfs send -Rw`** (see the implementation plan for the executable version). The original choice was `zpool attach` → resilver → `zpool detach`, and that is still the safer, simpler operation. It was abandoned for one reason: it caps ESP + swap at ~8.9 GiB (root must be ≥ the existing vdev), and the desired layout is **4 GiB ESP + 8 GiB swap = 12 GiB**, which only a fresh pool can accommodate. See the partition-budget note below for why 8 GiB swap is impossible under attach.

The fresh-pool approach:

- A raw replication stream (`zfs send -Rw`) carries every dataset, property, snapshot (`@blank`, `@premigrate`, `safe/hyperion-home`), and the **creation-time-immutable** `normalization=formD` — so faithfulness comes from the stream, not hand-recreation.
- **No single-copy window** provided the Samsung is not wiped: the new pool is populated while the Samsung stays live, and the Samsung is retained as `zpool-old` after cutover. (The original spec text overstated this as a mandatory drawback of send/recv; it is not.)
- The genuine risk is narrower than "immutable properties": raw-receiving an **encrypted pool-root** has mixed field reports. The plan neutralises it by performing the receive **live and reversibly** and gating on `zfs load-key` before any reboot — a failed receive costs nothing and the Samsung is untouched.
- Bonus: a fresh pool is born with current feature flags, so no later `zpool upgrade`.

Rejected alternatives:

- **`zpool attach` → resilver → `detach`.** Simpler and safer, and the recommendation until the 8 GiB swap requirement ruled it out. Preserved in git history as the fallback if the encrypted receive proves intractable.
- **`disko` destroy + restore.** Rules itself out. There is nothing to restore from.

## Partition budget (why attach was ruled out)

`zpool attach` refuses a device smaller than the existing vdev. The Samsung's root partition is **3,991,121,428,480 B**, so under attach:

```
4,000,787,030,016 − 3,991,121,428,480 = 9,665,601,536 B ≈ 9 GiB + 1.8 MiB
```

**Under attach, ESP + swap must fit in ~9 GiB**, with ~2 MiB consumed by GPT headers and alignment — so 8 GiB swap plus a 4 GiB ESP (12 GiB) is impossible, which is what forced the switch to a fresh pool. Under the fresh-pool approach the budget disappears: root only has to hold 1.49T, so **ESP 4 GiB + swap 8 GiB** fits with terabytes to spare.

Chosen: **ESP 4 GiB, swap 4 GiB** (8 GiB total). The new root lands ~1 GiB *larger* than the Samsung's, so the attach has margin rather than being byte-exact.

- The current 1 GiB ESP is already 55% full (557M/1022M) with Limine holding 10 kernel generations. Secure Boot (spec 3) adds signed artifacts. 4 GiB also fits UKIs should lanzaboote ever happen.
- Swap drops 8 GiB → 4 GiB at no cost: it is `randomEncryption`, so hibernation is already impossible, and the machine has 128 GiB of RAM.

## Phases

### Phase 0 — Pre-flight

```bash
zfs snapshot -r zpool@premigrate          # cheap, instant; guards fat-fingers, not disk loss
nvme list                                  # CONFIRM nvme0n1 is the Corsair
lsblk /dev/nvme0n1                         # CONFIRM no partitions
nvme format /dev/nvme0n1 --lbaf=1 --force  # 4Kn — destructive, now-or-never
nvme id-ns /dev/nvme0n1 -H | grep 'in use' # expect: Data Size: 4096 bytes
```

`nvme format` is irreversible and targets the wrong drive if `nvme0`/`nvme1` are transposed. **Verify the model string before running it.** 4Kn matches the pool's existing `ashift=12` (2¹² = 4096), so physical geometry and ZFS write size agree — which is not true on the Samsung today.

**Abort if:** `nvme0n1` shows any partition, or its model is not `Corsair MP700 PRO XT`.

### Phase 1 — Partition the Corsair (temporary labels)

Labels are deliberately *not* `disk-main-*`. Both drives share a machine, `/boot` and swap resolve through `/dev/disk/by-partlabel/`, and duplicate labels make those symlinks ambiguous — a clean route to an unbootable system.

```bash
sgdisk --zap-all /dev/nvme0n1
sgdisk -n 1:0:+4G -t 1:EF00 -c 1:mig-esp  /dev/nvme0n1
sgdisk -n 2:0:-4G -t 2:BF00 -c 2:mig-root /dev/nvme0n1
sgdisk -n 3:0:0   -t 3:8200 -c 3:mig-swap /dev/nvme0n1
partprobe /dev/nvme0n1
```

**Gate:** `lsblk -b -no SIZE /dev/nvme0n1p2` must be **≥ 3991121428480**. If not, the attach will fail — shrink swap and redo.

### Phase 2 — Attach and resilver

```bash
zpool attach zpool nvme-eui.0025385a51a3c872-part2 \
  /dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO-part2
zpool status zpool    # watch resilver
```

The pool becomes a 2-way mirror and copies 2.12T. Reads are gated by the Samsung, so this is not fast — irrelevant, because it runs live and nothing is blocked on it.

**Gate:** resilver completes with `0 errors` and no `DEGRADED` state before proceeding.

### Phase 3 — ESP, Limine, and the boot test

`/boot` resolves through `/dev/disk/by-partlabel/disk-main-ESP`. Rather than mounting the new ESP by hand — which would silently revert on the next boot, leaving the verification step inspecting the Samsung — **move the label**. Only the ESP labels are swapped here; `mig-root`/`mig-swap` vs `disk-main-root`/`disk-main-swap` are still distinct, so nothing else collides.

```bash
mkfs.vfat -F32 -n BOOT /dev/disk/by-partlabel/mig-esp
umount /boot
sgdisk -c 1:old-esp       /dev/nvme1n1   # Samsung ESP steps aside
sgdisk -c 1:disk-main-ESP /dev/nvme0n1   # Corsair ESP takes the name
partprobe /dev/nvme0n1 /dev/nvme1n1
mount /dev/disk/by-partlabel/disk-main-ESP /boot   # now the Corsair, and stays that way
nixos-rebuild boot                                 # installs Limine to the Corsair ESP
```

Renaming a GPT partition does not touch its contents. `canTouchEfiVariables = true`, so a firmware boot entry is created. Reboot; select the Corsair entry if the firmware does not prefer it.

The Samsung's ESP still holds its own Limine install and its own firmware boot entry (EFI entries reference partition **GUIDs**, not names), so it remains selectable as a fallback. The mirror is intact, so this reboot risks nothing.

**Gate:** `efibootmgr -v` confirms `BootCurrent` is the Corsair entry; `findmnt /boot` shows `nvme0n1p1`; `zpool status` still shows a healthy 2-way mirror. Do not proceed otherwise.

### Phase 4 — Detach, disambiguate, relabel

```bash
zpool detach zpool nvme-eui.0025385a51a3c872-part2
zpool import                            # ← READ THE OUTPUT. Verification gate.
```

After detach, the Samsung's partition still carries a ZFS label naming a pool `zpool`. If initrd's `zpool import zpool` sees two candidates, the machine may not boot. Rename the detached side rather than destroying it:

```bash
zpool import -N <guid-of-detached> zpool-old
zpool export zpool-old
```

This rewrites the Samsung's label to `zpool-old`, restoring unambiguity **while keeping a complete, importable copy of the system** — currently the only second copy of `/persist` in existence.

> **Unverified assumption.** That a detached mirror member imports cleanly under a new name is expected (detach leaves a self-consistent copy) but has not been confirmed on this hardware. The bare `zpool import` above is the check. If it reports the detached side as unimportable, stop and reassess before touching the Samsung — do not improvise.

Then resolve the remaining labels — root and swap; the ESPs were already swapped in Phase 3.

```bash
swapoff -a                                                       # frees disk-main-swap
sgdisk -c 2:old-root      -c 3:old-swap       /dev/nvme1n1        # non-destructive: GPT names only
sgdisk -c 2:disk-main-root -c 3:disk-main-swap /dev/nvme0n1
partprobe /dev/nvme0n1 /dev/nvme1n1
```

Renaming GPT partition names does not touch partition contents, so the Samsung stays bootable as a fallback.

After this, every `by-partlabel` path the running config references — `disk-main-ESP`, `disk-main-swap` — already resolves to the Corsair, with no config change. Swap is `randomEncryption`, so it is reformatted at boot and needs no `mkswap`.

### Phase 5 — Reconcile disko

`disko` never runs destructively here; it is updated to *describe* what was built, per the manual-first sequencing. Since Phase 4 already moved the labels, this change is declarative bookkeeping — it makes a from-scratch `disko` run reproduce the current disk.

In `systems/ulysses/disko-config.nix`:

- `device` → `/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO`
- ESP `size` → `4G`
- root `end` → `-4G`
- swap `size` → `100%` (unchanged; now resolves to 4G)

```bash
nixos-rebuild boot && reboot
```

**Gate:** clean boot, `findmnt /boot` on `nvme0n1p1`, `swapon --show` on `nvme0n1p3`, `zpool status` showing a single healthy vdev on the Corsair.

### Phase 6 — `zpool upgrade` (deferred, irreversible)

The pool reports *"some supported features are not enabled"*. After several days of clean boots:

```bash
zpool upgrade zpool
```

Deferred deliberately: upgrading forecloses importing the pool with older ZFS, which would complicate rolling back to an older NixOS generation. There is no urgency.

## What this spec does not do

The Samsung is left **intact and untouched** as `zpool-old`. It is not wiped, not repartitioned, not made into scratch. That is spec 2, and it is deliberately severed: beginning it destroys the fallback, so it must not start until the Corsair is genuinely proven.

## Rollback

| Failure point | Recovery |
|---|---|
| Phase 0–1 | Nothing has touched the Samsung. Re-zap the Corsair. |
| Phase 2 (bad Corsair) | `zpool detach` the *Corsair*. Pool is untouched. |
| Phase 3 (won't boot) | Select the Samsung ESP in firmware. Mirror is intact. |
| Phase 4–5 | Boot the Samsung ESP; `zpool import zpool-old`. Full system, as of detach. |
| After Phase 6 | `zpool-old` predates the upgrade and remains importable. |
