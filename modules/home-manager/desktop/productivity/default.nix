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
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    ./3d-printing.nix
    ./blender.nix
    ./freecad.nix
    ./gimp.nix
    ./imgbrd-grabber.nix
    ./inkscape.nix
    ./kicad.nix
    ./krita.nix
    ./libreoffice.nix
    ./obsidian.nix
    ./openscad.nix
    ./sioyek.nix
    ./thunderbird.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (productivityCfg.enable or false)) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".zotero"];
    };

    home.packages = with pkgs; [
      zotero
    ];
  };
}
