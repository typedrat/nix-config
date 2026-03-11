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
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.tools.enable or false)) {
    home.packages = with pkgs; [
      ethtool
      lm_sensors
      lsof
      ltrace
      pciutils
      strace
      sysstat
      usbutils
    ];

    programs.bottom.enable = true;

    programs.btop = {
      enable = true;
      package = pkgs.btop-cuda;
    };
  };
}
