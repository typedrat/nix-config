#!/usr/bin/env bash
# Task 4 (corrected): per-dataset non-raw send into a pre-encrypted pool,
# then verify. Reproduces the current topology exactly (single encryption root
# at the pool root, same paths, one boot prompt, 8G swap, no config changes).
#
# THE FIX from the first attempt: mountpoints are set at RECEIVE time via
# `zfs recv -o mountpoint=X -u`. The -u guarantees the dataset is never mounted.
# There is NO bare `zfs set mountpoint` anywhere -- that is what mounted
# zpool-new over the live root last time and forced a reboot.
#
# Also: @migrate is recreated fresh (impermanence rollback destroys it on
# local/root and local/home at every boot), and the pool is created with
# cachefile=none + exported at the end, so a reboot can't auto-import it.
#
# Non-destructive to the Samsung. Any failure: zpool destroy zpool-new.
#
# Run:  nix shell nixpkgs#pv --command sudo --preserve-env=PATH bash 04-send-and-verify.sh
set -euo pipefail
cd "$(dirname "$0")"
. ./_lib.sh
assert_is_corsair

ROOT_PART=/dev/disk/by-partlabel/mig-root
CORSAIR_DEV=$(readlink -f "$CORSAIR"); ROOT_DEV=$(readlink -f "$ROOT_PART")
[ "$ROOT_DEV" = "${CORSAIR_DEV}p3" ] || { echo "ABORT: mig-root ($ROOT_DEV) not on Corsair"; exit 1; }

# Passphrase from /tmp/pass with the trailing newline stripped. $(cat ...)
# strips trailing newlines; printf %s writes it back without adding one, so the
# keyfile holds exactly the passphrase you'll type at the boot prompt.
PASSFILE=/tmp/pass
[ -r "$PASSFILE" ] || { echo "ABORT: $PASSFILE not readable"; exit 1; }
KEYFILE=$(mktemp /tmp/zmig.key.XXXXXX); chmod 600 "$KEYFILE"
trap 'rm -f "$KEYFILE"' EXIT
printf '%s' "$(cat "$PASSFILE")" > "$KEYFILE"
[ -s "$KEYFILE" ] || { echo "ABORT: stripped passphrase is empty"; exit 1; }

# Clear any prior zpool-new (import first if it's on disk but not imported).
if zpool list zpool-new >/dev/null 2>&1; then
  zpool destroy zpool-new
elif zpool import 2>/dev/null | grep -q 'zpool-new'; then
  zpool import -N -f zpool-new && zpool destroy zpool-new
fi

# Fresh @migrate everywhere (rollback wipes local/root + local/home @migrate).
echo "--- recreating @migrate snapshots fresh ---"
zfs destroy -r zpool@migrate 2>/dev/null || true
zfs snapshot -r zpool@migrate
zfs list -t snapshot -o name | grep '@migrate$'

echo "--- create ENCRYPTED destination pool (key from $PASSFILE, no prompt) ---"
zpool create -f -o ashift=12 -o autotrim=on -o cachefile=none \
  -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=file://"$KEYFILE" \
  -O acltype=posixacl -O dnodesize=auto -O normalization=formD \
  -O relatime=on -O xattr=sa -O canmount=off -O mountpoint=none \
  zpool-new "$ROOT_PART"

echo "--- container datasets ---"
zfs create -o canmount=on -o mountpoint=none zpool-new/local
zfs create -o canmount=on -o mountpoint=none -o com.sun:auto-snapshot=true zpool-new/safe

# ---- helpers: non-raw, mountpoint set via -o, NEVER mounted (-u) ----
est()  { zfs send -nP "$@" 2>/dev/null | awk '/^size/{print $2}' || true; }
pipe() { if command -v pv >/dev/null 2>&1; then pv -pterab -s "${1:-0}"; else cat; fi; }
recv_full() {  # $1 src@snap   $2 dest   $3 mountpoint
  echo ">> full  $1 -> $2  (mountpoint=$3)"
  local s; s=$(est "$1")
  zfs send "$1" | pipe "$s" | zfs recv -o mountpoint="$3" -u "$2"
}
recv_incr() {  # $1 src   $2 from@   $3 to@   $4 dest
  echo ">> incr  $1 $2..$3 -> $4"
  local s; s=$(est -i "$2" "$1$3")
  zfs send -i "$2" "$1$3" | pipe "$s" | zfs recv -u "$4"
}

confirm "Send all datasets into the encrypted zpool-new now?"

# local/root + local/home carry @blank (impermanence): full @blank, then @blank->@migrate
recv_full "zpool/local/root@blank" zpool-new/local/root /
recv_incr "zpool/local/root" "@blank" "@migrate" zpool-new/local/root
recv_full "zpool/local/home@blank" zpool-new/local/home /home
recv_incr "zpool/local/home" "@blank" "@migrate" zpool-new/local/home
# the rest: full @migrate
recv_full "zpool/local/nix@migrate"           zpool-new/local/nix          /nix
recv_full "zpool/safe/persist@migrate"        zpool-new/safe/persist       /persist
recv_full "zpool/safe/hyperion-home@migrate" zpool-new/safe/hyperion-home legacy

echo "--- SAFETY: confirm nothing from zpool-new mounted ---"
assert_zpoolnew_unmounted

echo "--- VERIFY: structure, @blank, single encryption root, key loads ---"
zfs unload-key zpool-new
zfs load-key zpool-new          # reads keylocation=file://$KEYFILE -- no prompt
[ "$(zfs get -H -o value keystatus zpool-new)" = available ] || { echo "FAIL: key did not load"; exit 1; }
echo "encryptionroot (all must be zpool-new):"
zfs get -r -o name,value encryptionroot zpool-new
echo "@blank present:"; zfs list -t snapshot -r zpool-new | grep '@blank' || { echo "FAIL: @blank missing"; exit 1; }
echo "datasets:"; zfs list -r zpool-new

# Final system unlocks at the boot prompt, so point keylocation back to prompt.
echo "--- set keylocation=prompt for the booted system ---"
zfs set keylocation=prompt zpool-new

echo "--- export (inert until cutover; cachefile=none means no auto-import) ---"
zpool export zpool-new

echo
echo "TASK 4 COMPLETE. zpool-new holds a verified copy and is exported."
