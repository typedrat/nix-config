{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf osConfig.rat.virtualisation.docker.enable {
    home.packages = with pkgs; [
      fuse-overlayfs
      passt
      dive
      lazydocker
    ];
  };
}
