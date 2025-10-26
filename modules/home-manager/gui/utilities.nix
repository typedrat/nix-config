{
  config,
  osConfig,
  self',
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
in {
  config = modules.mkIf ((guiCfg.enable or false) && (guiCfg.utilities.enable or false)) {
    home.packages = with pkgs; [
      qalculate-qt
      transmission_4-qt6
      waypipe
      wev
      self'.packages.xcursor-viewer
      self'.packages.zmk-studio
    ];
  };
}
