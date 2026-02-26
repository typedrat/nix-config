{
  osConfig,
  inputs,
  lib,
  ...
}: let
  inherit (lib) attrsets modules;

  catppuccinCfg = builtins.fromJSON (builtins.readFile "${inputs.catppuccin-element}/config.json");
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.enable {
      directories = [".config/Element"];
    };
    programs.element-desktop = {
      enable = true;

      settings = attrsets.mergeAttrsList [
        {
          default_server_config."m.homeserver" = {
            base_url = "https://matrix.thisratis.gay";
            server_name = "thisratis.gay";
          };
        }

        catppuccinCfg
      ];
    };
  };
}
