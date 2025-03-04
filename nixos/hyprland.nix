{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  nix.settings = {
    extra-substituters = ["https://hyprland.cachix.org"];
    extra-trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;

    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    wayland = {
      enable = true;
      compositorCommand = "${lib.getExe config.programs.hyprland.package} --config /etc/sddm/hyprland.conf";
    };

    settings = {
      General = {
        GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
      };
    };
  };

  environment.etc."sddm/hyprland.conf".text = ''
    misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
        force_default_wallpaper = 0
        initial_workspace_tracking = 1
    }

    input {
        numlock_by_default = true
        kb_layout = us
    }

    cursor {
        no_warps = 1
        no_hardware_cursors = 1
    }

    monitor = , preferred, auto, 1
  '';

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
      config.programs.hyprland.portalPackage
      xdg-desktop-portal-gtk
    ];
  };
}
