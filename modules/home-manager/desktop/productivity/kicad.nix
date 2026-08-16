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
  productivityCfg = guiCfg.productivity or {};
  cliCfg = userCfg.cli or {};
  aiCfg = cliCfg.ai or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  hasUserSecrets = builtins.pathExists (config.rat.userSecretsDir + "/digikey.yaml");
in {
  config = modules.mkIf (guiCfg.enable && productivityCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories =
        [".config/kicad" ".local/share/kicad"]
        ++ lib.optional (aiCfg.enable or false) ".local/share/kicad-mcp";
    };

    rat.userSecrets = lib.mkIf hasUserSecrets {
      digikey = {
        clientId = {};
        clientSecret = {};
      };
    };

    programs.zsh.initContent = lib.mkIf hasUserSecrets (lib.mkBefore ''
      export DIGIKEY_CLIENT_ID=$(cat ${config.sops.secrets."digikey/clientId".path})
      export DIGIKEY_CLIENT_SECRET=$(cat ${config.sops.secrets."digikey/clientSecret".path})
    '');

    home.packages =
      [
        (pkgs.kicad.override {
          addons = with pkgs.kicadAddons; [
            # TODO: re-enable once upstream adds KiCAD 10 compatibility
            # kikit
            # kikit-library
          ];
        })
      ]
      ++ lib.optional (aiCfg.enable or false) pkgs.kicad-mcp-server;
  };
}
