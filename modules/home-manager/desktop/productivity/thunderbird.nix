{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".thunderbird"];
    };
    programs.thunderbird = {
      enable = true;

      profiles.default = {
        isDefault = true;

        accountsOrder = [
          "Personal"
          "Backup"
          "Work"
        ];

        settings = {
          "extensions.autoDisableScopes" = 0; # Don't auto-disable extensions
        };
      };
    };
    catppuccin.thunderbird.profile = "default";
  };
}
