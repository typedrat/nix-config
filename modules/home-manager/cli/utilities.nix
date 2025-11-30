{
  config,
  osConfig,
  inputs',
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
      # Archiving tools
      unzip
      xz
      zip

      # Crypto and secrets
      age
      sops
      ssh-to-age

      # File processing
      ffmpeg-full
      imagemagickBig
      tokei

      # CLI utilities
      cachix
      gdu
      jd-diff-patch
      jq
      llm
      openssl
      pv
      waypipe
      wl-clipboard

      # Nix utilities
      nixpkgs-review
      nix-diff
      nix-tree
      nix-prefetch-github

      # Binary cache
      inputs'.attic.packages.attic-client
    ];
  };
}
