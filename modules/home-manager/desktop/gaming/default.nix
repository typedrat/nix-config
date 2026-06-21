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
  gamingCfg = guiCfg.gaming or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    ./anime-game-launchers.nix
    ./eden.nix
    ./retroarch.nix
    ./sgdboop.nix
    ./skyscraper.nix
    ./sunshine.nix
    ./xmage.nix
  ];

  config = modules.mkIf (guiCfg.enable && gamingCfg.enable) {
    home.packages = with pkgs; [
      bottles
      gamescope
      igir
      pegasus-frontend
      umu-launcher
      winePackages.stagingFull
    ];

    xdg.userDirs.extraConfig.XDG_GAMES_DIR = "$HOME/Games";

    xdg.configFile."pegasus-frontend/themes/colorful".source = "${pkgs.pegasus-theme-colorful}/share/pegasus-frontend/themes/colorful";

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/Steam"
        ".steam"
        ".local/share/bottles"
        ".config/pegasus-frontend"
        ".config/rom-organizer"
        ".local/share/wine"
        # Native GOG/GameMaker game saves (e.g. Mina the Hollower)
        ".local/share/Yacht Club Games"
        "Games"
      ];
    };
  };
}
