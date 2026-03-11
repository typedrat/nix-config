# Home-Manager Module Reorganization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize `modules/home-manager/` from an unprincipled grab-bag into a layered, domain-organized structure with three-level cascading enable options.

**Architecture:** Top-level split by layer (core/cli/desktop/hardware/theming), domain subdivisions within each layer, three-level cascading enable options (section > subdivision > program group) in `modules/shared/users/`. The `gui/` directory becomes `desktop/`, loose root files move into `core/`, and overlapping CLI tool files are consolidated into `cli/tools/`.

**Tech Stack:** Nix (NixOS modules, Home Manager modules, flake-parts)

---

## Important Context

- **Option definitions** live in `modules/shared/users/` (NixOS modules that define `rat.users.<name>.*`)
- **HM modules** live in `modules/home-manager/` and read options via `osConfig.rat.users.${username}`
- **User config** is set in `users/awilliams.nix` (NixOS module)
- Current HM modules use the `or false` anti-pattern instead of proper option references — fix this everywhere
- Every `default.nix` in a directory imports its children and may set shared config
- Impermanence integration is pervasive — preserve all `home.persistence` blocks
- After each task, verify the system evaluates: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`

## Pre-flight

Before starting, create a feature branch:

```bash
cd /home/awilliams/Development/nix-config
git checkout -b refactor/home-manager-reorg
```

---

### Task 1: Create `core/` directory and move root-level files

Move the foundational modules that apply to all hosts into `core/`.

**Files:**
- Create: `modules/home-manager/core/default.nix`
- Move: `modules/home-manager/accounts.nix` -> `modules/home-manager/core/accounts.nix`
- Move: `modules/home-manager/impermanence.nix` -> `modules/home-manager/core/impermanence.nix`
- Move: `modules/home-manager/mime.nix` -> `modules/home-manager/core/mime.nix`
- Move: `modules/home-manager/sops.nix` -> `modules/home-manager/core/sops.nix`
- Move: `modules/home-manager/user-sops-secrets.nix` -> `modules/home-manager/core/user-sops-secrets.nix`
- Move: `modules/home-manager/cli/xdg-compliance.nix` -> `modules/home-manager/core/xdg-compliance.nix`
- Modify: `modules/home-manager/default.nix` — update imports
- Modify: `modules/home-manager/cli/default.nix` — remove xdg-compliance import

**Step 1: Create core/default.nix**

```nix
{
  imports = [
    ./accounts.nix
    ./impermanence.nix
    ./mime.nix
    ./sops.nix
    ./user-sops-secrets.nix
    ./xdg-compliance.nix
  ];
}
```

**Step 2: Move files**

```bash
mkdir -p modules/home-manager/core
git mv modules/home-manager/accounts.nix modules/home-manager/core/
git mv modules/home-manager/impermanence.nix modules/home-manager/core/
git mv modules/home-manager/mime.nix modules/home-manager/core/
git mv modules/home-manager/sops.nix modules/home-manager/core/
git mv modules/home-manager/user-sops-secrets.nix modules/home-manager/core/
git mv modules/home-manager/cli/xdg-compliance.nix modules/home-manager/core/
```

**Step 3: Fix sops.nix relative path**

`core/sops.nix` references `../../secrets/default.yaml`. After moving one level deeper, update to `../../../secrets/default.yaml`.

Similarly, `core/user-sops-secrets.nix` references `../../secrets/synapdeck-gdrive.json` — update to `../../../secrets/synapdeck-gdrive.json`.

**Step 4: Update modules/home-manager/default.nix**

Replace the individual imports with `./core/`:

```nix
# Remove these imports:
#   ./accounts.nix
#   ./impermanence.nix
#   ./mime.nix
#   ./sops.nix
#   ./user-sops-secrets.nix
# Add:
#   ./core/
```

**Step 5: Update modules/home-manager/cli/default.nix**

Remove `./xdg-compliance.nix` from its imports list.

**Step 6: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 7: Commit**

```bash
git add -A modules/home-manager/core/
git commit -m "refactor: create core/ directory for foundational home-manager modules"
```

---

### Task 2: Move `security-key.nix` and `skyscraper.nix` to their new homes

**Files:**
- Move: `modules/home-manager/security-key.nix` -> `modules/home-manager/hardware/security-key.nix`
- Move: `modules/home-manager/skyscraper.nix` -> `modules/home-manager/gui/games/skyscraper.nix` (will become `desktop/gaming/` in a later task)
- Modify: `modules/home-manager/default.nix` — remove old imports
- Modify: `modules/home-manager/gui/games/default.nix` — add skyscraper import
- Create or modify: `modules/home-manager/hardware/default.nix` — add security-key import

**Step 1: Move files**

```bash
git mv modules/home-manager/security-key.nix modules/home-manager/hardware/
git mv modules/home-manager/skyscraper.nix modules/home-manager/gui/games/
```

**Step 2: Create hardware/default.nix if it doesn't exist, or update it**

Check if `modules/home-manager/hardware/default.nix` exists. If not, create:

```nix
{
  imports = [
    ./coolercontrol.nix
    ./openrgb.nix
    ./security-key.nix
  ];
}
```

If it exists, add `./security-key.nix` to its imports.

**Step 3: Update gui/games/default.nix**

Add `./skyscraper.nix` to its imports list.

**Step 4: Update modules/home-manager/default.nix**

Remove `./security-key.nix` and `./skyscraper.nix` from imports. Ensure `./hardware/` is imported (it may already be via directory import).

**Step 5: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 6: Commit**

```bash
git commit -am "refactor: move security-key to hardware/, skyscraper to games/"
```

---

### Task 3: Consolidate CLI tools into `cli/tools/` subdirectory

Split the overlapping `tools.nix`, `utilities.nix`, `system-tools.nix` and absorb `packages.nix`.

**Files:**
- Create: `modules/home-manager/cli/tools/default.nix`
- Create: `modules/home-manager/cli/tools/core.nix`
- Create: `modules/home-manager/cli/tools/git.nix`
- Create: `modules/home-manager/cli/tools/monitoring.nix`
- Create: `modules/home-manager/cli/tools/nix.nix`
- Create: `modules/home-manager/cli/tools/media.nix`
- Create: `modules/home-manager/cli/tools/archiving.nix`
- Create: `modules/home-manager/cli/tools/secrets.nix`
- Delete: `modules/home-manager/cli/tools.nix`
- Delete: `modules/home-manager/cli/utilities.nix`
- Delete: `modules/home-manager/cli/system-tools.nix`
- Delete: `modules/home-manager/packages.nix`
- Modify: `modules/home-manager/cli/default.nix` — update imports
- Modify: `modules/home-manager/default.nix` — remove packages.nix import

**Step 1: Create the tools/ directory and files**

`cli/tools/default.nix`:
```nix
{
  imports = [
    ./archiving.nix
    ./core.nix
    ./git.nix
    ./media.nix
    ./monitoring.nix
    ./nix.nix
    ./secrets.nix
  ];
}
```

`cli/tools/core.nix` — enhanced shell tools + misc packages from packages.nix:
- From `tools.nix`: aria2, bat, bottom, direnv, eza, fd, fzf, jq, nix-index, parallel, ripgrep, yazi, zoxide
- From `packages.nix`: cowsay, file, gawk, gnused, gnutar, tree, which, zstd, fastfetch (with ZFS), hyfetch, catbox-cli
- Persistence: direnv, zoxide, yazi data dirs
- Guard: `mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.core.enable)`

`cli/tools/git.nix` — git-related tools:
- From `tools.nix`: lazygit, difftastic, mergiraf
- Persistence: mergiraf data dir
- Guard: `mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.git.enable)`

`cli/tools/monitoring.nix` — system monitoring:
- From `tools.nix`: btop (with cuda), bottom
- From `system-tools.nix`: ethtool, lm_sensors, lsof, ltrace, pciutils, strace, sysstat, usbutils
- Guard: `mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.monitoring.enable)`

`cli/tools/nix.nix` — Nix ecosystem tools:
- From `utilities.nix`: fh, nixpkgs-review, nix-diff, nix-tree, nix-prefetch-github, nix-update, cachix, attic-client
- From `tools.nix`: nix-index (with zsh integration)
- Guard: `mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.nix.enable)`

`cli/tools/media.nix` — media processing:
- From `utilities.nix`: ffmpeg-full, imagemagickBig, tokei, chafa, yt-dlp
- Guard: `mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.media.enable)`

`cli/tools/archiving.nix` — archive tools:
- From `utilities.nix`: unzip, xz, zip, p7zip, unrar
- From `packages.nix`: zstd
- Guard: `mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.archiving.enable)`

`cli/tools/secrets.nix` — crypto/secrets tools:
- From `utilities.nix`: age, sops, ssh-to-age
- Also from `utilities.nix`: openssl, pv, rename, vim.xxd (general utilities — put in core.nix)
- Guard: `mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.secrets.enable)`

Note: `waypipe` and `wl-clipboard` from `utilities.nix` are Wayland tools — move to `desktop/utilities.nix` if not already there.

**Step 2: Delete old files and update imports**

```bash
mkdir -p modules/home-manager/cli/tools
# Create all new files
git rm modules/home-manager/cli/tools.nix
git rm modules/home-manager/cli/utilities.nix
git rm modules/home-manager/cli/system-tools.nix
git rm modules/home-manager/packages.nix
```

Update `modules/home-manager/cli/default.nix`: replace `./tools.nix`, `./utilities.nix`, `./system-tools.nix` with `./tools/`.

Update `modules/home-manager/default.nix`: remove `./packages.nix`.

**Step 3: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor: consolidate CLI tools into organized tools/ subdirectory"
```

---

### Task 4: Create `cli/networking/` and merge networking modules

**Files:**
- Create: `modules/home-manager/cli/networking/default.nix`
- Move: `modules/home-manager/cli/networking.nix` -> `modules/home-manager/cli/networking/tools.nix`
- Move: `modules/home-manager/cli/tv-power.nix` -> `modules/home-manager/cli/networking/tv-power.nix`
- Move: `modules/home-manager/rclone.nix` -> `modules/home-manager/cli/networking/rclone.nix`
- Modify: `modules/home-manager/cli/default.nix` — update imports
- Modify: `modules/home-manager/default.nix` — remove rclone.nix import

**Step 1: Create directory and move files**

```bash
mkdir -p modules/home-manager/cli/networking
git mv modules/home-manager/cli/networking.nix modules/home-manager/cli/networking/tools.nix
git mv modules/home-manager/cli/tv-power.nix modules/home-manager/cli/networking/
git mv modules/home-manager/rclone.nix modules/home-manager/cli/networking/
```

**Step 2: Create networking/default.nix**

```nix
{
  imports = [
    ./rclone.nix
    ./tools.nix
    ./tv-power.nix
  ];
}
```

**Step 3: Fix rclone.nix**

The rclone module reads from `osConfig.rat.users.${username}.rclone` — no path changes needed since it doesn't reference relative files.

Add `qbittorrent-cli` from `packages.nix` into `tools.nix`'s package list.

**Step 4: Update imports**

In `modules/home-manager/cli/default.nix`: replace `./networking.nix` and `./tv-power.nix` with `./networking/`.

In `modules/home-manager/default.nix`: remove `./rclone.nix`.

**Step 5: Merge comfy-cli into ai.nix**

`modules/home-manager/cli/comfy-cli.nix` should be absorbed into `modules/home-manager/cli/ai.nix`. Add `programs.comfy-cli` config to `ai.nix` and delete `comfy-cli.nix`.

Also extract llama-cpp from `systems/ulysses/default.nix` (`inputs'.llama-cpp.packages.cuda`) and add it to `ai.nix`'s package list (gated on a check for CUDA/nvidia availability via `osConfig.rat.hardware.nvidia.enable or false`).

Remove `./comfy-cli.nix` from `modules/home-manager/cli/default.nix` imports.

**Step 6: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 7: Commit**

```bash
git add -A
git commit -m "refactor: create cli/networking/, merge comfy-cli into ai.nix, add llama-cpp"
```

---

### Task 5: Rename `gui/` to `desktop/` and move `kdeglobals.nix`

This is the big rename. Every reference to `gui/` in imports and every variable named `guiCfg` in HM modules changes.

**Files:**
- Rename: `modules/home-manager/gui/` -> `modules/home-manager/desktop/`
- Move: `modules/home-manager/kdeglobals.nix` -> `modules/home-manager/desktop/kdeglobals.nix`
- Modify: `modules/home-manager/default.nix` — `./gui/` becomes `./desktop/`, remove `./kdeglobals.nix`

**Step 1: Rename directory**

```bash
git mv modules/home-manager/gui modules/home-manager/desktop
git mv modules/home-manager/kdeglobals.nix modules/home-manager/desktop/
```

**Step 2: Update modules/home-manager/default.nix**

Replace `./gui/` with `./desktop/`. Remove `./kdeglobals.nix`. Add `./desktop/kdeglobals.nix` to `desktop/default.nix` imports instead.

**Step 3: Update desktop/default.nix**

Add `./kdeglobals.nix` to imports.

**Step 4: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

At this point, all internal references should still work because Nix module imports are relative paths and the internal structure of `gui/` (now `desktop/`) hasn't changed yet.

**Step 5: Commit**

```bash
git commit -am "refactor: rename gui/ to desktop/, move kdeglobals.nix"
```

---

### Task 6: Reorganize `desktop/browsers/`

Split `browsers.nix` into a `browsers/` directory and relocate the bitwarden-resize script.

**Files:**
- Create: `modules/home-manager/desktop/browsers/default.nix`
- Create: `modules/home-manager/desktop/browsers/common.nix`
- Create: `modules/home-manager/desktop/browsers/brave.nix`
- Create: `modules/home-manager/desktop/browsers/zen.nix`
- Delete: `modules/home-manager/desktop/browsers.nix`
- Move: `modules/home-manager/desktop/firefox/default.nix` -> `modules/home-manager/desktop/hyprland/bitwarden-resize.nix`
- Move: `modules/home-manager/desktop/firefox/bitwarden-resize-script.nix` -> `modules/home-manager/desktop/hyprland/bitwarden-resize-script.nix`
- Delete: `modules/home-manager/desktop/firefox/` directory
- Modify: `modules/home-manager/desktop/default.nix` — replace `./browsers.nix` and `./firefox/` with `./browsers/`
- Modify: `modules/home-manager/desktop/hyprland/default.nix` — add bitwarden-resize import

**Step 1: Create browsers/ directory**

Extract `commonFirefoxConfig` into `browsers/common.nix` as a module that provides the shared config via a `let` binding or option.

Extract Brave config block into `browsers/brave.nix`.

Extract Zen config block into `browsers/zen.nix`.

`browsers/default.nix`:
```nix
{
  imports = [
    ./brave.nix
    ./common.nix
    ./zen.nix
  ];
}
```

The persistence block from the original `browsers.nix` should go in `default.nix`.

**Step 2: Move bitwarden-resize to hyprland/**

```bash
git mv modules/home-manager/desktop/firefox/default.nix modules/home-manager/desktop/hyprland/bitwarden-resize.nix
git mv modules/home-manager/desktop/firefox/bitwarden-resize-script.nix modules/home-manager/desktop/hyprland/
git rm -r modules/home-manager/desktop/firefox
```

Update `hyprland/bitwarden-resize.nix` to reference `./bitwarden-resize-script.nix` (same directory now).

Add `./bitwarden-resize.nix` to `hyprland/default.nix` imports.

**Step 3: Update desktop/default.nix**

Replace `./browsers.nix` and `./firefox/` with `./browsers/`.

**Step 4: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: split browsers.nix into browsers/, move bitwarden-resize to hyprland/"
```

---

### Task 7: Create `desktop/terminals/`, rename `devtools/` and `games/`

**Files:**
- Create: `modules/home-manager/desktop/terminals/default.nix`
- Move: `modules/home-manager/desktop/ghostty/` -> `modules/home-manager/desktop/terminals/ghostty/`
- Move: `modules/home-manager/desktop/wezterm/` -> `modules/home-manager/desktop/terminals/wezterm/`
- Rename: `modules/home-manager/desktop/devtools/` -> `modules/home-manager/desktop/development/`
- Rename: `modules/home-manager/desktop/games/` -> `modules/home-manager/desktop/gaming/`
- Modify: `modules/home-manager/desktop/default.nix` — update all imports

**Step 1: Create terminals/**

```bash
mkdir -p modules/home-manager/desktop/terminals
git mv modules/home-manager/desktop/ghostty modules/home-manager/desktop/terminals/
git mv modules/home-manager/desktop/wezterm modules/home-manager/desktop/terminals/
```

Create `terminals/default.nix`:
```nix
{
  imports = [
    ./ghostty
    ./wezterm
  ];
}
```

**Step 2: Rename directories**

```bash
git mv modules/home-manager/desktop/devtools modules/home-manager/desktop/development
git mv modules/home-manager/desktop/games modules/home-manager/desktop/gaming
```

**Step 3: Update desktop/default.nix**

Replace `./ghostty/`, `./wezterm/` with `./terminals/`.
Replace `./devtools/` with `./development/`.
Replace `./games/` with `./gaming/`.

**Step 4: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 5: Commit**

```bash
git commit -am "refactor: create terminals/, rename devtools/ and games/"
```

---

### Task 8: Split `graphics.nix` and merge `easyeffects/` into `media/`

**Files:**
- Create: `modules/home-manager/desktop/productivity/gimp.nix`
- Create: `modules/home-manager/desktop/productivity/inkscape.nix`
- Delete: `modules/home-manager/desktop/graphics.nix`
- Move: `modules/home-manager/desktop/easyeffects/` -> `modules/home-manager/desktop/media/easyeffects/`
- Modify: `modules/home-manager/desktop/utilities.nix` — add imgbrd-grabber
- Modify: `modules/home-manager/desktop/security.nix` — merge gnome-keyring.nix content
- Delete: `modules/home-manager/desktop/gnome-keyring.nix`
- Delete: `modules/home-manager/desktop/claude-desktop.nix` (merge into `desktop/ai.nix`)
- Create: `modules/home-manager/desktop/ai.nix` (if not just renaming claude-desktop.nix)
- Modify: `modules/home-manager/desktop/default.nix` — update imports
- Modify: `modules/home-manager/desktop/productivity/default.nix` — add gimp, inkscape imports

**Step 1: Split graphics.nix**

Create `productivity/gimp.nix`:
```nix
{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  desktopCfg = osConfig.rat.desktop or {};
  productivityCfg = desktopCfg.productivity or {};
in {
  config = mkIf ((desktopCfg.enable or false) && (productivityCfg.enable or false)) {
    home.packages = [pkgs.gimp3];
  };
}
```

Create `productivity/inkscape.nix` (similar, with persistence for `.config/inkscape`).

Add `imgbrd-grabber` to `desktop/utilities.nix` packages.

**Step 2: Move easyeffects into media/**

```bash
git mv modules/home-manager/desktop/easyeffects modules/home-manager/desktop/media/
```

Update `desktop/media/default.nix` to import `./easyeffects/`.

**Step 3: Merge gnome-keyring into security.nix**

Add seahorse package, gnome-keyring service config, and persistence from `gnome-keyring.nix` into `security.nix`.

```bash
git rm modules/home-manager/desktop/gnome-keyring.nix
```

**Step 4: Rename claude-desktop.nix to ai.nix**

```bash
git mv modules/home-manager/desktop/claude-desktop.nix modules/home-manager/desktop/ai.nix
```

**Step 5: Update desktop/default.nix**

Remove imports: `./graphics.nix`, `./gnome-keyring.nix`, `./claude-desktop.nix`, `./easyeffects/`.
Ensure `./ai.nix`, `./security.nix`, `./utilities.nix` are imported.

**Step 6: Update desktop/productivity/default.nix**

Add `./gimp.nix` and `./inkscape.nix` to imports.

**Step 7: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 8: Commit**

```bash
git add -A
git commit -m "refactor: split graphics.nix, merge easyeffects into media/, consolidate security"
```

---

### Task 9: Update shared option definitions — rename `gui` to `desktop`

This is the option tree rename. Update option definitions and all consumers.

**Files:**
- Rename: `modules/shared/users/gui.nix` -> `modules/shared/users/desktop.nix`
- Modify: `modules/shared/users/default.nix` — update import
- Modify: `modules/shared/users/desktop.nix` — rename `gui` to `desktop` in option paths
- Modify: ALL HM modules in `modules/home-manager/desktop/` — change `guiCfg` references to `desktopCfg`, change `osConfig.rat.gui` to `osConfig.rat.desktop`
- Modify: `users/awilliams.nix` — rename `gui` to `desktop` in user config
- Modify: Any NixOS modules that reference `rat.gui` (check `modules/nixos/gui/` for cross-references)

**Step 1: Rename option file**

```bash
git mv modules/shared/users/gui.nix modules/shared/users/desktop.nix
```

Update `modules/shared/users/default.nix`: `./gui.nix` -> `./desktop.nix`.

**Step 2: Update option definitions in desktop.nix**

In `modules/shared/users/desktop.nix`:
- Rename `guiOptions` to `desktopOptions`
- Rename `options.gui` to `options.desktop` in the `rat.users` option
- Rename `devtools` to `development`
- Rename `games` to `gaming`
- Rename `terminal` to `terminals`

**Step 3: Update users/awilliams.nix**

All references under `rat.users.awilliams.gui.*` become `rat.users.awilliams.desktop.*`.

**Step 4: Global search and replace in HM modules**

Search all files in `modules/home-manager/desktop/` for:
- `guiCfg` -> `desktopCfg`
- `osConfig.rat.gui` -> `osConfig.rat.desktop`
- `userCfg.gui` -> `userCfg.desktop`
- `gamesCfg` -> `gamingCfg`
- `devtoolsCfg` -> `developmentCfg`

Also search `modules/home-manager/cli/` and `modules/home-manager/core/` for any `osConfig.rat.gui` references (e.g., `xdg-compliance.nix` might reference nvidia).

**Step 5: Check NixOS module cross-references**

Search `modules/nixos/` for `rat.gui` references — these define the NixOS-level `rat.gui` options (different from `rat.users.*.gui`). Those are separate and should NOT be renamed — they control system-level GUI settings like display manager, not user-level desktop apps.

However, HM modules that read `osConfig.rat.gui.enable` (the system-level one, not user-level) need to keep that reference. Carefully distinguish:
- `osConfig.rat.gui.enable` — system-level, keep as-is
- `osConfig.rat.users.${username}.gui` / `userCfg.gui` — user-level, rename to `desktop`

**Step 6: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath
```

**Step 7: Commit**

```bash
git commit -am "refactor: rename gui option tree to desktop in shared options and all consumers"
```

---

### Task 10: Add three-level cascading enable options

Add granular subdivision options to the shared option definitions.

**Files:**
- Modify: `modules/shared/users/cli.nix` — add tool subdivision options
- Modify: `modules/shared/users/desktop.nix` — add missing section-level enables, subdivision options
- Modify: All HM modules — update guards to use three-level checks

**Step 1: Update cli.nix option definitions**

Replace the current flat `tools.enable` with subdivisions:

```nix
cliOptions = types.submodule {
  options = {
    enable = options.mkEnableOption "CLI tools and configuration";

    shell = {
      enable = options.mkEnableOption "shell configuration" // {default = true;};
    };

    tools = {
      enable = options.mkEnableOption "CLI development tools" // {default = true;};
      core.enable = options.mkEnableOption "core shell tools (bat, fzf, etc.)" // {default = true;};
      git.enable = options.mkEnableOption "git tools (lazygit, difftastic)" // {default = true;};
      monitoring.enable = options.mkEnableOption "system monitoring tools" // {default = true;};
      nix.enable = options.mkEnableOption "Nix ecosystem tools" // {default = true;};
      media.enable = options.mkEnableOption "media processing tools" // {default = true;};
      archiving.enable = options.mkEnableOption "archive/compression tools" // {default = true;};
      secrets.enable = options.mkEnableOption "crypto and secrets tools" // {default = true;};
    };

    development = {
      enable = options.mkEnableOption "development CLI tools" // {default = true;};
    };

    ai = {
      enable = options.mkEnableOption "AI tools and configuration" // {default = true;};
    };

    networking = {
      enable = options.mkEnableOption "networking tools" // {default = true;};
    };
  };
};
```

Remove `comfy-cli` and `tv-power` as separate top-level options (they're now inside `ai` and `networking` respectively).

**Step 2: Update desktop.nix option definitions**

Add section-level `enable` for `browsers`:

```nix
browsers = {
  enable = options.mkEnableOption "web browsers" // {default = true;};
  firefox.enable = options.mkEnableOption "Firefox" // {default = true;};
  brave.enable = options.mkEnableOption "Brave" // {default = true;};
  zen.enable = options.mkEnableOption "Zen Browser" // {default = true;};
};

terminals = {
  enable = options.mkEnableOption "terminal emulators" // {default = true;};
  wezterm.enable = options.mkEnableOption "WezTerm" // {default = true;};
  ghostty.enable = options.mkEnableOption "Ghostty";
};
```

Rename `devtools` -> `development`, `games` -> `gaming`, `terminal` -> `terminals` if not already done in Task 9.

**Step 3: Update all HM module guards**

Every HM module guard changes from the `or false` pattern to proper three-level:

Before:
```nix
modules.mkIf ((cliCfg.enable or false) && (cliCfg.tools.enable or false))
```

After:
```nix
modules.mkIf (cliCfg.enable && cliCfg.tools.enable && cliCfg.tools.core.enable)
```

Do this for every module file. The `or false` pattern is no longer needed because all options now have proper defaults.

**Step 4: Update users/awilliams.nix if needed**

The user config may need updates if option names changed (e.g., `comfy-cli` -> handled by `ai`, `tv-power` -> handled by `networking`).

**Step 5: Verify evaluation**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath
```

**Step 6: Commit**

```bash
git commit -am "refactor: add three-level cascading enable options"
```

---

### Task 11: Clean up `desktop/default.nix` imports and final polish

Ensure `desktop/default.nix` has a clean, organized import list matching the new structure.

**Files:**
- Modify: `modules/home-manager/desktop/default.nix`
- Modify: `modules/home-manager/default.nix`
- Modify: `modules/home-manager/cli/default.nix`

**Step 1: Verify desktop/default.nix imports**

Should look like:
```nix
{
  imports = [
    ./ai.nix
    ./browsers
    ./chat
    ./development
    ./gaming
    ./hyprland
    ./kdeglobals.nix
    ./media
    ./productivity
    ./security.nix
    ./terminals
    ./utilities.nix
  ];
}
```

With any shared configuration (like the current `packages` block from `gui/default.nix`).

**Step 2: Verify root default.nix imports**

Should look like:
```nix
imports = [
  ./cli
  ./core
  ./desktop
  ./hardware
  ./theming
];
```

Plus any remaining root-level config that isn't in a category.

**Step 3: Run formatter**

```bash
nix fmt
```

**Step 4: Full evaluation check**

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.hyperion.config.system.build.toplevel.drvPath
```

**Step 5: Commit**

```bash
git commit -am "refactor: final cleanup of home-manager module reorganization"
```

---

### Task 12: Update CLAUDE.md

Update the project documentation to reflect the new structure.

**Files:**
- Modify: `CLAUDE.md` — update Module Organization section, file locations

**Step 1: Update CLAUDE.md**

In the Module Organization section, update:
- `modules/home-manager/` description to reflect new structure (core/, cli/, desktop/, hardware/, theming/)
- Update any references to `gui/` -> `desktop/`
- Mention the three-level option system

**Step 2: Commit**

```bash
git commit -am "docs: update CLAUDE.md for home-manager reorganization"
```
