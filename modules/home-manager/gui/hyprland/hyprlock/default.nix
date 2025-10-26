{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
in {
  config = modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false)) {
    catppuccin.hyprlock.useDefaultConfig = false;

    programs.hyprlock = {
      enable = true;
      package = inputs.hyprlock.packages."${pkgs.stdenv.system}".hyprlock;

      extraConfig = lib.readFile ./hyprlock.conf;
    };
  };
}
