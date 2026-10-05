{
  osConfig,
  inputs,
  lib,
  pkgs,
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
        equicord.enable = true;
        krisp.enable = true;
      };

      config = {
        useQuickCss = true;
        enabledThemeLinks = [
          "https://catppuccin.github.io/discord/dist/catppuccin-frappe-lavender.theme.css"
        ];
        plugins = {
          sendTimestamps.enable = true;
          readAllNotificationsButton.enable = true;
        };
      };
      extraConfig.plugins.GithubPrivateEmbeds = {
        enable = true;
        ghPath = lib.getExe pkgs.gh;
      };
      userPlugins.githubPrivateEmbeds = ../../../../users/awilliams/discord-plugins/githubPrivateEmbeds;

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
      directories = [".config/discord" ".config/Vesktop" ".config/Vencord" ".config/Equicord"];
    };
  };
}
