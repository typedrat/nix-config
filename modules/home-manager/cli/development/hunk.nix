{
  config,
  osConfig,
  inputs,
  inputs',
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  developmentCfg = cliCfg.development or {};
  hunkCfg = developmentCfg.hunk or {};

  enabled = cliCfg.enable && developmentCfg.enable && hunkCfg.enable;
in {
  imports = [
    inputs.hunk.homeManagerModules.hunk
  ];

  config = modules.mkIf enabled {
    programs.hunk = {
      enable = true;
      package = inputs'.hunk.packages.default;
      enableGitIntegration = hunkCfg.gitIntegration.enable;
    };
  };
}
