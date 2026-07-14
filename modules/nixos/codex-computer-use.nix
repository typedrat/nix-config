# System-level plumbing for Codex Desktop's Linux Computer Use backend
# (codex-computer-use-linux), enabled per-user in home-manager via
# programs.codexDesktopLinux.computerUseUi.
#
# The backend needs two things the desktop package cannot provide itself:
#
#   - Input injection. On Hyprland the XDG portal exposes Screenshot/ScreenCast
#     but not RemoteDesktop, so synthetic pointer/keyboard events cannot go
#     through the portal. The backend's preferred path opens /dev/uinput
#     directly instead, which needs the invoking user in the "uinput" group.
#     (ydotool would be a redundant second uinput wrapper, so it is omitted.)
#   - An accessibility bus. App listing and accessibility trees are read over
#     AT-SPI, which is dbus-activated but only present once at-spi2-core runs.
#
# Screenshots (portal) and window listing/focus (Hyprland IPC) already work
# from the existing desktop session.
{
  config,
  lib,
  ...
}: let
  guiUsers =
    lib.filterAttrs
    (_: userCfg: userCfg.enable && (userCfg.gui.enable or false))
    config.rat.users;
in {
  config = lib.mkIf (config.rat.gui.enable && config.rat.gui.chat.enable) {
    hardware.uinput.enable = true;
    services.gnome.at-spi2-core.enable = true;

    users.users = lib.mapAttrs (_: _: {extraGroups = ["uinput"];}) guiUsers;
  };
}
