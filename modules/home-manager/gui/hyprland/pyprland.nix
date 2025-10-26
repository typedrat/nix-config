{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (inputs.pyprland.packages.${pkgs.stdenv.system}) pyprland;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
in {
  config = modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false)) {
    home.packages = [
      pyprland
    ];

    xdg.configFile."hypr/pyprland.toml".text = ''
      [pyprland]
      plugins = ["scratchpads", "monitors"]

      [scratchpads.term]
      animation = "fromTop"
      command = "wezterm start --always-new-process"
      class = "scratchpad"
      size = "75% 60%"
      max_size = "1920px 100%"
      margin = 50

      [scratchpads.btop]
      animation = "fromTop"
      command = "wezterm start --always-new-process --class scratchpad-btop btop"
      class = "scratchpad-btop"
      lazy = true
      size = "75% 60%"
      max_size = "1920px 100%"
      margin = 50
    '';

    wayland.windowManager.hyprland.settings = {
      exec-once = ["uwsm app -- pypr"];

      bind = [
        "$main_mod,grave,exec,pypr toggle term"
        "$main_mod,backtick,exec,pypr toggle btop"
      ];
    };
  };
}
