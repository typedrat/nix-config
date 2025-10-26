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
in {
  imports = [
    ./3d-printing.nix
    ./freecad.nix
    ./kicad.nix
    ./libreoffice.nix
    ./obsidian.nix
    ./sioyek.nix
    ./thunderbird.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (productivityCfg.enable or false)) {
    home.packages = with pkgs; [
      cherry-studio
    ];
  };
}
