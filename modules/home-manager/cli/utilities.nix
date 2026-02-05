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
      p7zip
      unrar

      # Crypto and secrets
      age
      sops
      ssh-to-age

      # File processing
      ffmpeg-full
      imagemagickBig
      tokei

      # CLI utilities
      aria2
      cachix
      chafa
      yt-dlp
      gdu
      jd-diff-patch
      jq
      openssl
      pv
      rename
      vim.xxd
      waypipe
      wl-clipboard

      # Nix utilities
      fh
      nixpkgs-review
      nix-diff
      nix-tree
      nix-prefetch-github

      # Binary cache
      inputs'.attic.packages.attic-client
    ];
  };
}
