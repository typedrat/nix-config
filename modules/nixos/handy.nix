# System-level enablement for Handy offline speech-to-text.
#
# Activates automatically whenever an enabled user turns on
# rat.users.<name>.gui.productivity.handy.enable (mirrors the home-manager
# guard in modules/home-manager/desktop/productivity/handy.nix). Pulls in the
# upstream NixOS module (programs.handy) which installs the package and adds
# the /dev/uinput udev rule that rdev's global-hotkey grab() needs, then wires
# up the bits the package wrapper cannot: the uinput kernel module, "input"
# group membership and the Wayland text-injection helper.
#
# Shortcut backends for push-to-talk on Wayland:
#   - "tauri"      X11 XGrabKey: press-only, doesn't grab on Wayland. No PTT.
#   - "handy_keys" evdev: reports release as well as press (PTT works), but
#                  needs /dev/input access — hence the uinput module + "input"
#                  group below.
#   - "portal"     xdg-desktop-portal GlobalShortcuts: the native Wayland
#                  mechanism (works via xdg-desktop-portal-hyprland / KDE),
#                  full press+release, no device-access plumbing needed.
#                  Added by the patched package below (cjpais/Handy#1287).
# The backend is selected declaratively via
# rat.users.<name>.gui.productivity.handy.keyboardImplementation.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules;

  userHasHandy = userCfg:
    userCfg.enable
    && (userCfg.gui.enable or false)
    && (userCfg.gui.productivity.enable or false)
    && (userCfg.gui.productivity.handy.enable or false);

  handyUsers = lib.filterAttrs (_: userHasHandy) config.rat.users;

  system = pkgs.stdenv.hostPlatform.system;

  # Apply cjpais/Handy#1287 — adds the xdg-desktop-portal GlobalShortcuts
  # backend ("portal"). The PR's own Cargo.lock hunk was rebased onto our
  # locked 0.8.3 source (only the new `ashpd` crate is added; its transitive
  # deps already resolve in the lock). Refresh or drop this patch when the
  # handy input advances or the PR merges upstream.
  patchedSrc = pkgs.applyPatches {
    name = "handy-src-pr1287-portal";
    src = inputs.handy;
    patches = [../../patches/handy-pr1287-portal-globalshortcuts.patch];
  };

  # buildRustPackage bakes cargoDeps from the original lock, so override both
  # the source and the vendored deps to pick up the patched Cargo.lock.
  handyPackage = inputs.handy.packages.${system}.handy.overrideAttrs (_: {
    src = patchedSrc;
    cargoDeps = pkgs.rustPlatform.importCargoLock {
      lockFile = "${patchedSrc}/src-tauri/Cargo.lock";
      allowBuiltinFetchGit = true;
    };
  });
in {
  imports = [
    inputs.handy.nixosModules.default
  ];

  config = modules.mkIf (handyUsers != {}) {
    # Installs handy system-wide and adds the uinput udev rule (group "input").
    programs.handy.enable = true;

    # Use the patched build that adds the "portal" shortcut backend.
    programs.handy.package = handyPackage;

    # Ensure /dev/uinput exists so the udev rule applies and the handy_keys
    # backend can create its virtual input device for global-hotkey grabbing.
    # (Not needed by the "portal" backend, but harmless and keeps handy_keys
    # available as a fallback.)
    boot.kernelModules = ["uinput"];

    # wtype performs text injection on Wayland (Hyprland). Keep it on the system
    # PATH so the handy process finds it regardless of how it was launched.
    environment.systemPackages = [pkgs.wtype];

    # Global hotkeys via evdev/uinput need the user in the "input" group; the
    # udev rule above grants that group access to /dev/uinput.
    users.users = lib.mapAttrs (_: _: {extraGroups = ["input"];}) handyUsers;
  };
}
