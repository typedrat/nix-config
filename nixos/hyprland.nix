{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        enable = true;
        command = "${lib.getExe config.programs.hyprland.package} --config /etc/greetd/hyprland.conf";
        user = "greeter";
      };
    };
  };

  environment.etc."greetd/hyprland.conf".text = ''
    monitor = HDMI-A-1, disable
    exec-once = ${lib.getExe config.programs.regreet.package}; hyprctl dispatch exit
    env = GTK_USE_PORTAL,0
    env = GDK_DEBUG,no-portals
    misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
        disable_hyprland_qtutils_check = true
    }
  '';

  programs.regreet = {
    enable = true;
    settings = {
      appearance.greeting_msg = "Welcome back!";

      commands = {
        reboot = ["systemctl" "reboot"];
        poweroff = ["systemctl" "poweroff"];
      };

      widget.clock = {
        format = "%a %H:%M";
        resolution = "500ms";
      };
    };
  };

  # Enable sound.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable polkit
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (
        subject.isInGroup("users") &&
        [
          "org.freedesktop.login1.reboot",
          "org.freedesktop.login1.reboot-multiple-sessions",
          "org.freedesktop.login1.power-off",
          "org.freedesktop.login1.power-off-multiple-sessions",
        ].indexOf(action.id) !== -1
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  services.udisks2.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };
}
