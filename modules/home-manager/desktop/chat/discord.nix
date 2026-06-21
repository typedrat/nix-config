{
  osConfig,
  inputs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    inputs.nixcord.homeModules.nixcord
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    programs.nixcord = {
      enable = true;

      # Vesktop is the preferred client; disable the bundled Discord package.
      discord = {
        enable = true;
        vencord.enable = true;
        # krisp.enable = true;
      };

      # Theming: Catppuccin Frappé (lavender accent) loaded via Vencord's
      # native theme support. Font overrides live in quickCss since they're
      # not first-class config.
      config = {
        useQuickCss = true;
        plugins = {
          sendTimestamps.enable = true;
          readAllNotificationsButton.enable = true;
        };
      };
      quickCss = ''
        :root {
            --font-primary: sans-serif;
            --font-display: sans-serif;
            --font-headline: sans-serif;
            --font-code: monospace;
        }
      '';
    };

    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/discord" ".config/Vesktop" ".config/Vencord"];
    };
  };
}
