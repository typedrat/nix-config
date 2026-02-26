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
  gamesCfg = guiCfg.games or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    ./retroarch.nix
    ./sgdboop.nix
    ./xmage.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (gamesCfg.enable or false)) {
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
        ".local/share/wine"
        "Games"
      ];
    };
  };
}
