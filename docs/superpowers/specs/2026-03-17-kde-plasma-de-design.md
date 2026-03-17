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

### New options

- `rat.gui.kde.enable` (bool, default `false`) — defined in `modules/nixos/gui/kde.nix`
- `rat.gui.hyprland.enable` (bool, default `true`) — defined in `modules/nixos/gui/hyprland.nix` (alongside existing Hyprland options)
- `rat.gui.defaultSession` (enum `["hyprland-uwsm" "plasma"]`, default `"hyprland-uwsm"`) — defined in `modules/nixos/gui/default.nix`

Each DE's enable option lives in its own module file, consistent with how `rat.gui.hyprland.monitors` etc. already live in `hyprland.nix`. The `defaultSession` option is DE-agnostic so it stays in `default.nix`.

**Note**: The exact KDE Plasma 6 session name (likely `"plasma"`) must be verified against the NixOS `services.desktopManager.plasma6` module during implementation.

### New module: `modules/nixos/gui/kde.nix`

Gated on `rat.gui.enable && rat.gui.kde.enable`. Configures:

- `services.desktopManager.plasma6.enable = true`

### XDG Desktop Portal Configuration

When both DEs are enabled, both portal backends must be installed, with per-DE routing via `xdg.portal.config`:

```nix
xdg.portal.config = {
  hyprland = {
    default = ["hyprland" "gtk"];
  };
  KDE = {
    default = ["kde"];
  };
};
```

- `hyprland.nix` adds `xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk` to `extraPortals` (as it does now) and sets the `hyprland` portal config
- `kde.nix` adds `xdg-desktop-portal-kde` to `extraPortals` and sets the `KDE` portal config
- Both portal configs merge via NixOS's `mkMerge` — no conditional exclusion needed

### Changes to `modules/nixos/gui/hyprland.nix`

- Add `rat.gui.hyprland.enable` option (default `true`)
- Gate `programs.hyprland.enable` and all Hyprland NixOS config on `rat.gui.hyprland.enable` (in addition to existing `rat.gui.enable` gate)
- Remove `services.displayManager.defaultSession` — now controlled by `rat.gui.defaultSession` in `default.nix`
- Add `xdg.portal.config.hyprland` for per-DE portal routing
- Existing Hyprland-specific options (`monitors`, `primaryMonitor`, `tvMonitor`, `workspaces`) stay unchanged

### Changes to `modules/nixos/gui/default.nix`

- Add `rat.gui.defaultSession` option
- Wire `services.displayManager.defaultSession` to `rat.gui.defaultSession`
- Import `./kde.nix`

### Changes to `modules/nixos/gui/greeter/sddm.nix`

The SDDM module currently hardcodes `CompositorCommand` to `config.programs.hyprland.package`. This must become conditional:

- If Hyprland is enabled: use `config.programs.hyprland.package` (current behavior)
- If only KDE is enabled: use `kwin_wayland` or omit (SDDM can use its own compositor)

This prevents a reference to a non-existent Hyprland package in KDE-only configurations.

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

### plasma-manager Import Strategy

The plasma-manager Home Manager module has a two-layer import:

1. **Module import** (unconditional): `inputs.plasma-manager.homeManagerModules.plasma-manager` is imported in `modules/home-manager/theming/default.nix` — this makes plasma-manager options available regardless of DE choice, since kdeglobals theming applies to KDE apps under any DE. This follows the existing pattern (e.g., `inputs.catppuccin.homeModules.catppuccin` is imported in the same file).

2. **KDE session configuration** (gated on `guiCfg.enable && kdeCfg.enable && osConfig.rat.gui.kde.enable`): The full Plasma shell configuration (panel, kwin, splash, etc.) lives in `modules/home-manager/desktop/kde/default.nix` and only activates for KDE-enabled systems/users.

### Catppuccin Theming via plasma-manager

Configured in `modules/home-manager/theming/` (replacing `kde-colors.nix`), active when `themingCfg.enable && guiCfg.enable`:

- **Color scheme**: Catppuccin colors via plasma-manager's workspace color scheme options
- **Fonts**: SF Pro Display to match GTK config

### KDE Session Configuration

Configured in `modules/home-manager/desktop/kde/default.nix`, active when KDE is enabled:

- **Plasma theme**: Catppuccin Plasma theme (window decorations, panel, splash screen)
- **Window decorations**: Catppuccin-themed via kwin settings
- **Dark mode**: Forced dark color scheme
- **Other Plasma shell settings** as appropriate

### Qt Theming Consideration

The existing theming module sets `qt.platformTheme.name = "kvantum"` and `qt.style.name = "kvantum"`. Under KDE Plasma, Qt apps should ideally use the Plasma integration layer. However, since Home Manager config is static (not session-dependent), the pragmatic approach is:

- Keep Kvantum as the Qt theme for all sessions. Kvantum works well under both Hyprland and KDE Plasma, and the Catppuccin Kvantum theme provides consistent appearance across both DEs.
- If this causes issues under KDE Plasma during testing, revisit with session-specific environment variables or XDG autostart scripts.

### Impermanence

Persists KDE state directories under `home.persistence.${persistDir}`:

- `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
- `~/.config/kwinrc`
- `~/.config/plasmashellrc`
- `~/.local/share/baloo/`
- `~/.local/share/kactivitymanagerd/`
- `~/.local/share/kwalletd/`
- `~/.local/share/kscreen/` (multi-monitor layout)
- `~/.config/kde.org/`
- `~/.config/kdedefaults/`
- `~/.config/kconf_updaterc`

This list will likely need expansion during testing. Additional paths should be added as discovered.

## Flake Input

New input: `plasma-manager` (prefer FlakeHub, fall back to `github:nix-community/plasma-manager`).

## Removals

- **`modules/home-manager/desktop/kdeglobals.nix`**: Remove entirely. The `rat.kdeglobals` option and INI generation approach is replaced by `plasma-manager`.
- **`modules/home-manager/theming/kde-colors.nix`**: Remove entirely. Its color scheme output was consumed by `kdeglobals.nix`. Catppuccin colors will be set via `plasma-manager` instead.
- Update imports in `modules/home-manager/desktop/default.nix` and `modules/home-manager/theming/default.nix` accordingly.

## Existing `hyprland.kde` Interaction

`rat.users.*.gui.hyprland.kde.enable` stays unchanged. It installs KDE packages (plasma-workspace, kio, Dolphin, Okular, etc.) needed to run KDE apps under Hyprland. Under a KDE Plasma session these packages are redundant but harmless.

**Note**: The `applications.menu` file in `hyprland/kde/` may conflict with KDE Plasma's own menu definition. Verify during implementation and scope the menu file to Hyprland sessions if needed.

## Greeter Session Discovery

Verify during implementation that tuigreet (the default greeter) correctly discovers the KDE Plasma session file created by `services.desktopManager.plasma6.enable`. This should work automatically via XDG session desktop files, but should be confirmed.

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

## Implementation Order

To avoid broken intermediate states:

1. Add `plasma-manager` flake input
2. Create NixOS modules: `kde.nix`, update `default.nix` (new options, import), update `hyprland.nix` (add enable option, gate config, remove defaultSession)
3. Fix `sddm.nix` compositor command to be conditional
4. Update `modules/shared/users/gui.nix` with `kde` option block
5. Import `plasma-manager` HM module in `modules/home-manager/theming/default.nix`; migrate kdeglobals theming to `plasma-manager`
6. Create `modules/home-manager/desktop/kde/default.nix` with Plasma session config
7. Remove old `kdeglobals.nix` and `kde-colors.nix`; update imports
8. Update `modules/home-manager/desktop/default.nix` to import `./kde`
9. Update `systems/ulysses/default.nix` to enable KDE

## Files to Create

- `modules/nixos/gui/kde.nix`
- `modules/home-manager/desktop/kde/default.nix` (new KDE Plasma HM module, distinct from existing `hyprland/kde/`)

## Files to Modify

- `flake.nix` — add `plasma-manager` input
- `modules/nixos/gui/default.nix` — add `defaultSession` option; wire to `services.displayManager.defaultSession`; import `kde.nix`
- `modules/nixos/gui/hyprland.nix` — add `rat.gui.hyprland.enable` option; gate config on it; remove `defaultSession`; add portal config
- `modules/nixos/gui/greeter/sddm.nix` — make compositor command conditional on Hyprland availability
- `modules/shared/users/gui.nix` — add `kde` option block
- `modules/home-manager/desktop/default.nix` — import `./kde`; remove `./kdeglobals.nix` import
- `modules/home-manager/theming/default.nix` — import `plasma-manager` HM module; remove `./kde-colors.nix` import; add plasma-manager color config
- `systems/ulysses/default.nix` — add `rat.gui.kde.enable = true`

## Files to Remove

- `modules/home-manager/desktop/kdeglobals.nix`
- `modules/home-manager/theming/kde-colors.nix`
