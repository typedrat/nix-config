{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
in {
  config = modules.mkIf (osConfig.rat.gaming.enable && osConfig.rat.gaming.steam.enable) {
    programs.mangohud.enable = true;

    home.packages = with pkgs; [
      sgdboop
    ];
  };
}
