# KDE Plasma as Alternate Desktop Environment

## Summary

Add KDE Plasma 6 as a full standalone desktop environment option alongside Hyprland, selectable at the display manager login screen. Both DEs can be enabled simultaneously on a system. App-level toggles (browsers, chat, dev tools, media, etc.) are shared and DE-agnostic; only DE shell components differ.

## Requirements

- KDE Plasma 6 as a full session selectable at the display manager
- Both Hyprland and KDE can be enabled simultaneously
- Catppuccin theming as deeply integrated as possible
- Shared app categories across DEs
- Greeter choice remains independent of DE choice
- Impermanence support for KDE state

## Approach

Top-level DE options at both NixOS and Home Manager levels, following existing patterns. No shared DE abstraction — Hyprland and KDE are too different to benefit from one.

## NixOS Layer

### New options in `modules/nixos/gui/default.nix`

- `rat.gui.kde.enable` (bool, default `false`) — enables KDE Plasma 6
- `rat.gui.hyprland.enable` (bool, default `true`) — gates Hyprland setup (currently implicit)
- `rat.gui.defaultSession` (enum `["hyprland-uwsm" "plasma"]`, default `"hyprland-uwsm"`) — controls `services.displayManager.defaultSession`

### New module: `modules/nixos/gui/kde.nix`

Gated on `rat.gui.enable && rat.gui.kde.enable`. Configures:

- `services.desktopManager.plasma6.enable = true`
- XDG desktop portal: `xdg-desktop-portal-kde` added only when Hyprland is NOT also enabled (portal conflict). When both DEs are active, Hyprland's portal setup takes precedence.

### Changes to `modules/nixos/gui/hyprland.nix`

- Gate `programs.hyprland.enable` and all Hyprland NixOS config on `rat.gui.hyprland.enable` (in addition to existing `rat.gui.enable` gate)
- Move `services.displayManager.defaultSession` out — it's now controlled by `rat.gui.defaultSession` in `default.nix`
- The existing Hyprland-specific options (`rat.gui.hyprland.monitors`, `primaryMonitor`, `tvMonitor`, `workspaces`) stay unchanged

## Home Manager Options Layer (`modules/shared/users/gui.nix`)

Add at the same level as `hyprland`:

```nix
kde = {
  enable = mkEnableOption "KDE Plasma configuration" // { default = true; };
};
```

Defaults to `true` so enabling `rat.gui.kde.enable` at NixOS level automatically gives users the KDE config (same pattern as `hyprland.enable`).

No sub-options initially — KDE Plasma is batteries-included. Options can be added later if needed.

## Home Manager KDE Module (`modules/home-manager/desktop/kde/`)

New module tree, imported from `modules/home-manager/desktop/default.nix`.

Gated on: `guiCfg.enable && kdeCfg.enable && osConfig.rat.gui.kde.enable`

### plasma-manager Integration

Uses the `plasma-manager` Home Manager module (new flake input) for declarative KDE Plasma configuration. Configures:

- **Color scheme**: Catppuccin colors via `plasma-manager` options (replaces the broken `kdeglobals.nix` approach)
- **Plasma theme**: Catppuccin Plasma theme (window decorations, panel, splash screen)
- **Fonts**: SF Pro Display to match GTK config
- **Window decorations**: Catppuccin-themed via kwin settings
- **Dark mode**: Forced dark color scheme

### Impermanence

Persists KDE state directories under `home.persistence.${persistDir}`:

- `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
- `~/.config/kwinrc`
- `~/.config/plasmashellrc`
- `~/.local/share/baloo/`
- `~/.local/share/kactivitymanagerd/`
- `~/.local/share/kwalletd/`
- Other KDE state dirs as needed

## Flake Input

New input: `plasma-manager` (prefer FlakeHub, fall back to `github:nix-community/plasma-manager`).

Imported unconditionally in Home Manager shared modules — it's a no-op when not configured. This allows `plasma-manager` to manage kdeglobals for both KDE Plasma sessions AND KDE apps running under Hyprland.

## Removals

- **`modules/home-manager/desktop/kdeglobals.nix`**: Remove entirely. The `rat.kdeglobals` option and INI generation approach is replaced by `plasma-manager`.
- **`modules/home-manager/theming/kde-colors.nix`**: Remove entirely. Its color scheme output was consumed by `kdeglobals.nix`. Catppuccin colors will be set via `plasma-manager` instead.
- Update imports in `modules/home-manager/desktop/default.nix` and `modules/home-manager/theming/default.nix` accordingly.

## Existing `hyprland.kde` Interaction

`rat.users.*.gui.hyprland.kde.enable` stays unchanged. It installs KDE packages (plasma-workspace, kio, Dolphin, Okular, etc.) needed to run KDE apps under Hyprland. Under a KDE Plasma session these packages are redundant but harmless.

## Ulysses Configuration

Minimal changes to `systems/ulysses/default.nix`:

```nix
rat.gui = {
  enable = true;
  kde.enable = true;
  # hyprland.enable defaults to true — no change needed
  # defaultSession defaults to "hyprland-uwsm" — no change needed
  hyprland = { ... }; # unchanged
};
```

User config (`rat.users.awilliams.gui`) needs no changes — `kde.enable` defaults to `true`.

## Files to Create

- `modules/nixos/gui/kde.nix`
- `modules/home-manager/desktop/kde/default.nix` (new KDE Plasma HM module, distinct from existing `hyprland/kde/`)

## Files to Modify

- `flake.nix` — add `plasma-manager` input
- `modules/nixos/gui/default.nix` — add `kde.enable`, `hyprland.enable`, `defaultSession` options; import `kde.nix`
- `modules/nixos/gui/hyprland.nix` — gate on `rat.gui.hyprland.enable`; remove `defaultSession`
- `modules/shared/users/gui.nix` — add `kde` option block
- `modules/home-manager/desktop/default.nix` — import `./kde`; remove `./kdeglobals.nix`
- `modules/home-manager/theming/default.nix` — remove `./kde-colors.nix` import
- `systems/ulysses/default.nix` — add `rat.gui.kde.enable = true`
- Home Manager shared module imports (in `nixos-hosts.nix` or equivalent) — add `plasma-manager` module

## Files to Remove

- `modules/home-manager/desktop/kdeglobals.nix`
- `modules/home-manager/theming/kde-colors.nix`
