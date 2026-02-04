{
  config,
  osConfig,
  lib,
  self',
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.comfy-cli.enable or false)) {
    programs.comfy-cli = {
      enable = true;
      package = self'.packages.comfy-cli;
    };
  };
}
