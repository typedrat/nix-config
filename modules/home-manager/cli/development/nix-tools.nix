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
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.development.enable or false)) {
    home.packages = with pkgs; [
      # Nix formatters and linters
      alejandra
      nixfmt

      # Nix LSP and development tools
      nixd
    ];
  };
}
