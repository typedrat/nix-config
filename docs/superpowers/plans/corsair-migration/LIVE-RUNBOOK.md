# Live-USB cutover runbook

You are here because the Corsair copy (`zpool-new`) is complete and verified,
and it's time to cut over. This runs from the **NixOS installer USB**.

## One line to get Claude Code running (no copy-paste needed)

`go.sh` is on the installer's ESP (`EFIBOOT`). In the live USB:

```sh
mkdir /esp && mount /dev/disk/by-label/EFIBOOT /esp && bash /esp/go.sh
```

It imports the Samsung (prompts your passphrase), bootstraps auth + scripts into
RAM, and launches Claude Code primed for the cutover. Then just say **"ready"** —
it reads `~/migration/CLAUDE.md` on startup. No message to paste.

### Fallback (if `go.sh` isn't on the ESP)

```sh
zpool import -f -l -R /mnt zpool zpool-old
bash /mnt/persist/home/awilliams/CUTOVER        # tab-complete: /mnt<tab>/p<tab>/h<tab>/a<tab>/C<tab>
cd ~/migration && nix run nixpkgs#claude-code
```

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
