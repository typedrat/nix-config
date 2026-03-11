{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  gitCfg = userCfg.git or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkMerge [
    # Base git configuration (if user has configured name/email)
    (mkIf (gitCfg.name != null && gitCfg.email != null) {
      programs.git = {
        enable = true;
        lfs.enable = true;

        signing = mkIf (gitCfg.signing.key != null) {
          inherit (gitCfg.signing) key format;
          inherit (gitCfg.signing) signByDefault;
        };

        settings = {
          user = {
            inherit (gitCfg) name;
            inherit (gitCfg) email;
          };

          init = {
            defaultBranch = "master";
          };

          push = {
            autoSetupRemote = true;
          };
        };
      };
    })

    # Git CLI tools
    (mkIf (cliCfg.enable && cliCfg.tools.enable) {
      home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
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
    })
  ];
}
