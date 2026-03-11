{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.tools.enable or false)) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/mergiraf"
      ];
    };

    programs.difftastic = {
      enable = true;
      git.enable = true;
    };

    programs.lazygit.enable = true;

    programs.mergiraf.enable = true;
  };
}
