{
  inputs,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    inputs.mcmojave-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    hyprpolkitagent
    mpvpaper
    waypaper
    nwg-look
    nwg-dock-hyprland
    nwg-drawer
    (xfce.thunar.override {
      thunarPlugins = with pkgs.xfce; [
        thunar-volman
      ];
    })
    flameshot
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;

    package = null;
    portalPackage = null;

    settings = {
      monitor = [
        "DP-2,3840x2160@60.0,0x1080,1.0"
        "HDMI-A-1,3840x2160@60.0,960x0,2.0"
      ];
      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "waypaper --restore"
        "nwg-drawer -r -term wezterm -wm hyprland"
        "firefox"
        "wezterm"
      ];
    };
  };

  home.sessionVariables.HYPRCURSOR_THEME = "McMojave";
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  services.mako = {
    enable = true;
    defaultTimeout = 30;
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "podif hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  programs.hyprlock.enable = true;

  programs.eww = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.kitty.enable = true;
}
