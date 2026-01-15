{
  config,
  osConfig,
  self',
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  gamesCfg = guiCfg.games or {};
in {
  imports = [
    ./retroarch.nix
    ./sgdboop.nix
    ./xmage.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (gamesCfg.enable or false)) {
    home.packages = with pkgs; [
      gamescope
      igir
      pegasus-frontend
      umu-launcher
      wineWowPackages.stableFull
    ];

    xdg.configFile."pegasus-frontend/themes/colorful".source = "${self'.packages.pegasus-theme-colorful}/share/pegasus-frontend/themes/colorful";
  };
}
