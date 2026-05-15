{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkForce;
  cfg = config.rat.gui;

  seahorseAskpass = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  ksshAskpass = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

  # Runtime dispatch wrapper: picks the askpass that matches the desktop the
  # user is currently logged into. SSH_ASKPASS is a single system-wide value,
  # but $XDG_CURRENT_DESKTOP is per-session, so we defer the decision to exec
  # time. Under KDE we use ksshaskpass (Qt-native); everywhere else we use
  # seahorse's GTK askpass, which integrates with the gnome-keyring instance
  # we run on every GUI host.
  #
  # On hosts where KDE isn't even built, the wrapper degenerates to just
  # exec'ing seahorse — no point branching on a binary that doesn't exist.
  askpassDispatch = pkgs.writeShellScript "ssh-askpass-dispatch" (
    if cfg.kde.enable
    then ''
      case "''${XDG_CURRENT_DESKTOP:-}" in
        *KDE*) exec ${ksshAskpass} "$@" ;;
        *)     exec ${seahorseAskpass} "$@" ;;
      esac
    ''
    else ''
      exec ${seahorseAskpass} "$@"
    ''
  );
in {
  config = mkIf cfg.enable {
    security.pam.services.greetd.enableGnomeKeyring = true;
    security.pam.services.login.enableGnomeKeyring = true;

    # Seahorse manages keys/passwords in the GNOME Keyring and also ships a
    # GTK ssh-askpass helper. Enabling it here installs seahorse system-wide
    # and registers its D-Bus service so the "Passwords and Keys" UI works.
    programs.seahorse.enable = true;

    # Use the runtime dispatch wrapper above. Both programs.seahorse and
    # services.desktopManager.plasma6 set askPassword via mkDefault, which
    # collide on hosts running both (ulysses) and yield an empty string —
    # mkForce wins unconditionally.
    programs.ssh.askPassword = mkForce "${askpassDispatch}";

    # The nixpkgs default for enableAskPassword is services.xserver.enable,
    # which is false on Wayland-only sessions. Force it on so SSH_ASKPASS
    # gets exported into the user environment. The wrapper script in the
    # ssh module pulls WAYLAND_DISPLAY/DISPLAY/XAUTHORITY from the systemd
    # user environment, so the dispatched askpass works under Hyprland and KDE.
    programs.ssh.enableAskPassword = true;
  };
}
