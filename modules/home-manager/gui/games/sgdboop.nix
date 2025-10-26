{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
in {
  config = modules.mkIf (osConfig.rat.games.enable && osConfig.rat.games.steam.enable) {
    programs.mangohud.enable = true;

    home.packages = with pkgs; [
      sgdboop
    ];
  };
}
