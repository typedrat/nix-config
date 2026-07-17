# Live-USB cutover runbook

You are here because the Corsair copy (`zpool-new`) is complete and verified,
and it's time to cut over. This runs from the **NixOS installer USB**.

## The 3 commands to get Claude Code running (no copy-paste needed)

Terminal-only, so these use tab-completion-friendly short paths:

```sh
# 1: import the Samsung, load key (prompts passphrase), mount everything under /mnt
zpool import -f -l -R /mnt zpool zpool-old

# 2: copy auth + scripts to RAM, export the pool  (tab-complete the path: /mnt<tab>/p<tab>/h<tab>/a<tab>/C<tab>)
bash /mnt/persist/home/awilliams/CUTOVER

# 3: start Claude Code, which auto-loads the cutover context
cd ~/migration && nix run nixpkgs#claude-code
```

Then just tell Claude **"ready"** — it reads `~/migration/CLAUDE.md` on startup
and picks up the cutover. No message to paste.

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
