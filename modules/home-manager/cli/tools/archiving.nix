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
  config = modules.mkIf (cliCfg.enable && cliCfg.tools.enable) {
    home.packages = with pkgs; [
      _7zz-rar
      unrar
      unzip
      xz
      zip
      zstd
    ];
  };
}
