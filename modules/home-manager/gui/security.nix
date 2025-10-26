{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
in {
  config = modules.mkIf ((guiCfg.enable or false) && (guiCfg.security.enable or false)) {
    home.packages = with pkgs; [
      bitwarden-desktop
    ];
  };
}
