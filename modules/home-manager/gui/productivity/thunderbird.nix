{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
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
