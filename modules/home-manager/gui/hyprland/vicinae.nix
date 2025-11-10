{
  config,
  osConfig,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
in {
  imports = [
    inputs.vicinae.homeManagerModules.default
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false) && (hyprlandCfg.launcher or "rofi") == "vicinae") {
    services.vicinae = {
      enable = true;
      autoStart = true;
      settings = {
        theme = {
          name = "catppuccin-frappe";
          iconTheme = "Catppuccin Frappé Lavender";
        };

        font = {
          size = 10.5;
        };

        popToRootOnClose = true;
        rootSearch = {
          searchFiles = true;
        };

        window = {
          csd = true;
          opacity = 0.625;
          rounding = 10;
        };
      };
    };

    wayland.windowManager.hyprland.settings = {
      layerrule = [
        "blur, vicinae"
        "ignorealpha 0, vicinae"
        "noanim, vicinae"
      ];

      windowrulev2 = [
        "plugin:hyprbars:nobar, title:^Vicinae Launcher$"
      ];

      bind = [
        "$main_mod, space, exec, vicinae toggle"
        "$main_mod, b, exec, vicinae vicinae://extensions/vicinae/wm/switch-windows"
        "$main_mod, v, exec, vicinae vicinae://extensions/vicinae/clipboard/history"
        "$main_mod&SHIFT, period, exec, vicinae vicinae://extensions/vicinae/vicinae/search-emojis"
      ];
    };
  };
}
