{
  osConfig,
  inputs,
  lib,
  ...
}: let
  inherit (lib) attrsets modules;

  catppuccinCfg = builtins.fromJSON (builtins.readFile "${inputs.catppuccin-element}/config.json");
in {
  config = modules.mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
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
