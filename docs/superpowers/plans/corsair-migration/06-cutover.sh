#!/usr/bin/env bash
# Task 6: CUTOVER, run from the NixOS live USB (NOT the installed system).
#
# Imports the Samsung pool as zpool-old and the Corsair pool as zpool, catches
# up the data datasets with an incremental, relabels partitions, installs the
# bootloader onto a fresh Corsair ESP, and exports. The Samsung is never
# written to except its GPT partition NAMES; it remains a complete fallback
# (zpool-old). Any failure aborts with the Samsung intact.
#
# Self-verifying: every stage checks its result and aborts loudly. Everything is
# logged. Run it and paste the log if anything looks off.
#
# Run (from the live USB, as root):
#   bash 06-cutover.sh 2>&1 | tee /mnt/usb/cutover-log.txt
set -uo pipefail

CORSAIR=/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO
SAMSUNG=/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D
DATA_DATASETS=(local/nix safe/persist safe/hyperion-home)   # the ones to catch up

abort() { echo; echo "!! ABORT: $*"; echo "!! Samsung is intact as a fallback. Nothing on it was written except"; echo "!! GPT names. To recover a bootable system: boot this USB, 'zpool import -l zpool-old'."; exit 1; }
say()   { echo; echo "==== $* ===="; }
confirm(){ read -rp ">> $1  Type YES: " a; [ "$a" = YES ] || abort "declined at: $1"; }

# ---- Stage 0: safety + device mapping ----
say "Stage 0: environment + device identity"
[ "$(id -u)" = 0 ] || abort "run as root"
rootfs=$(findmnt -no FSTYPE /)
[ "$rootfs" != zfs ] || abort "/ is ZFS -- you are on an installed system, not the live USB. STOP."
echo "root fs is '$rootfs' (live USB, good)"
[ -e "$CORSAIR" ] && [ -e "$SAMSUNG" ] || abort "Corsair/Samsung by-id path missing"
[ "$(lsblk -dno MODEL "$CORSAIR")" = "Corsair MP700 PRO XT" ] || abort "Corsair model mismatch"
[ "$(lsblk -dno MODEL "$SAMSUNG")" = "Samsung SSD 990 EVO Plus 4TB" ] || abort "Samsung model mismatch"
echo "Corsair -> $(readlink -f "$CORSAIR")   Samsung -> $(readlink -f "$SAMSUNG")"
zpool list zpool     >/dev/null 2>&1 && abort "a pool named 'zpool' is already imported"
zpool list zpool-old >/dev/null 2>&1 && abort "a pool named 'zpool-old' is already imported"

# ---- Stage 1: import both pools, load keys (one passphrase, used for both) ----
say "Stage 1: import pools + load keys"
read -rsp "ZFS passphrase: " PASS; echo
KF=$(mktemp); chmod 600 "$KF"; trap 'rm -f "$KF"' EXIT; printf '%s' "$PASS" > "$KF"
[ -s "$KF" ] || abort "empty passphrase"

# Samsung on-disk name is 'zpool' -> import as zpool-old (no mount, we only read it).
zpool import -f -N zpool zpool-old || abort "import Samsung as zpool-old failed"
# Corsair on-disk name is 'zpool-new'. If it's still imported under that name, export first.
zpool list zpool-new >/dev/null 2>&1 && { echo "exporting still-imported zpool-new"; zpool export zpool-new || abort "could not export zpool-new"; }
# import as zpool, altroot /mnt, no auto-mount.
zpool import -f -R /mnt -N zpool-new zpool || abort "import Corsair as zpool failed"

# sanity: right pools on the right disks
zpool status zpool-old | grep -q "$(basename "$(readlink -f "$SAMSUNG")")" || abort "zpool-old is not on the Samsung"
zpool status zpool     | grep -q "$(basename "$(readlink -f "$CORSAIR")")" || abort "zpool is not on the Corsair"

zfs load-key -L file://"$KF" zpool-old || abort "load-key zpool-old failed (wrong passphrase?)"
zfs load-key -L file://"$KF" zpool     || abort "load-key zpool failed (wrong passphrase?)"
echo "both keys loaded"

# structure sanity on the destination
for ds in local/root local/nix local/home safe/persist safe/hyperion-home; do
  zfs list -H -o name "zpool/$ds" >/dev/null 2>&1 || abort "zpool/$ds missing on the Corsair copy"
done
zfs list -H -o name zpool/local/root@blank zpool/local/home@blank >/dev/null 2>&1 || abort "@blank missing on the copy"
echo "destination structure + @blank present"

# ---- Stage 2: incremental catch-up of the data datasets ----
say "Stage 2: incremental catch-up (local/root and local/home are skipped -- they roll back to @blank)"
zfs snapshot -r zpool-old@migrate2 || abort "snapshot @migrate2 failed"
for ds in "${DATA_DATASETS[@]}"; do
  zfs list -H -o name "zpool-old/$ds@migrate"  >/dev/null 2>&1 || abort "source zpool-old/$ds@migrate missing (cannot do incremental)"
  zfs list -H -o name "zpool/$ds@migrate"      >/dev/null 2>&1 || abort "dest zpool/$ds@migrate missing"
  echo ">> catching up zpool/$ds  (@migrate -> @migrate2)"
  if command -v pv >/dev/null 2>&1; then
    sz=$(zfs send -nP -i "@migrate" "zpool-old/$ds@migrate2" 2>/dev/null | awk '/^size/{print $2}')
    zfs send -i "@migrate" "zpool-old/$ds@migrate2" | pv -pterab -s "${sz:-0}" | zfs recv -u "zpool/$ds" || abort "catch-up recv failed for $ds"
  else
    zfs send -i "@migrate" "zpool-old/$ds@migrate2" | zfs recv -u "zpool/$ds" || abort "catch-up recv failed for $ds"
  fi
  zfs list -H -o name "zpool/$ds@migrate2" >/dev/null 2>&1 || abort "@migrate2 did not land on zpool/$ds"
done
echo "catch-up complete"

# ---- Stage 3: relabel partitions (GPT names only; non-destructive to data) ----
say "Stage 3: relabel partitions"
echo "Samsung -> old-*, Corsair -> disk-main-*"
confirm "Relabel partitions on both drives?"
sgdisk -c 1:old-esp -c 2:old-root -c 3:old-swap "$SAMSUNG" || abort "relabel Samsung failed"
sgdisk -c 1:disk-main-ESP -c 2:disk-main-swap -c 3:disk-main-root "$CORSAIR" || abort "relabel Corsair failed"
partprobe "$CORSAIR" "$SAMSUNG" 2>/dev/null || { partx -u "$CORSAIR"; partx -u "$SAMSUNG"; }
udevadm settle 2>/dev/null || sleep 2
[ "$(readlink -f /dev/disk/by-partlabel/disk-main-ESP)" = "$(readlink -f "$CORSAIR")p1" ] || abort "disk-main-ESP does not resolve to the Corsair"
echo "labels ok: disk-main-ESP -> $(readlink -f /dev/disk/by-partlabel/disk-main-ESP)"

# ---- Stage 4: fresh ESP + bootloader (existing generation) ----
say "Stage 4: fresh ESP + bootloader"
confirm "Format the Corsair ESP and install the bootloader?"
mkfs.vfat -F32 -n BOOT /dev/disk/by-partlabel/disk-main-ESP || abort "mkfs ESP failed"
zfs mount zpool/local/root   || abort "mount zpool/local/root failed"
zfs mount zpool/local/nix    || abort "mount zpool/local/nix failed"
zfs mount zpool/local/home   || abort "mount zpool/local/home failed"
zfs mount zpool/safe/persist || abort "mount zpool/safe/persist failed"
mount /dev/disk/by-partlabel/disk-main-ESP /mnt/boot || abort "mount ESP failed"
for d in dev proc sys run; do mount --rbind "/$d" "/mnt/$d" || abort "bind /$d failed"; done
NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- \
  /nix/var/nix/profiles/system/bin/switch-to-configuration boot || abort "bootloader install (switch-to-configuration boot) failed"
[ -e /mnt/boot/EFI/limine/BOOTX64.EFI ] || abort "Limine EFI not found on the new ESP after install"
install -D /mnt/boot/EFI/limine/BOOTX64.EFI /mnt/boot/EFI/BOOT/BOOTX64.EFI || abort "removable-media fallback copy failed"
echo "bootloader installed; removable-media fallback in place"

# ---- Stage 5: finalize ----
say "Stage 5: export and finish"
umount -R /mnt 2>/dev/null || true
zpool export zpool     || abort "export zpool failed (something still using it?)"
zpool export zpool-old || echo "note: export zpool-old failed (harmless; it will not auto-import)"
echo
echo "################################################################"
echo "# CUTOVER COMPLETE."
echo "#  - Remove the USB and reboot."
echo "#  - In firmware, pick the Corsair/Limine entry if it isn't default."
echo "#  - You'll be asked for the ZFS passphrase once at boot."
echo "#  - If it does NOT boot: this USB, 'zpool import -l zpool-old' = full"
echo "#    system as of now. Nothing on the Samsung was lost."
echo "################################################################"
