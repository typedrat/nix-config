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
    inputs.wayland-pipewire-idle-inhibit.homeModules.default
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false)) {
    services.wayland-pipewire-idle-inhibit = {
      enable = true;
      systemdTarget = "graphical-session.target";
      settings = {
        verbosity = "INFO";
        media_minimum_duration = 10;
        idle_inhibitor = "wayland";
        sink_whitelist = [];
        node_blacklist = [];
      };
    };
  };
}
