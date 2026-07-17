#!/usr/bin/env bash
# Run in the LIVE USB (as root) AFTER importing the Samsung with altroot:
#   zpool import -f -l -R /mnt zpool zpool-old      # prompts for passphrase, mounts under /mnt
#
# Copies your Claude auth + migration scripts into RAM, writes a CLAUDE.md so a
# fresh Claude Code auto-loads the cutover context, then exports zpool-old.
set -euo pipefail

SRC=""
for base in /mnt/persist /persist; do
  [ -d "$base/home/awilliams/.claude" ] && SRC="$base/home/awilliams" && break
done
[ -n "$SRC" ] || { echo "ERROR: can't find persisted home (is safe/persist mounted under /mnt or /persist?)"; exit 1; }
DEST=${HOME:-/root}
REPO="$SRC/Development/nix-config/docs/superpowers/plans"

echo "found persisted home at $SRC"
echo "copying Claude auth into $DEST ..."
mkdir -p "$DEST/.claude"
cp "$SRC/.claude/.credentials.json" "$DEST/.claude/.credentials.json"
cp "$SRC/.claude.json"              "$DEST/.claude.json"
cp "$SRC/.claude/CLAUDE.md"         "$DEST/.claude/CLAUDE.md"     2>/dev/null || true
cp "$SRC/.claude/settings.json"     "$DEST/.claude/settings.json" 2>/dev/null || true
chmod 600 "$DEST/.claude/.credentials.json" "$DEST/.claude.json"

echo "copying migration scripts + plan into $DEST/migration ..."
mkdir -p "$DEST/migration"
cp "$REPO/corsair-migration/"*.sh "$DEST/migration/"
cp "$REPO/2026-07-09-corsair-nvme-migration.md" "$DEST/migration/plan.md"

# CLAUDE.md is auto-loaded by Claude Code from the working directory -- this
# primes a fresh session so the user doesn't have to paste anything.
cat > "$DEST/migration/CLAUDE.md" <<'EOF'
# Migration cutover — resume context (read this first)

You are a FRESH Claude Code session resuming an in-progress NVMe migration on
host `ulysses`, at the CUTOVER step, running from a NixOS live USB. You do NOT
have the prior conversation; get context from the files here.

READ NOW: `plan.md` (full design + current state) and `06-cutover.sh` (the
cutover script), both in this directory.

State:
- Migrating the root pool from the Samsung 990 EVO Plus to the Corsair MP700 PRO XT.
- The copy is DONE and verified: `zpool-new` on the Corsair is a complete copy
  (single encryption root, all datasets, `@blank` snapshots, key loads). It is
  currently exported.
- Remaining = the cutover in `06-cutover.sh`: import Samsung as `zpool-old` and
  Corsair as `zpool`, incremental catch-up of the data datasets, relabel
  partitions, install the bootloader (nixos-enter switch-to-configuration boot),
  export, reboot.

Hard rules:
- The user CANNOT copy-paste in this terminal-only env. Give SHORT commands.
- nvme0/nvme1 names are NOT stable — always use /dev/disk/by-id. Verify identity.
- The Samsung is the ONLY backup. It stays intact as `zpool-old`; never wipe it.
  Any failure => boot zpool-old and retry. No step may risk data.
- `06-cutover.sh` self-verifies and hard-aborts. Run it, watch its output, and
  help interpret any abort.

Start by reading plan.md and 06-cutover.sh, confirm the by-id device mapping,
then walk the user through running 06-cutover.sh.
EOF

echo "exporting zpool-old (the cutover re-imports it fresh) ..."
zpool export zpool-old

cat <<EOF

DONE. Now run:
  cd ~/migration && nix run nixpkgs#claude-code

Then just tell Claude you're ready — it auto-loads the cutover context.
EOF
