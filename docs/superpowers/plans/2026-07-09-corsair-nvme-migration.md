# Corsair NVMe Migration Implementation Plan (send/recv)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to track task-by-task. Steps use checkbox (`- [ ]`) syntax.

> ## ⚠ THIS PLAN IS NOT SUBAGENT-EXECUTABLE
>
> It runs `nvme format`, `sgdisk`, and `zfs recv` against the live root pool of a
> workstation with **no backup of `/persist`**, and part of it runs from a live
> USB. An agent cannot observe a POST screen, select a firmware boot entry, type
> a passphrase at an initrd prompt, or recover a machine that fails to come up.
>
> **A human runs every command, at the console.** An agent may read the plan,
> check output against expected values, and refuse to advance a gate.

> ## ⚠ DEVICE NAMES ARE NOT STABLE — THIS IS NOT THEORETICAL
>
> Between two sessions of writing this plan, with no hardware change, the kernel
> names **inverted**: the Corsair went from `nvme0n1` to `nvme1n1`, the Samsung
> from `nvme1n1` to `nvme0n1`. A `nvme format /dev/nvme0n1` written for the first
> session would have formatted the **live system** in the second.
>
> **Every destructive command uses `/dev/disk/by-id/…` or
> `/dev/disk/by-partlabel/…`, never `/dev/nvmeXnY`.** Task 0 re-derives the
> mapping for the current session into shell variables. Use the variables.

**Goal:** Move the root pool to the Corsair MP700 PRO XT via `zfs send -Rw`, into a fresh pool that permits a 4 GiB ESP + 8 GiB swap layout the attach method cannot. The Samsung is kept intact as the fallback.

**Architecture:** Create a new pool on the Corsair; `zfs send -Rw` (raw replication stream) the entire `zpool` hierarchy into it — carrying every property, snapshot, and the creation-time-immutable `normalization=formD`. The risky part (raw-receiving an encrypted pool-root) is proven **live and reversibly** before any reboot. Final cutover — rename, catch-up increment, bootloader — runs from a live USB. The Samsung is renamed `zpool-old` and never wiped by this plan.

**Tech Stack:** ZFS on root (encrypted, single encryption root at pool top), Limine, impermanence with root rollback, disko (reconciled after), NixOS unstable.

## Global Constraints

- **No backup of `/persist` exists.** 1.49T in one place. Every gate exists because of this.
- **`by-id` for all destructive ops. Never `/dev/nvmeXnY`.** (See the device-name warning above.)
- New pool must end up named **`zpool`**, `ashift=12`, `autotrim=on`, with every dataset property reproduced. `send -Rw` carries them, including `normalization=formD` (immutable after creation — cannot be fixed by hand later).
- Encryption root is the pool root `zpool`; single passphrase unlocks all. Preserving this through `recv` is the de-risk gate (Task 4).
- Layout: **ESP 4 GiB, swap 8 GiB, root = remainder.** No attach threshold — a fresh pool only stores 1.49T, so root can be smaller than the disk.
- Stable identifiers (verify in Task 0, do not trust the parentheticals):
  - Corsair: `nvme-Corsair_MP700_PRO_XT_AD27B6108002KO`
  - Samsung: `nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D`
  - Live vdev in `zpool status`: `nvme-eui.0025385a51a3c872-part2` (on the Samsung)
- A fresh pool is born with current feature flags, so **no `zpool upgrade` is needed** (the attach plan's Task 8 is gone).
- **8 GiB swap covers the 4.7 GiB observed peak outright — no zram.** The peak itself is ARC-eviction artifact; capping `zfs_arc_max` is a separate follow-up, out of scope.

## Prerequisites

- [x] NixOS live USB, tested, boots on this machine. **Required — the cutover runs from it.**
- [x] ZFS passphrase known and tested (typed at initrd, and at every `load-key` in this plan).
- [x] No UPS — accepted, bounded: the Samsung is never wiped, so any failure means "boot the Samsung and retry," never data loss.
- [ ] `~1–2 hours`; the live send (~1.49T) is the long unattended part; the USB cutover is short.
- [ ] On branch `typedrat/nvme-migration-specs`, tree clean.

---

### Task 0: Establish this session's device mapping (MANDATORY, FIRST)

**Files:** none.

**Interfaces:**
- Produces: shell variables `$CORSAIR` and `$SAMSUNG` (stable `by-id` paths) used by every later task. Re-run this at the start of **every** session — the `nvmeXnY` names may have changed since last time.

- [ ] **Step 1: Bind the variables to stable paths and confirm roles**

```bash
export CORSAIR=/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO
export SAMSUNG=/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D

echo "Corsair -> $(readlink -f $CORSAIR)"     # note the kernel name; do not hard-code it
echo "Samsung -> $(readlink -f $SAMSUNG)"
lsblk -no MODEL "$CORSAIR" | head -1           # MUST print: Corsair MP700 PRO XT
lsblk -no MODEL "$SAMSUNG" | head -1           # MUST print: Samsung SSD 990 EVO Plus 4TB
findmnt -no SOURCE /boot                        # the Samsung's p1 — the LIVE system
```

- [ ] **Step 2: Confirm the Corsair is blank and the Samsung is live**

```bash
# count partition rows, not the disk's own row (tail -n +2 would false-positive)
[ "$(lsblk -rno TYPE "$CORSAIR" | grep -c part)" -eq 0 ] \
  && echo "Corsair blank — good" || { echo "STOP: Corsair not blank"; lsblk "$CORSAIR"; }
zpool status zpool | grep nvme-eui             # live vdev is on the Samsung
```

**ABORT if** either model string is wrong, the Corsair shows partitions, or `/boot` is not on the Samsung. Do not run a single destructive command until this task passes.

---

### Task 1: Baseline (mostly captured already)

**Files:** Create `/persist/migration-baseline.txt` (persistent — survives the impermanence rollback, and rides along in the send/recv copy).

> An earlier `/root/migration-baseline.txt` was wiped by the impermanence root
> rollback on reboot. Capture to `/persist` this time.

- [ ] **Step 1: Capture the baseline to a persistent path**

```bash
sudo sh -c '{
  echo "=== date ==="; date
  echo "=== nvme list ==="; nvme list
  echo "=== lsblk bytes ==="; lsblk -b -o NAME,SIZE,MODEL,SERIAL,PARTLABEL,FSTYPE,MOUNTPOINT
  echo "=== zpool status ==="; zpool status zpool
  echo "=== zfs list ==="; zfs list
  echo "=== efibootmgr ==="; efibootmgr -v
  echo "=== findmnt /boot ==="; findmnt /boot
  echo "=== swapon ==="; swapon --show
} | tee /persist/migration-baseline.txt'
```

- [x] **Step 2: `@premigrate` snapshots exist** — recursive snapshot already taken (`zpool@premigrate` and descendants, 8 total). These are a fixed reference; the live send in Task 4 uses a **fresh** `@migrate` snapshot instead, so `@premigrate` stays as an untouched anchor.

- [ ] **Step 3: Re-verify current state**

```bash
zfs list -H -o name | sort               # expect the 8 datasets listed in Task 7
zpool status zpool                       # ONLINE, no errors
```

---

### Task 2: Format the Corsair to 4Kn

**Files:** none.

**Interfaces:**
- Consumes: `$CORSAIR` from Task 0.
- Produces: Corsair at 4096-byte LBA, no partition table.

> `nvme format` is irreversible. It targets `$CORSAIR` (by-id) — **never a raw `nvme0`/`nvme1` name.** Read the model string in Step 1 before Step 2.

- [ ] **Step 1: Re-confirm the target**

```bash
lsblk -no MODEL "$CORSAIR" | head -1      # MUST print: Corsair MP700 PRO XT
nvme id-ns "$CORSAIR" -H | grep -i 'lba format'   # LBA Format 1 = 4096 "Best"
```

**ABORT if** the model is not `Corsair MP700 PRO XT`.

- [ ] **Step 2: Format to 4Kn**

```bash
nvme format "$CORSAIR" --lbaf=1 --force
nvme id-ns "$CORSAIR" -H | grep 'in use'  # expect: Data Size: 4096 bytes ... (in use)
```

**ABORT if** still 512 bytes. Matches the pool's `ashift=12`; only fixable now.

---

### Task 3: Partition the Corsair

**Files:** none.

**Interfaces:**
- Consumes: 4Kn Corsair.
- Produces: partlabels `mig-esp` (4 GiB), `mig-swap` (8 GiB), `mig-root` (remainder). Renamed to `disk-main-*` at cutover (Task 6).

> Temp labels avoid colliding with the Samsung's live `disk-main-*` while both are attached. A fresh pool has no attach threshold, so root simply takes what's left after ESP and swap.

- [ ] **Step 1: Write the partition table**

```bash
sgdisk --zap-all "$CORSAIR"
sgdisk -n 1:0:+4G -t 1:EF00 -c 1:mig-esp  "$CORSAIR"
sgdisk -n 2:0:+8G -t 2:8200 -c 2:mig-swap "$CORSAIR"
sgdisk -n 3:0:0   -t 3:8300 -c 3:mig-root "$CORSAIR"   # 8300 = disko's ZFS partition type on the Samsung
partx -u "$CORSAIR"    # partprobe (parted) is not installed on the running system; partx (util-linux) is
```

`sgdisk` isn't in the base system either — it's in `gptfdisk` (now added to `modules/nixos/packages.nix`, live after the next rebuild). Until then, prefix with:
`nix shell nixpkgs#gptfdisk --command sudo --preserve-env=PATH bash …`

- [ ] **Step 2: Verify layout and that root dwarfs the data**

```bash
sgdisk -p "$CORSAIR"
lsblk -b -no SIZE /dev/disk/by-partlabel/mig-root   # expect ~3.98 TB, >> 1.49T used
ls -l /dev/disk/by-partlabel/ | grep -E 'mig-|disk-main-'   # mig-* and disk-main-* both unique
```

**ABORT if** any label is duplicated across the two drives.

---

### Task 4: Create the new pool and raw-send LIVE — the encryption de-risk gate

**Files:** none.

**Interfaces:**
- Consumes: `mig-root` partition.
- Produces: `zpool-new` on the Corsair holding a full, key-loadable copy as of `@migrate`.

> This is the crux, done **live and reversibly.** The machine keeps running on the Samsung. If the encrypted receive misbehaves, destroy `zpool-new` and nothing is lost — no reboot wasted, Samsung untouched. Only proceed to the cutover once `zfs load-key` succeeds here.

- [ ] **Step 1: Fresh migration snapshot**

```bash
zfs snapshot -r zpool@migrate
zfs list -t snapshot | grep @migrate      # one per dataset
```

- [ ] **Step 2: Create the destination pool (root dataset props come from the stream)**

```bash
zpool create -f -o ashift=12 -o autotrim=on -O mountpoint=none -O canmount=off \
  zpool-new /dev/disk/by-partlabel/mig-root
```

- [ ] **Step 3: Raw replication send (primary method)**

```bash
zfs send -Rw zpool@migrate | zfs recv -F -u zpool-new
```

`-R` carries all descendants, properties, and snapshots (`@blank`, `@premigrate`, `safe/hyperion-home`); `-w` sends the encrypted blocks raw; `-u` prevents mounting; `-F` lets the stream's root replace the freshly created `zpool-new` root.

- [ ] **Step 4: THE GATE — verify structure, snapshots, and that the key loads**

```bash
zfs list -r zpool-new                                   # local/root, local/nix, local/home, safe/persist, safe/hyperion-home
zfs list -t snapshot -r zpool-new | grep -E '@blank|@migrate'   # @blank on local/root AND local/home
zfs get -r encryption,encryptionroot zpool-new | grep encryptionroot   # all should read zpool-new
zfs get -o name,property,value normalization,acltype,xattr zpool-new/safe/persist
zfs unload-key -a 2>/dev/null; zfs load-key zpool-new   # PROMPTS for passphrase — must succeed
zfs get keystatus zpool-new                             # expect: available
```

**Expected:** every dataset and both `@blank` snapshots present; `encryptionroot` = `zpool-new` throughout; `load-key` accepts the passphrase and reports `available`.

**ABORT / fall back if** `load-key` fails or the encryptionroot is wrong. This is the known-uncertain step. Recovery is clean — nothing is committed:

```bash
zpool destroy zpool-new        # zero loss; Samsung still live
```

Then either retry with the **fallback method** (create the pool pre-encrypted and receive children under it):

```bash
zpool create -f -o ashift=12 -o autotrim=on \
  -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=prompt \
  -O acltype=posixacl -O xattr=sa -O normalization=formD -O dnodesize=auto \
  -O relatime=on -O mountpoint=none -O canmount=off \
  zpool-new /dev/disk/by-partlabel/mig-root
zfs send -Rw zpool/local@migrate | zfs recv -F -u zpool-new/local
zfs send -Rw zpool/safe@migrate  | zfs recv -F -u zpool-new/safe
```

…or abandon send/recv and revert to the attach plan (ESP 4G + swap 4G + zram) in git history. **Do not improvise past a failed `load-key`** against an unbacked-up pool.

---

### Task 5: Keep using the machine while the copy sits

Nothing to run. `zpool-new` holds the copy as of `@migrate`; the live pool keeps diverging. Task 6 catches the delta with an incremental. Schedule the cutover when you can spare a reboot.

---

### Task 6: Cutover from the live USB

**Files:** none.

**Interfaces:**
- Consumes: `zpool-new` (proven in Task 4).
- Produces: the Corsair pool renamed `zpool`, caught up to the moment of cutover, bootable; the Samsung renamed `zpool-old`, intact.

> Runs from the **live USB** — the new pool must take the name `zpool`, which the running system holds. Re-run **Task 0** first; kernel names differ under the live environment.

- [ ] **Step 1: Boot the live USB, re-derive the mapping**

Re-run Task 0 Step 1 to rebind `$CORSAIR` / `$SAMSUNG`. Do not assume the names from earlier.

- [ ] **Step 2: Import both pools under final names, load keys**

```bash
zpool import                                    # observe both pools and their GUIDs
zpool import -f -l zpool     zpool-old          # Samsung -> zpool-old (-l loads key)
zpool import -f -l zpool-new zpool              # Corsair -> zpool
zpool status                                    # zpool on Corsair, zpool-old on Samsung
```

- [ ] **Step 3: Catch-up incremental (delta since `@migrate`)**

```bash
zfs snapshot -r zpool-old@migrate2
zfs send -Rw -I zpool-old@migrate zpool-old@migrate2 | zfs recv -u zpool
zfs list -t snapshot -r zpool | grep @migrate2  # confirm the delta landed on the Corsair pool
```

- [ ] **Step 4: Relabel partitions to final names**

```bash
# Samsung steps aside (by-id from Task 0; partition suffixes are stable within a disk)
sgdisk -c 1:old-esp -c 2:old-root -c 3:old-swap "$SAMSUNG"
# Corsair takes the canonical names
sgdisk -c 1:disk-main-ESP -c 2:disk-main-swap -c 3:disk-main-root "$CORSAIR"
partprobe "$CORSAIR" "$SAMSUNG"
```

- [ ] **Step 5: Fresh ESP and bootloader for the existing generation**

The ESP is FAT, not part of the ZFS copy — build it fresh. The current system generation is already on the copied `/nix`, so install *its* bootloader rather than rebuilding.

```bash
mkfs.vfat -F32 -n BOOT /dev/disk/by-partlabel/disk-main-ESP
mkdir -p /mnt
mount -t zfs zpool/local/root /mnt
mount /dev/disk/by-partlabel/disk-main-ESP /mnt/boot
mount -t zfs zpool/local/nix /mnt/nix
for d in dev proc sys run; do mount --rbind /$d /mnt/$d; done
NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- \
  /nix/var/nix/profiles/system/bin/switch-to-configuration boot
```

**Verify:** `ls /mnt/boot/EFI/limine/BOOTX64.EFI` exists, and install the removable-media fallback that the current setup lacks:

```bash
install -D /mnt/boot/EFI/limine/BOOTX64.EFI /mnt/boot/EFI/BOOT/BOOTX64.EFI
```

- [ ] **Step 6: Export cleanly and reboot to the Corsair**

```bash
umount -R /mnt
zpool export zpool
zpool export zpool-old
reboot     # remove the USB; select the Corsair/Limine entry in firmware if needed
```

**ABORT if** the machine does not boot: the Samsung is intact and importable — boot the live USB, `zpool import -l zpool-old`, and you have a complete system as of `@migrate2`. Investigate before retrying; nothing is lost.

---

### Task 7: First boot from the Corsair — the gate

**Files:** none.

- [ ] **Step 1: Verify the running system is on the Corsair**

Re-run Task 0 to rebind variables, then:

```bash
findmnt -no SOURCE /boot                 # a partition on the Corsair
zpool status zpool                       # single vdev, on the Corsair, ONLINE, 0 errors
readlink -f /dev/disk/by-partlabel/disk-main-ESP   # a Corsair partition
swapon --show                            # disk-main-swap active (8G)
zfs list                                 # all datasets mounted; /, /nix, /home, /persist
```

Confirm no dataset went missing. Compare against the known-good list captured
during this migration (inline, because impermanence wipes `/root` every boot
and Task 7 runs after a reboot):

```bash
cat > /tmp/datasets-before.txt <<'EOF'
zpool
zpool/local
zpool/local/home
zpool/local/nix
zpool/local/root
zpool/safe
zpool/safe/hyperion-home
zpool/safe/persist
EOF
zfs list -H -o name | sort > /tmp/datasets-after.txt
diff <(sort /tmp/datasets-before.txt) /tmp/datasets-after.txt && echo "DATASETS MATCH"
```

**ABORT if** anything mounts from the Samsung, or a dataset is missing.

---

### Task 8: Reconcile disko

**Files:** Modify `systems/ulysses/disko-config.nix` (device, ESP size, swap/root split).

> Declarative bookkeeping — disko is **not run destructively.** It is edited to describe what was built.

- [ ] **Step 1: Edit the config**

- `device` → `/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO`
- ESP `size` → `4G`
- Reorder to ESP → swap → root, with swap `size = "8G"` and root taking the remainder:

```nix
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
  swap = {
    size = "8G";
    content = {
      type = "swap";
      randomEncryption = true;
    };
  };
  root = {
    size = "100%";
    content = {
      type = "zfs";
      pool = "zpool";
    };
  };
};
```

- [ ] **Step 2: Verify it evaluates**

```bash
nix fmt
nix build .#nixosConfigurations.ulysses.config.system.build.toplevel --no-link
```

- [ ] **Step 3: Apply and reboot — the gate**

```bash
nixos-rebuild boot && reboot
```

After boot: re-run Task 7 Step 1's checks. **ABORT if** it does not boot: boot the live USB, `zpool import -l zpool-old`.

- [ ] **Step 4: Commit**

```bash
git add systems/ulysses/disko-config.nix
git commit -m "ulysses: move root pool to Corsair MP700 PRO XT (send/recv)

Fresh pool via zfs send -Rw, allowing a 4G ESP + 8G swap layout the attach
threshold forbade. ESP grows 1G -> 4G (1G could not hold maxGenerations=10
at ~136 MiB initrds); swap stays 8G. Samsung retained as zpool-old."
```

---

### Task 9: Retire the fallback — deferred, not part of this plan

The Samsung remains imported-capable as `zpool-old`, intact. Do **not** destroy it here. It is the only second copy of `/persist`, and destroying it is the first step of the Samsung scratch-pool spec — begin that only after days of clean boots from the Corsair.

---

## Rollback Summary

| Failure point | Recovery |
|---|---|
| Task 0–3 | Nothing touched the Samsung. Re-zap the Corsair. |
| Task 4 (bad encrypted recv) | `zpool destroy zpool-new`. Zero loss; Samsung live. |
| Task 6 (won't boot) | Live USB; `zpool import -l zpool-old`. Full system as of `@migrate2`. |
| Task 7–8 | Same — the Samsung is untouched and importable. |

## What this plan deliberately does not do

The Samsung is left **intact** as `zpool-old` — not wiped, not repartitioned. That is the Samsung scratch-pool spec, severed on purpose: beginning it destroys the only second copy of `/persist`.
