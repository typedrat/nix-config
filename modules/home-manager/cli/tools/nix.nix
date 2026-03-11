{
  config,
  osConfig,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = mkMerge [
    # Base Nix configuration
    {
      nix.gc = {
        automatic = true;
        persistent = true;
        dates = "daily";
        options = "--delete-older-than 30d";
      };

      xdg.configFile."nixpkgs/config.nix".text = ''
        { allowUnfree = true; }
      '';
    }

    # Nix CLI tools
    (mkIf (cliCfg.enable && cliCfg.tools.enable) {
      home.packages = with pkgs; [
        cachix
        fh
        nix-diff
        nix-prefetch-github
        nix-tree
        nix-update
        nixpkgs-review
        inputs'.attic.packages.attic-client
      ];

      programs.nix-index = {
        enable = true;
        enableZshIntegration = true;
      };
    })
  ];
}
