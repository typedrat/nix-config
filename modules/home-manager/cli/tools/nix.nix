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
  };
}
