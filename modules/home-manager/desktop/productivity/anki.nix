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
  ankiCfg = productivityCfg.anki or {};
  syncEnabled = ankiCfg.sync.enable or false;

  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && productivityCfg.enable && ankiCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".local/share/Anki2"];
    };

    programs.anki = {
      enable = true;

      # The catppuccin module supplies the ReColor add-on and its palette, but
      # ReColor still keys off Anki's own light/dark mode to pick a column out
      # of that palette.
      theme =
        if config.catppuccin.flavor == "latte"
        then "light"
        else "dark";

      addons = with pkgs.ankiAddons; [
        fsrs4anki-helper
      ];

      # The credential files are read at profile open, so the secrets never
      # reach the store.
      profiles."User 1".sync = modules.mkIf syncEnabled {
        usernameFile = config.sops.secrets."anki/username".path;
        keyFile = config.sops.secrets."anki/syncKey".path;
        autoSync = true;
        syncMedia = true;
      };
    };

    rat.userSecrets = modules.mkIf syncEnabled {
      anki = {
        username = {};
        syncKey = {};
      };
    };
  };
}
