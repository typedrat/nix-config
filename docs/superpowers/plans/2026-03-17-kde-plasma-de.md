# KDE Plasma Desktop Environment Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add KDE Plasma 6 as a full standalone DE alongside Hyprland, selectable at the display manager, with deep Catppuccin theming via plasma-manager.

**Architecture:** New `rat.gui.kde.enable` and `rat.gui.hyprland.enable` options at NixOS level, with corresponding Home Manager user options. plasma-manager flake input provides declarative KDE configuration. Existing kdeglobals/kde-colors modules replaced by plasma-manager. Per-DE XDG portal routing via `xdg.portal.config`.

**Tech Stack:** NixOS, Home Manager, flake-parts, plasma-manager, catppuccin-kde, KDE Plasma 6

**Spec:** `docs/superpowers/specs/2026-03-17-kde-plasma-de-design.md`

---

### Task 1: Add plasma-manager flake input

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add plasma-manager input to flake.nix**

In the `#region Theming` section (after the catppuccin entries around line 113), add:

```nix
plasma-manager = {
  url = "github:nix-community/plasma-manager";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
```

plasma-manager is not on FlakeHub, so GitHub URL is required.

- [ ] **Step 2: Update the lock file**

Run: `nix flake update plasma-manager`
Expected: Lock file updated with plasma-manager entry.

- [ ] **Step 3: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat: add plasma-manager flake input"
```

---

### Task 2: Create NixOS KDE module and update GUI options

This task creates `kde.nix` first, then updates `default.nix` and `hyprland.nix`. The ordering ensures `./kde.nix` exists before `default.nix` imports it.

**Files:**
- Create: `modules/nixos/gui/kde.nix`
- Modify: `modules/nixos/gui/default.nix`
- Modify: `modules/nixos/gui/hyprland.nix`

- [ ] **Step 1: Create `modules/nixos/gui/kde.nix`**

```nix
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.rat.gui;
in {
  options.rat.gui.kde = {
    enable = mkEnableOption "KDE Plasma 6 desktop environment";
  };

  config = mkIf (cfg.enable && cfg.kde.enable) {
    services.desktopManager.plasma6.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.kdePackages.xdg-desktop-portal-kde
      ];
      config.KDE = {
        default = ["kde"];
      };
    };
  };
}
```

**Note:** The XDG portal config key `KDE` corresponds to the `XDG_CURRENT_DESKTOP` value for KDE Plasma. Verify this during testing.

- [ ] **Step 2: Update `modules/nixos/gui/default.nix`**

Replace the current content. Key changes:
- Add `rat.gui.defaultSession` option (enum)
- Import `./kde.nix`
- Wire `services.displayManager.defaultSession`

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
in {
  imports = [
    ./gnome-keyring.nix
    ./greeter
    ./hyprland.nix
    ./kde.nix
    ./plymouth.nix
  ];

  options.rat.gui = {
    enable = mkEnableOption "gui";

    defaultSession = mkOption {
      default = "hyprland-uwsm";
      type = types.enum ["hyprland-uwsm" "plasma"];
      description = "The default desktop session for the display manager";
    };

    greeter.variant = mkOption {
      default = "tuigreet";
      type = types.enum ["tuigreet" "sddm"];
      description = "The display manager / greeter to use";
    };

    chat.enable = mkEnableOption "chat clients" // {default = true;};
    media.enable = mkEnableOption "media software" // {default = true;};
    productivity.enable = mkEnableOption "productivity software" // {default = true;};
    development.enable = mkEnableOption "graphical development tools" // {default = true;};
  };

  config = mkIf config.rat.gui.enable {
    services.displayManager.defaultSession = config.rat.gui.defaultSession;

    boot = {
      extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
      kernelModules = ["v4l2loopback"];
    };
  };
}
```

**Note:** The exact KDE Plasma 6 session name is likely `"plasma"` but should be verified against `services.desktopManager.plasma6` during testing. Check with `ls /run/current-system/sw/share/wayland-sessions/` after building.

- [ ] **Step 3: Update `modules/nixos/gui/hyprland.nix`**

Add the `rat.gui.hyprland.enable` option. Gate all config on it. Remove `services.displayManager.defaultSession` (moved to `default.nix`). Add per-DE portal config.

```nix
{
  config,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib) options types;
  cfg = config.rat.gui;
in {
  options.rat.gui.hyprland = {
    enable = options.mkEnableOption "Hyprland window manager" // {default = true;};

    monitors = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Default monitor configuration for this host";
      example = [
        "DP-2,3840x2160@60.0,0x1080,1.0"
        "HDMI-A-1,3840x2160@60.0,960x0,2.0"
      ];
    };

    primaryMonitor = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Primary monitor ID for waybar, hyprlock, etc.";
      example = "DP-2";
    };

    tvMonitor = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "TV monitor ID for media applications (MPV, etc.). If null, TV-specific rules are disabled.";
      example = "HDMI-A-1";
    };

    workspaces = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Default workspace configuration for this host";
      example = [
        "1, monitor:DP-2, persistent=true"
        "2, monitor:DP-2, persistent=true"
      ];
    };
  };

  config = mkIf (cfg.enable && cfg.hyprland.enable) {
    programs.hyprland = {
      enable = true;
      withUWSM = true;

      package = inputs'.hyprland.packages.hyprland;
      portalPackage = inputs'.hyprland.packages.xdg-desktop-portal-hyprland;
    };

    security.pam.services.hyprlock = {};

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        config.programs.hyprland.portalPackage
        xdg-desktop-portal-gtk
      ];
      config.hyprland = {
        default = ["hyprland" "gtk"];
      };
    };
  };
}
```

- [ ] **Step 4: Verify evaluation**

Run: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`
Expected: Derivation path output (no errors). This confirms all three files work together.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/gui/kde.nix modules/nixos/gui/default.nix modules/nixos/gui/hyprland.nix
git commit -m "feat: add KDE Plasma NixOS module and DE toggle options

- New rat.gui.kde.enable option enables KDE Plasma 6 with per-DE
  XDG portal routing
- New rat.gui.hyprland.enable option (default true) gates Hyprland
- New rat.gui.defaultSession enum controls display manager default
- Move defaultSession from hyprland.nix to default.nix"
```

---

### Task 3: Fix SDDM compositor command

**Files:**
- Modify: `modules/nixos/gui/greeter/sddm.nix`

- [ ] **Step 1: Make SDDM compositor command conditional**

The current `sddm.nix` hardcodes `config.programs.hyprland.package` as the SDDM Wayland compositor. This breaks if Hyprland is disabled. Split the compositor command into its own `mkIf` block:

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.rat.gui;
  impermanenceCfg = config.rat.impermanence;
in {
  config = mkMerge [
    (mkIf (cfg.enable && cfg.greeter.variant == "sddm") {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
        settings.General.GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
      };
    })
    (mkIf (cfg.enable && cfg.greeter.variant == "sddm" && cfg.hyprland.enable) {
      services.displayManager.sddm.settings.Wayland.CompositorCommand =
        "${lib.getExe config.programs.hyprland.package}";
    })
    (mkIf (cfg.enable && cfg.greeter.variant == "sddm" && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = ["/var/lib/sddm"];
      };
    })
  ];
}
```

- [ ] **Step 2: Verify evaluation**

Run: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`
Expected: Derivation path output (no errors).

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/gui/greeter/sddm.nix
git commit -m "fix: make SDDM compositor command conditional on Hyprland

Split into separate mkIf block to prevent referencing a non-existent
Hyprland package in KDE-only configurations."
```

---

### Task 4: Add KDE option to Home Manager shared options

**Files:**
- Modify: `modules/shared/users/gui.nix`

- [ ] **Step 1: Add `kde` option block**

In `modules/shared/users/gui.nix`, add the `kde` option block inside the `guiOptions` submodule, right after the closing `};` of the `hyprland` block (after line 113, before the `chat` block):

```nix
      kde = {
        enable = options.mkEnableOption "KDE Plasma configuration" // {default = true;};
      };
```

This goes at the same indentation level as `hyprland = {` and `chat = {`.

- [ ] **Step 2: Verify evaluation**

Run: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`
Expected: Derivation path output (no errors).

- [ ] **Step 3: Commit**

```bash
git add modules/shared/users/gui.nix
git commit -m "feat: add rat.users.*.gui.kde option

Adds per-user KDE Plasma enable option (default true), matching
the hyprland.enable pattern."
```

---

### Task 5: Import plasma-manager and migrate kdeglobals theming

**Files:**
- Modify: `modules/home-manager/theming/default.nix`
- Remove: `modules/home-manager/theming/kde-colors.nix`
- Remove: `modules/home-manager/desktop/kdeglobals.nix`
- Modify: `modules/home-manager/desktop/default.nix`

This task replaces the broken `rat.kdeglobals` + `kde-colors.nix` approach with plasma-manager. The plasma-manager module is imported unconditionally in theming so it manages kdeglobals for KDE apps under any DE.

**Important:** This task does NOT add `./kde` to `desktop/default.nix` imports — that happens in Task 6 after the directory is created.

- [ ] **Step 1: Update `modules/home-manager/theming/default.nix`**

Replace the import of `./kde-colors.nix` with `inputs.plasma-manager.homeModules.plasma-manager`. Add plasma-manager color scheme configuration in place of the old `rat.kdeglobals` approach.

**Note:** The module export path is `homeModules.plasma-manager` (NOT the deprecated `homeManagerModules`).

```nix
{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  themingCfg = userCfg.theming or {};
  guiCfg = userCfg.gui or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);
in {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    inputs.plasma-manager.homeModules.plasma-manager

    ./steam.nix
  ];

  config = modules.mkIf themingCfg.enable (modules.mkMerge [
    {
      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [".config/dconf"];
      };

      catppuccin = {
        enable = true;
        inherit (osConfig.catppuccin) flavor;
        inherit (osConfig.catppuccin) accent;
      };
    }

    (modules.mkIf guiCfg.enable {
      catppuccin = {
        gtk.icon.enable = true;
        cursors.enable = true;
        kvantum.enable = true;
        waybar.mode = "createLink";
      };

      gtk = {
        enable = true;

        font = {
          name = "SF Pro Display";
          size = 13;
        };

        theme = {
          package = pkgs.adw-gtk3;
          name = "adw-gtk3-dark";
        };

        gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
        gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
        gtk3.extraCss = builtins.readFile ./gtk3/gtk.css;
        gtk4.extraCss = builtins.readFile ./gtk4/gtk.css;
      };

      xdg.configFile."gtk-4.0/colors.css".source = ./gtk4/colors.css;

      dconf = {
        enable = true;
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
          };

          "org/gnome/desktop/wm/preferences" = {
            button-layout = "";
          };
        };
      };

      qt = {
        enable = true;
        platformTheme.name = "kvantum";
        style.name = "kvantum";
      };

      # KDE color scheme via plasma-manager (replaces kde-colors.nix + kdeglobals.nix)
      programs.plasma.workspace.colorScheme = "Catppuccin${capitalizeFirst config.catppuccin.flavor}${capitalizeFirst config.catppuccin.accent}";

      home.packages = [
        (pkgs.catppuccin-kde.override {
          flavour = [config.catppuccin.flavor];
          accents = [config.catppuccin.accent];
          winDecStyles = ["modern"];
        })
      ];
    })
  ]);
}
```

**Key changes from original:**
- Added `inputs.plasma-manager.homeModules.plasma-manager` to imports
- Removed `./kde-colors.nix` import
- Added `capitalizeFirst` helper (moved from `kde-colors.nix`)
- Added `programs.plasma.workspace.colorScheme` to set Catppuccin via plasma-manager
- Added `catppuccin-kde` package to install color scheme files

**Verification tip:** To confirm the color scheme name is correct, after building you can run:
`ls $(nix build .#catppuccin-kde --print-out-paths)/share/color-schemes/`

- [ ] **Step 2: Remove `modules/home-manager/theming/kde-colors.nix`**

```bash
git rm modules/home-manager/theming/kde-colors.nix
```

- [ ] **Step 3: Remove `modules/home-manager/desktop/kdeglobals.nix`**

```bash
git rm modules/home-manager/desktop/kdeglobals.nix
```

- [ ] **Step 4: Update `modules/home-manager/desktop/default.nix`**

Remove only the `./kdeglobals.nix` import. Do NOT add `./kde` yet (that happens in Task 6):

```nix
{
  imports = [
    ./browsers
    ./chat
    ./development
    ./gaming
    ./hyprland
    ./media
    ./productivity
    ./terminals
    ./ai.nix
    ./security.nix
    ./utilities.nix
  ];
}
```

- [ ] **Step 5: Verify evaluation**

Run: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`
Expected: Derivation path output (no errors).

- [ ] **Step 6: Commit**

```bash
git add modules/home-manager/theming/default.nix modules/home-manager/desktop/default.nix
git commit -m "feat: replace kdeglobals/kde-colors with plasma-manager

Import plasma-manager unconditionally in theming module. Configure
Catppuccin color scheme via programs.plasma.workspace.colorScheme
and install catppuccin-kde package. Remove broken kdeglobals.nix
and kde-colors.nix modules."
```

---

### Task 6: Create Home Manager KDE Plasma session module

**Files:**
- Create: `modules/home-manager/desktop/kde/default.nix`
- Modify: `modules/home-manager/desktop/default.nix`

- [ ] **Step 1: Create `modules/home-manager/desktop/kde/default.nix`**

This module configures the full KDE Plasma session experience — panel, window decorations, kwin, splash screen, fonts, etc. It only activates when both the system and user have KDE enabled.

```nix
{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  kdeCfg = guiCfg.kde or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);

  flavorName = capitalizeFirst config.catppuccin.flavor;
  accentName = capitalizeFirst config.catppuccin.accent;
in {
  config = modules.mkIf (
    guiCfg.enable
    && kdeCfg.enable
    && osConfig.rat.gui.kde.enable
  ) {
    programs.plasma = {
      enable = true;
      overrideConfig = false;

      workspace = {
        theme = "default";
        lookAndFeel = "Catppuccin-${flavorName}-${accentName}";
        windowDecorations = {
          library = "org.kde.kwin.aurorae";
          theme = "__aurorae__svg__Catppuccin${flavorName}-Modern";
        };
        splashScreen.theme = "Catppuccin-${flavorName}-${accentName}";
      };

      fonts = {
        general = {
          family = "SF Pro Display";
          pointSize = 13;
        };
        fixedWidth = {
          family = "SF Mono";
          pointSize = 12;
        };
      };

      kwin = {
        effects = {
          translucency.enable = true;
          blur.enable = true;
        };
      };

      configFile = {
        kdeglobals = {
          KDE.AnimationDurationFactor = 0.5;
        };
      };
    };

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/baloo"
        ".local/share/kactivitymanagerd"
        ".local/share/kwalletd"
        ".local/share/kscreen"
        ".config/kde.org"
        ".config/kdedefaults"
      ];
      files = [
        ".config/kwinrc"
        ".config/plasma-org.kde.plasma.desktop-appletsrc"
        ".config/plasmashellrc"
        ".config/kconf_updaterc"
      ];
    };
  };
}
```

**Notes:**
- `overrideConfig = false` — lets users customize Plasma without plasma-manager resetting on every activation. Can be changed to `true` later for fully declarative config.
- The `lookAndFeel` and `windowDecorations.theme` names come from the `catppuccin-kde` package. The exact names may need adjustment during testing — verify with `plasma-apply-lookandfeel --list` after installing the package.
- Config files (`kwinrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc`, `kconf_updaterc`) go under `files` in impermanence; directories (`baloo`, `kactivitymanagerd`, `kwalletd`, `kscreen`, `kde.org`, `kdedefaults`) go under `directories`.
- This list will likely need expansion during testing. Add paths as needed.

- [ ] **Step 2: Add `./kde` to `modules/home-manager/desktop/default.nix` imports**

```nix
{
  imports = [
    ./browsers
    ./chat
    ./development
    ./gaming
    ./hyprland
    ./kde
    ./media
    ./productivity
    ./terminals
    ./ai.nix
    ./security.nix
    ./utilities.nix
  ];
}
```

- [ ] **Step 3: Verify evaluation**

Run: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`
Expected: Derivation path output (no errors). The KDE HM module should load but not activate since `rat.gui.kde.enable` is still false on ulysses.

- [ ] **Step 4: Commit**

```bash
git add modules/home-manager/desktop/kde/default.nix modules/home-manager/desktop/default.nix
git commit -m "feat: add Home Manager KDE Plasma session module

Configures KDE Plasma with Catppuccin look-and-feel, window
decorations, fonts, kwin effects, and impermanence support
via plasma-manager."
```

---

### Task 7: Enable KDE on Ulysses

**Files:**
- Modify: `systems/ulysses/default.nix`

- [ ] **Step 1: Add `kde.enable = true` to Ulysses config**

In `systems/ulysses/default.nix`, add `kde.enable = true;` inside the `rat.gui` block (around line 132, after `enable = true;`):

```nix
    gui = {
      enable = true;
      kde.enable = true;
      hyprland = {
```

- [ ] **Step 2: Verify evaluation**

Run: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`
Expected: Derivation path output (no errors). This is the critical test — both DEs enabled simultaneously.

- [ ] **Step 3: Verify other hosts still evaluate**

Run: `nix eval .#nixosConfigurations.hyperion.config.system.build.toplevel.drvPath`
Run: `nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath`
Expected: Both succeed. These hosts don't set `kde.enable = true`, so KDE should not activate for them.

- [ ] **Step 4: Verify KDE session file exists in build output**

Run: `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel --no-link --print-out-paths`
Then: `ls <output-path>/sw/share/wayland-sessions/`
Expected: Should contain both `hyprland-uwsm.desktop` (or similar) and `plasma.desktop` (or similar). This confirms tuigreet will discover both sessions. Note the exact KDE session filename — if it's not `plasma.desktop`, the `rat.gui.defaultSession` enum may need updating.

- [ ] **Step 5: Commit**

```bash
git add systems/ulysses/default.nix
git commit -m "feat: enable KDE Plasma on Ulysses

Both Hyprland and KDE Plasma are now available as session
options at the display manager on Ulysses."
```

---

### Task 8: Format and final verification

- [ ] **Step 1: Run formatter**

Run: `nix fmt`
Expected: All files formatted. Fix any formatting issues.

- [ ] **Step 2: Commit formatting changes if any**

```bash
git add -A
git commit -m "style: format nix files"
```

- [ ] **Step 3: Full evaluation check**

Run: `nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath`
Run: `nix eval .#nixosConfigurations.hyperion.config.system.build.toplevel.drvPath`
Run: `nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath`
Expected: All three succeed.

- [ ] **Step 4: Build Ulysses config (optional, confirms full build)**

Run: `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel --no-link`
Expected: Build succeeds (this may take a while as it fetches KDE Plasma packages).
