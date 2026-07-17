#!/usr/bin/env bash
# Run in the LIVE USB environment, as root, AFTER:
#   zpool import -f -N zpool zpool-old
#   zfs load-key zpool-old            # type your ZFS passphrase
#   zfs mount zpool-old/safe/persist  # -> /persist
#
# Copies your Claude auth + the migration scripts into RAM, then exports
# zpool-old so the cutover can re-import it fresh.
set -euo pipefail
SRC=/persist/home/awilliams
DEST=${HOME:-/root}

[ -r "$SRC/.claude/.credentials.json" ] || { echo "ERROR: $SRC/.claude/.credentials.json not found -- is safe/persist mounted?"; exit 1; }

echo "copying Claude auth into $DEST ..."
mkdir -p "$DEST/.claude"
cp "$SRC/.claude/.credentials.json" "$DEST/.claude/.credentials.json"
cp "$SRC/.claude.json"              "$DEST/.claude.json"
cp "$SRC/.claude/CLAUDE.md"         "$DEST/.claude/CLAUDE.md"     2>/dev/null || true
cp "$SRC/.claude/settings.json"     "$DEST/.claude/settings.json" 2>/dev/null || true
chmod 600 "$DEST/.claude/.credentials.json" "$DEST/.claude.json"

echo "copying migration scripts + plan into $DEST/migration ..."
mkdir -p "$DEST/migration"
cp "$SRC/Development/nix-config/docs/superpowers/plans/corsair-migration/"*.sh "$DEST/migration/"
cp "$SRC/Development/nix-config/docs/superpowers/plans/2026-07-09-corsair-nvme-migration.md" "$DEST/migration/plan.md"

echo "exporting zpool-old (the cutover re-imports it fresh) ..."
zpool export zpool-old

cat <<EOF

DONE. Now run:
  nix run nixpkgs#claude-code

Then paste this to Claude:
  Read ~/migration/plan.md and ~/migration/06-cutover.sh. We are at Task 6
  (cutover), running from the live USB. zpool-new is a verified complete copy
  on the Corsair (currently exported). Guide me through the cutover.
EOF
