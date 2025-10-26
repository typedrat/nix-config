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
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.tools.enable or false)) {
    home.packages = with pkgs; [
      # Miscellaneous utilities
      cowsay
      file
      gawk
      gnused
      gnutar
      tree
      which
      zstd

      # Custom packages
      self'.packages.catbox-cli
      self'.packages.qbittorrent-cli
      self'.packages.stable-diffusion-cpp
      self'.packages.pyvizio

      # Fetch tools
      (fastfetch.overrideAttrs (oldAttrs: {
        buildInputs =
          (oldAttrs.buildInputs or [])
          ++ [
            zfs
          ];
      }))
      hyfetch
    ];
  };
}
