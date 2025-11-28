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
      wineWowPackages.stable
    ];
  };
}
