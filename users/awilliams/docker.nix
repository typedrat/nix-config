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
      dive
      docker-buildx
      docker-compose
      fuse-overlayfs
      lazydocker
      passt
    ];
  };
}
