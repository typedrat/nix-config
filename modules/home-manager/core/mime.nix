{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  mimeCfg = userCfg.mime or {};
in {
  config = modules.mkIf (mimeCfg.enable or false) {
    xdg.mimeApps = {
      enable = true;
      inherit (mimeCfg) defaultApplications;
      associations = {
        inherit (mimeCfg.associations) added;
        inherit (mimeCfg.associations) removed;
      };
    };

    # Ensure xdg-utils is available for xdg-open and MIME handling
    home.packages = with pkgs; [
      xdg-utils
    ];
  };
}
