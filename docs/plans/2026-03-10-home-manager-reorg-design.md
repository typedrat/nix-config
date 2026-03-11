# Home-Manager Module Reorganization Design

## Problem

The `modules/home-manager/` directory has accreted over time without consistent organizing principles. The `gui/` directory is a catch-all, CLI tool files overlap (`tools.nix`, `utilities.nix`, `system-tools.nix`), and loose root-level files have no clear home. It's hard to know where to find or put anything.

## Design Principles

1. **Top-level split by layer** (core/cli/desktop/hardware/theming) — headless systems skip `desktop/`, making the split functional, not just cosmetic.
2. **Domain subdivisions within each layer** — mirroring NixOS service organization where applicable (development, media, networking, etc.).
3. **Single files for small categories, directories when there's enough to organize.**
4. **Hyprland subtree is the gold standard** — its alternatives pattern is preserved unchanged.
5. **When moving a file, audit its contents** — split modules whose contents don't belong together (e.g., `graphics.nix` bundles gimp, inkscape, and imgbrd-grabber; these should be separated).
6. **Three-level cascading enable options** — section > subdivision > program group, each defaulting to its parent's value.

## New Directory Structure

```
modules/home-manager/
  core/
    accounts.nix
    impermanence.nix
    mime.nix
    sops.nix
    user-sops-secrets.nix
    xdg-compliance.nix              # moved from cli/

  cli/
    development/                     # unchanged
    shell/                           # unchanged
    ai.nix                           # merged: ai.nix + comfy-cli.nix + llama-cpp (from ulysses system config)
    networking/                      # networking.nix + rclone.nix + tv-power.nix + pyvizio (from packages.nix)
    tools/
      core.nix                       # bat, eza, fd, fzf, ripgrep, jq, yazi, zoxide, direnv, parallel
      git.nix                        # lazygit, difftastic, mergiraf
      monitoring.nix                 # btop, bottom, ethtool, lm_sensors, strace, lsof, etc.
      nix.nix                        # nix-index, fh, nixpkgs-review, nix-diff, nix-tree, nix-update, attic, cachix
      media.nix                      # ffmpeg, imagemagick, yt-dlp, chafa
      archiving.nix                  # zip, unzip, xz, p7zip, unrar, zstd
      secrets.nix                    # age, sops, ssh-to-age

  desktop/                           # renamed from gui/
    hyprland/                        # unchanged + bitwarden-resize script moved here from firefox/
    terminals/                       # ghostty, wezterm
    browsers/
      common.nix                     # shared Firefox engine config (search engines, extensions, settings)
      brave.nix
      zen.nix
                                     # firefox/ subdirectory removed (contents absorbed into browsers/)
    chat/                            # unchanged (discord, element, telegram, slack)
    development/                     # renamed from devtools/ (vscode, zed, imhex, virt-manager)
    media/                           # mpv, obs, spotify, tauon, jellyfin, easyeffects
    productivity/                    # existing + gimp.nix, inkscape.nix (split from graphics.nix)
                                     # 3d-printing, blender, freecad, kicad, krita, openscad,
                                     # libreoffice, obsidian, sioyek, thunderbird, zotero
    gaming/                          # renamed from games/ + skyscraper.nix (from root)
    ai.nix                           # claude-desktop
    security.nix                     # bitwarden + gnome-keyring
    utilities.nix                    # qalculate, transmission, waypipe, wev, xcursor-viewer, imgbrd-grabber
    kdeglobals.nix                   # moved from root

  hardware/
    coolercontrol.nix
    openrgb.nix
    security-key.nix                 # moved from root

  theming/                           # unchanged
```

## Deleted Files

- `packages.nix` — contents distributed into appropriate domain modules:
  - cowsay, file, gawk, gnused, gnutar, tree, which, zstd, fastfetch, hyfetch -> `cli/tools/core.nix`
  - qbittorrent-cli -> `cli/networking/`
  - catbox-cli -> `cli/tools/core.nix`
  - python3Packages.pyvizio -> `cli/networking/` (with tv-power.nix)

## Option Tree Changes

The shared option definitions in `modules/shared/users/` need updating:

### Renames
- `gui` -> `desktop`
- `devtools` -> `development`
- `games` -> `gaming`
- `terminal` -> `terminals`

### New Subdivisions
- `cli.tools` gains: `core`, `git`, `monitoring`, `nix`, `media`, `archiving`, `secrets`
- `cli.networking` added (new)
- `desktop.browsers` gains `enable` (currently has no section-level enable)

### Cascading Defaults

Each level defaults to its parent's value:

```nix
# Section level
cli.enable = mkEnableOption "CLI tools";

# Subdivision level — defaults to section
cli.tools.enable = mkEnableOption "CLI tools" // { default = true; };

# Program group level — defaults to subdivision
cli.tools.core.enable = mkEnableOption "core shell tools" // { default = true; };
```

HM modules use three-level guards:
```nix
mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.core.enable)
```

## Migration Notes

- The `gui` -> `desktop` rename affects both `modules/shared/users/gui.nix` and all HM modules that read `guiCfg`
- All `or false` patterns in HM modules should be replaced with proper option references
- llama-cpp needs to be extracted from `systems/ulysses/default.nix` into `cli/ai.nix`
- The bitwarden-resize script moves from `desktop/browsers/` (ex-`firefox/`) into `desktop/hyprland/`
