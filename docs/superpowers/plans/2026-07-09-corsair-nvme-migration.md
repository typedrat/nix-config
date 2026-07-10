# Corsair NVMe Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> ## ⚠ THIS PLAN IS NOT SUBAGENT-EXECUTABLE
>
> It runs `nvme format` and `zpool attach/detach` against the live root pool of a
> workstation with **no backup of `/persist`**. Three tasks require a physical
> reboot and reading a firmware boot menu. An agent cannot observe a POST screen,
> cannot select a firmware boot entry, and cannot recover a machine that fails to
> come up.
>
> **A human runs every command in this plan, at the console.** An agent may read
> it aloud, check outputs against the expected values, and refuse to advance a
> gate — nothing more.

**Goal:** Move the `zpool` root pool from the Samsung 990 EVO Plus to the Corsair MP700 PRO XT, live, with no restore step and no moment where only one copy of the data exists.

**Architecture:** `zpool attach` → resilver → `zpool detach`. ZFS's own resilver performs the copy, checksum-verifying every block. The pool retains its name, GUID, encryption root, and `ashift`. The Samsung is never wiped — after detach it is renamed `zpool-old` and kept as an intact, importable fallback.

**Tech Stack:** ZFS on root, disko (declarative, reconciled after the fact), Limine bootloader, impermanence with root rollback, NixOS unstable.

## Global Constraints

- **No backup of `/persist` exists.** 1.49T in exactly one place. Every gate below exists because of this.
- The Corsair root partition must be **≥ 3,991,121,428,480 bytes**, or `zpool attach` fails.
- ESP + swap must total **≤ 8 GiB**. Not 9: `4000787030016 − 9663676416 = 3991123353600`, which clears the threshold by only 1,925,120 bytes — less than GPT headers plus alignment. **9 GiB exactly fails.** Chosen: **ESP 4 GiB, swap 4 GiB.**
- ESP sizing is driven by initrd growth, not Secure Boot. Initrds are ~136 MiB and rising; `maxGenerations = 10` needs ~1.5 GiB transient during a rebuild. **The current 1 GiB ESP cannot hold 10 generations** — it holds 4 today at 55%. This migration incidentally fixes a latent `No space left on device` failure that would have struck around generation 7.
- Partition labels must be unique across both drives at all times. `/boot` and swap resolve through `/dev/disk/by-partlabel/`.
- Samsung by-id: `nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D` (`/dev/nvme1n1`)
- Corsair by-id: `nvme-Corsair_MP700_PRO_XT_AD27B6108002KO` (`/dev/nvme0n1`)
- Existing vdev name in `zpool status`: `nvme-eui.0025385a51a3c872-part2`
- **Never** run a destructive command without first re-confirming the device model string.

## Prerequisites (do not start without these)

- [x] A **NixOS live USB** exists and boots on this machine.
- [x] The **ZFS passphrase** for `zpool` is known and tested (you will type it at boot).
- [x] **No UPS — risk accepted, and it is bounded.** There is no point in this plan where power loss costs data: during Task 2 the Corsair is blank; during Task 4 the pool is a mirror with the Samsung holding a complete copy and ZFS resuming the resilver on reboot; after Task 6 the Samsung is importable as `zpool-old`.
- [ ] `~2 hours` of wall clock, of which the resilver (~1.69 TiB allocated) is unattended.
- [ ] Working tree is clean; you are on branch `typedrat/nvme-migration-specs`.

---

### Task 1: Capture baseline state

**Files:**
- Create: `/root/migration-baseline.txt` (scratch, not committed)

**Interfaces:**
- Produces: the detached-vdev GUID and partition geometry that Tasks 2, 5, and 6 depend on.

- [ ] **Step 1: Record everything that must be true again afterward**

```bash
{
  echo "=== date ==="; date
  echo "=== nvme list ==="; nvme list
  echo "=== lsblk bytes ==="; lsblk -b -o NAME,SIZE,MODEL,SERIAL,PARTLABEL,FSTYPE,MOUNTPOINT
  echo "=== zpool status ==="; zpool status zpool
  echo "=== zpool list -v -p ==="; zpool list -v -p zpool
  echo "=== zfs list ==="; zfs list
  echo "=== efibootmgr ==="; efibootmgr -v
  echo "=== findmnt /boot ==="; findmnt /boot
  echo "=== swapon ==="; swapon --show
} | tee /root/migration-baseline.txt
```

- [ ] **Step 2: Verify the three numbers this plan hard-codes**

```bash
lsblk -b -no SIZE /dev/nvme1n1p2   # expect exactly: 3991121428480
lsblk -b -no SIZE /dev/nvme1n1     # expect exactly: 4000787030016
lsblk -b -no SIZE /dev/nvme0n1     # expect exactly: 4000787030016
```

**ABORT if** any value differs. The partition budget arithmetic in this plan is derived from these exact bytes and is not self-correcting.

- [ ] **Step 3: Snapshot the pool**

```bash
zfs snapshot -r zpool@premigrate
zfs list -t snapshot | grep premigrate
```

Expected: one `@premigrate` line per dataset. This is instant and nearly free (copy-on-write). It guards against fat-fingers during the migration, **not** against disk loss.

---

### Task 2: Format the Corsair to 4Kn

**Files:** none — hardware operation.

**Interfaces:**
- Consumes: verified device identity from Task 1.
- Produces: `/dev/nvme0n1` with 4096-byte LBA, no partition table.

> `nvme format` is **irreversible** and destroys the wrong drive if `nvme0`/`nvme1` are transposed. `nvme0n1` is the *blank Corsair*. `nvme1n1` is your *live system*. Read the model string, out loud, before Step 3.

- [ ] **Step 1: Verify the target is the Corsair and is blank**

```bash
nvme id-ctrl /dev/nvme0n1 | grep -i '^mn'      # expect: Corsair MP700 PRO XT
lsblk /dev/nvme0n1                              # expect: NO partitions listed
```

**ABORT if** the model is not `Corsair MP700 PRO XT`, or any partition appears.

- [ ] **Step 2: Confirm 4Kn is offered**

```bash
nvme id-ns /dev/nvme0n1 -H | grep -i 'lba format'
```

Expected: `LBA Format 1 : ... Data Size: 4096 bytes - Relative Performance: 0 Best`

- [ ] **Step 3: Format**

```bash
nvme format /dev/nvme0n1 --lbaf=1 --force
```

- [ ] **Step 4: Verify the format took**

```bash
nvme id-ns /dev/nvme0n1 -H | grep 'in use'
```

Expected: `Data Size: 4096 bytes ... (in use)`

**ABORT if** still 512 bytes. 4Kn matches the pool's `ashift=12` (2¹² = 4096); proceeding at 512e is survivable but silently forfeits the alignment win, and this is the only moment it can be fixed.

---

### Task 3: Partition the Corsair with temporary labels

**Files:** none — partition table only.

**Interfaces:**
- Consumes: 4Kn-formatted `/dev/nvme0n1`.
- Produces: partlabels `mig-esp`, `mig-root`, `mig-swap`. Task 4 renames `mig-esp`; Task 6 renames the other two.

> Labels are deliberately **not** `disk-main-*`. The Samsung currently owns those names, and `/boot` and swap resolve through `/dev/disk/by-partlabel/`. Two partitions sharing a label makes those symlinks ambiguous — a clean route to an unbootable machine.

- [ ] **Step 1: Write the partition table**

```bash
sgdisk --zap-all /dev/nvme0n1
sgdisk -n 1:0:+4G -t 1:EF00 -c 1:mig-esp  /dev/nvme0n1
sgdisk -n 2:0:-4G -t 2:BF00 -c 2:mig-root /dev/nvme0n1
sgdisk -n 3:0:0   -t 3:8200 -c 3:mig-swap /dev/nvme0n1
partprobe /dev/nvme0n1
```

- [ ] **Step 2: Verify the attach threshold — this is the gate**

```bash
lsblk -b -no SIZE /dev/nvme0n1p2
```

Expected: a value **≥ 3991121428480** (should be ~3992195170304, about 1 GiB larger).

**ABORT if** smaller. `zpool attach` refuses a device below the existing vdev's size. Shrink swap and redo Step 1 rather than discovering this in Task 4.

- [ ] **Step 3: Verify labels are unique across both drives**

```bash
lsblk -o NAME,PARTLABEL /dev/nvme0n1 /dev/nvme1n1
ls -l /dev/disk/by-partlabel/
```

Expected: `mig-*` on nvme0n1, `disk-main-*` on nvme1n1, no duplicates, every symlink resolving to exactly one partition.

---

### Task 4: Attach and resilver

**Files:** none.

**Interfaces:**
- Consumes: `mig-root` from Task 3.
- Produces: `zpool` as a healthy 2-way mirror. Task 5 detaches from this state.

- [ ] **Step 1: Attach**

```bash
zpool attach zpool nvme-eui.0025385a51a3c872-part2 \
  /dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO-part2
```

- [ ] **Step 2: Watch the resilver**

```bash
watch -n 30 zpool status zpool
```

Reads are gated by the Samsung, so this is not fast. It runs live; keep using the machine. Expect tens of minutes for 2.12T.

- [ ] **Step 3: Verify the resilver completed clean — this is the gate**

```bash
zpool status zpool
```

Expected: `scan: resilvered ... with 0 errors`, both devices `ONLINE`, `errors: No known data errors`, **no** `DEGRADED`.

**ABORT if** any checksum error, any `DEGRADED` state, or a nonzero error count. Recovery: `zpool detach zpool <corsair-part2>` — the pool returns to exactly its prior state and nothing is lost. A Corsair that errors on first resilver is a Corsair to RMA.

---

### Task 5: Move the ESP and prove the Corsair boots

**Files:** none — GPT names and bootloader install.

**Interfaces:**
- Consumes: healthy mirror from Task 4.
- Produces: `/boot` on `nvme0n1p1`, Limine installed on the Corsair, Samsung ESP intact as `old-esp`.

> Do **not** mount the new ESP by hand and leave the config alone — `fileSystems."/boot".device` is `/dev/disk/by-partlabel/disk-main-ESP`, so it would silently revert to the Samsung on the next boot and you would verify the wrong ESP. Move the *label* instead. Only ESP labels swap here; `mig-root`/`mig-swap` vs `disk-main-root`/`disk-main-swap` remain distinct, so nothing collides.

- [ ] **Step 0: Create a durable fallback boot entry — DO THIS FIRST**

> The machine has **exactly one** EFI boot entry (`Boot0000* Limine`, on the Samsung ESP, partition GUID `1ecce9af-81f2-4cec-82c1-7fd8ab3108e9`). `nixos-rebuild boot` runs with `canTouchEfiVariables = true`; the Limine installer may **repoint that entry** at the Corsair. If it does, every "select the Samsung ESP in firmware" instruction in this plan becomes impossible to follow.
>
> Create a separately-labelled entry for the Samsung ESP *before* the installer can touch anything.

```bash
efibootmgr -v > /root/efibootmgr-before.txt
efibootmgr -c -d /dev/nvme1n1 -p 1 \
  -L "Limine (Samsung fallback)" \
  -l '\efi\limine\BOOTX64.EFI'
efibootmgr -v
```

**Verify:** `efibootmgr -v` lists **two** entries — the original `Limine` and the new `Limine (Samsung fallback)` — both pointing at partition GUID `1ecce9af-…`.

Now create the removable-media fallback, which **does not currently exist** on this machine. The ESP holds only `\EFI\limine\BOOTX64.EFI` and `\EFI\memtest86plus\mt86plus.efi`. Firmware one-shot boot menus offer `\EFI\BOOT\BOOTX64.EFI` unconditionally, with no NVRAM entry required — so without it, a cleared NVRAM (CMOS reset, dead battery, firmware update) leaves **neither** drive bootable.

```bash
install -D /boot/EFI/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
find /boot/EFI -iname '*.efi' -printf '%s\t%p\n' | sort -n
```

Limine locates `limine.conf` by searching the boot partition, including `/limine/`, so the copy boots the same menu. This is a 368 KB insurance policy against a failure mode the NVRAM entry cannot cover.

**Verify:** `\EFI\BOOT\BOOTX64.EFI` now exists at 368640 bytes.

**ABORT if** the fallback entry was not created, or `\EFI\BOOT\BOOTX64.EFI` is absent. Without at least one of these, a failed Corsair boot means live-USB recovery rather than picking a menu item.

- [ ] **Step 1: Make the filesystem**

```bash
mkfs.vfat -F32 -n BOOT /dev/disk/by-partlabel/mig-esp
```

- [ ] **Step 2: Swap the ESP labels — and check the fallback filesystem's health**

```bash
umount /boot || systemctl stop boot.mount
```

> The Samsung ESP contains `FSCK0000.REC` and `FSCK0001.REC` — orphaned-cluster files left by `fsck.vfat` after recovering a damaged FAT. This volume has been repaired at least twice. It is also the fallback that every ABORT gate in this plan depends on. Check it now, while it is unmounted and before it becomes load-bearing.

```bash
fsck.vfat -n /dev/nvme1n1p1        # read-only check; must be unmounted for a valid result
```

Expected: no errors beyond the known `FSCK*.REC` orphans. **ABORT if** it reports FAT damage, a bad boot sector, or cross-linked clusters — the fallback is not trustworthy, and the mirror should not be broken until you have a rescue path you believe in. Repair with `fsck.vfat -r` and re-verify before continuing.

```bash
sgdisk -c 1:old-esp       /dev/nvme1n1   # Samsung steps aside
sgdisk -c 1:disk-main-ESP /dev/nvme0n1   # Corsair takes the name
partprobe /dev/nvme0n1 /dev/nvme1n1
```

Renaming a GPT partition does not touch its contents. The Samsung's ESP keeps its Limine install and its firmware boot entry — EFI entries reference partition **GUIDs**, not names — so it stays selectable as a fallback.

- [ ] **Step 3: Verify the label now resolves to the Corsair**

```bash
readlink -f /dev/disk/by-partlabel/disk-main-ESP    # expect: /dev/nvme0n1p1
```

**ABORT if** it resolves to `nvme1n1p1`. Do not mount, do not rebuild.

- [ ] **Step 4: Mount and install Limine**

```bash
mount /dev/disk/by-partlabel/disk-main-ESP /boot
findmnt /boot                       # expect SOURCE /dev/nvme0n1p1
nixos-rebuild boot
```

- [ ] **Step 5: Confirm the fallback entry survived the rebuild**

```bash
diff /root/efibootmgr-before.txt <(efibootmgr -v)
efibootmgr -v | grep -i 'samsung fallback'
```

Expected: the `Limine (Samsung fallback)` entry is **still present** and still points at partition GUID `1ecce9af-…`. The other `Limine` entry may now point at the Corsair — that is fine and expected.

**ABORT if** the fallback entry is gone. Recreate it (Step 0) before rebooting. Do not reboot without it.

- [ ] **Step 6: Reboot and verify — this is the gate**

```bash
reboot
```

At the firmware menu, select the Corsair entry if the firmware does not prefer it. After boot:

```bash
efibootmgr -v | grep BootCurrent    # cross-reference against the Corsair entry
findmnt /boot                       # expect /dev/nvme0n1p1
zpool status zpool                  # expect healthy 2-way mirror, still
```

**ABORT if** the machine does not boot: at the firmware menu select **`Limine (Samsung fallback)`**. It is untouched, the mirror is intact, and nothing has been lost. Investigate before retrying.

---

### Task 6: Detach, disambiguate, relabel

**Files:** none.

**Interfaces:**
- Consumes: verified Corsair boot from Task 5.
- Produces: single-vdev `zpool` on the Corsair; Samsung relabeled `old-*` and renamed `zpool-old`.

- [ ] **Step 1: Detach the Samsung**

```bash
zpool detach zpool nvme-eui.0025385a51a3c872-part2
zpool status zpool                  # expect: single vdev, ONLINE, no mirror
```

- [ ] **Step 2: Read what the detached label actually says — this is the verification gate**

```bash
zpool import
```

> **This step exists because the plan's author could not verify the claim.** A detached mirror member is *expected* to be importable under a new name, since detach leaves a self-consistent copy. That expectation has not been confirmed on this hardware. **Read the actual output. Do not assume.**

Branch on what you see:

**Case A — a pool named `zpool` is listed** (with an `id:` GUID). Two pools now claim the name `zpool`; initrd's `zpool import zpool` may become ambiguous and fail to boot. Rename the detached side, keeping it fully intact.

The GUID is the number on the `id:` line of the `zpool import` output — the one whose vdev is `nvme1n1p2` (the Samsung), **not** the running pool. Capture it explicitly rather than retyping:

```bash
DETACHED_ID=$(zpool import 2>/dev/null | awk '/id:/{id=$2} /nvme1n1p2|old-root/{print id; exit}')
echo "$DETACHED_ID"                 # sanity-check: nonempty, and not the live pool's GUID
zpool status zpool | grep -i 'pool:' # the live pool, for contrast
```

Import it under a new name (`-N` skips mounting; the pool is encrypted and its datasets must not mount), then export so the rename is written back to the label:

```bash
zpool import -N "$DETACHED_ID" zpool-old
zpool export zpool-old
zpool import                        # expect: `zpool-old`, not `zpool`
```

**ABORT if** `$DETACHED_ID` is empty, or if `zpool import` still shows a second pool named `zpool` afterward. Booting with two `zpool` candidates is the failure this step exists to prevent.

**Case B — nothing is listed.** The detached label is not importable, so there is no ambiguity and no boot risk — but also **no fallback copy**. Stop. Do not proceed to Task 7 until you have decided whether to accept a single-copy system or to build a backup first.

**ABORT in any other case.** Do not improvise against 1.92T of unbacked-up data.

- [ ] **Step 3: Relabel root and swap (ESPs were already done in Task 5)**

```bash
swapoff -a
sgdisk -c 2:old-root       -c 3:old-swap       /dev/nvme1n1
sgdisk -c 2:disk-main-root -c 3:disk-main-swap /dev/nvme0n1
partprobe /dev/nvme0n1 /dev/nvme1n1
```

- [ ] **Step 4: Verify every label the running config depends on**

```bash
readlink -f /dev/disk/by-partlabel/disk-main-ESP    # expect /dev/nvme0n1p1
readlink -f /dev/disk/by-partlabel/disk-main-root   # expect /dev/nvme0n1p2
readlink -f /dev/disk/by-partlabel/disk-main-swap   # expect /dev/nvme0n1p3
ls /dev/disk/by-partlabel/                          # expect old-esp, old-root, old-swap too
```

Swap is `randomEncryption`, so it is reformatted at boot — no `mkswap` needed. Every `by-partlabel` path the running config references now points at the Corsair, with **no config change yet**.

---

### Task 7: Reconcile disko

**Files:**
- Modify: `systems/ulysses/disko-config.nix:10` (device), `:15` (ESP size), `:25` (root end)
- Modify: `systems/ulysses/default.nix` (add `zramSwap`)

**Interfaces:**
- Consumes: the on-disk layout built in Tasks 3–6.
- Produces: a disko config that reproduces the current disk from scratch.

> **Why `zramSwap`:** the partition shrinks 8 GiB → 4 GiB, but peak observed swap residency was 4.7 GiB. Compressed in-RAM swap absorbs the 0.7 GiB shortfall. The underlying cause of the swapping is an effectively-uncapped `zfs_arc_max` (`c_max` ≈ 122 GiB of 123 GiB RAM), which lets ARC crowd out anonymous pages. **Capping ARC is deliberately out of scope** — it is a separate change with its own reboot, and stacking it on a disk migration would confound any failure.

> `disko` is **not run destructively** here. This edit makes the declarative config *describe* what was built by hand, per the manual-first sequencing chosen during design.

- [ ] **Step 1: Edit the config**

```nix
main = {
  type = "disk";
  device = "/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO";
  content = {
    type = "gpt";
    partitions = {
      ESP = {
        size = "4G";
        type = "EF00";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = ["umask=0077"];
        };
      };
      root = {
        end = "-4G";
        content = {
          type = "zfs";
          pool = "zpool";
        };
      };
      swap = {
        size = "100%";
        content = {
          type = "swap";
          randomEncryption = true;
        };
      };
    };
  };
};
```

- [ ] **Step 2: Add zram to compensate for the smaller swap partition**

In `systems/ulysses/default.nix`, in the `# --- Boot ---` region:

```nix
  # Swap shrank 8G -> 4G to fit the ESP inside the partition budget. Peak swap
  # residency was 4.7G, so compressed in-RAM swap covers the difference.
  zramSwap.enable = true;
```

- [ ] **Step 3: Verify it evaluates and formats**

```bash
nix fmt
nix build .#nixosConfigurations.ulysses.config.system.build.toplevel --no-link
```

Expected: builds clean. **ABORT if** evaluation fails.

- [ ] **Step 4: Apply and reboot — this is the gate**

```bash
nixos-rebuild boot
reboot
```

After boot:

```bash
findmnt /boot                       # expect /dev/nvme0n1p1
swapon --show                       # expect /dev/nvme0n1p3
zpool status zpool                  # expect single healthy vdev on the Corsair
zfs list                            # expect all datasets mounted
```

Confirm no dataset went missing, by comparing against the Task 1 baseline:

```bash
zfs list -H -o name | sort > /tmp/datasets-after.txt
sed -n '/=== zfs list ===/,/^=== /p' /root/migration-baseline.txt \
  | awk 'NR>2 && $1 ~ /^zpool/ {print $1}' | sort > /tmp/datasets-before.txt
diff /tmp/datasets-before.txt /tmp/datasets-after.txt && echo "DATASETS MATCH"
```

Expected: `DATASETS MATCH`, no diff output.

**ABORT if** the machine does not boot: select the Samsung ESP in firmware, then `zpool import zpool-old` for a complete system as of Task 6.

- [ ] **Step 5: Commit**

```bash
git add systems/ulysses/disko-config.nix
git commit -m "ulysses: move root pool to Corsair MP700 PRO XT

Reconciles disko with the layout built by the live attach/resilver/detach
migration. ESP grows 1G -> 4G (Limine was at 55% of 1G, and Secure Boot
adds signed artifacts); swap shrinks 8G -> 4G to stay inside the 9 GiB
budget that keeps the root partition above the attach threshold."
```

---

### Task 8: `zpool upgrade` — deferred, irreversible

**Files:** none.

> **Do not run this in the same session.** Wait for several days of clean boots.

The pool reports *"some supported features are not enabled"*. Upgrading forecloses importing it with older ZFS, which would complicate rolling back to an older NixOS generation. There is no urgency.

- [ ] **Step 1: Confirm days of clean boots have passed, and `zpool-old` is still intact**

```bash
zpool import                        # expect zpool-old still listed
journalctl --list-boots | tail -5
```

- [ ] **Step 2: Upgrade**

```bash
zpool upgrade zpool
zpool status zpool                  # the "features not enabled" notice should be gone
```

Note: `zpool-old` predates the upgrade and remains importable by older ZFS. It is unaffected.

---

## Rollback Summary

| Failure point | Recovery |
|---|---|
| Task 1–3 | Nothing has touched the Samsung. Re-zap the Corsair. |
| Task 4 (bad Corsair) | `zpool detach` the **Corsair**. Pool is untouched. |
| Task 5 (won't boot) | Select `Limine (Samsung fallback)` in firmware (created in Task 5 Step 0). Mirror intact. |
| Task 6–7 | Boot `Limine (Samsung fallback)`; `zpool import zpool-old`. Full system as of detach. |
| After Task 8 | `zpool-old` predates the upgrade, still importable. |

## What this plan deliberately does not do

The Samsung is left **intact**. It is not wiped, not repartitioned, not made into scratch. That is `2026-07-09-samsung-scratch-pool-design.md`, and it is severed on purpose: beginning it destroys `zpool-old`, and with it the only second copy of `/persist` that will ever have existed.
