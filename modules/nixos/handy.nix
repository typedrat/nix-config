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
in {
  imports = [
    inputs.handy.nixosModules.default
  ];

  config = modules.mkIf (handyUsers != {}) {
    # Installs handy system-wide and adds the uinput udev rule (group "input").
    programs.handy.enable = true;

    # Ensure /dev/uinput exists so the udev rule applies and the handy_keys
    # backend can create its virtual input device for global-hotkey grabbing.
    boot.kernelModules = ["uinput"];

    # wtype performs text injection on Wayland (Hyprland). Keep it on the system
    # PATH so the handy process finds it regardless of how it was launched.
    environment.systemPackages = [pkgs.wtype];

    # Global hotkeys via evdev/uinput need the user in the "input" group; the
    # udev rule above grants that group access to /dev/uinput.
    users.users = lib.mapAttrs (_: _: {extraGroups = ["input"];}) handyUsers;
  };
}
