# Live-USB cutover runbook

You are here because the Corsair copy (`zpool-new`) is complete and verified,
and it's time to cut over. This runs from the **NixOS installer USB**.

## The 5 commands to get Claude Code running (memorize / photograph these)

Everything else is on `/persist`, but you need these first to reach it:

```sh
# 1-3: import the Samsung read-only and mount your persisted data
zpool import -f -N zpool zpool-old
zfs load-key zpool-old            # type your ZFS passphrase
zfs mount zpool-old/safe/persist  # -> /persist

# 4: copy auth + scripts to RAM, export the pool
bash /persist/home/awilliams/Development/nix-config/docs/superpowers/plans/corsair-migration/live-bootstrap.sh

# 5: start Claude Code (authenticated as you)
nix run nixpkgs#claude-code
```

Then paste to Claude:

> Read ~/migration/plan.md and ~/migration/06-cutover.sh. We are at Task 6
> (cutover) from the live USB. zpool-new is a verified complete copy on the
> Corsair (exported). Guide me through the cutover.

## What the cutover does (06-cutover.sh)

1. Imports Samsung as `zpool-old`, Corsair (`zpool-new`) as `zpool`, loads keys
2. Incremental catch-up of `local/nix`, `safe/persist`, `safe/hyperion-home`
   (`local/root`/`local/home` are skipped — they roll back to `@blank` on boot)
3. Relabels partitions (`mig-*` -> `disk-main-*`, Samsung -> `old-*`)
4. Fresh ESP + bootloader via `nixos-enter … switch-to-configuration boot`
5. Exports; you reboot into the Corsair

## Safety net

The Samsung is **never written** except its GPT partition names — it stays a
complete, bootable fallback as `zpool-old`. If the Corsair won't boot: boot this
USB again and `zpool import -l zpool-old` for a full system. Nothing is lost.
