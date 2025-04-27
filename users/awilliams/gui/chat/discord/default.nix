{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.packages = [
      (
        pkgs.discord.override
        {
          withOpenASAR = true;
          withVencord = true;
        }
      )
    ];

    # Discord theming:
    xdg.configFile."Vesktop/settings/quickCss.css".source = ./quickCss.css;
  };
}
