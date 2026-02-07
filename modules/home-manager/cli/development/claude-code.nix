{
  config,
  osConfig,
  self',
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules getExe;
  inherit (config.home) username homeDirectory;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.development.enable or false)) {
    home.packages = [
      pkgs.claude-code-bin
      self'.packages.cclogviewer
    ];

    # Add ~/.local/bin to PATH
    home.sessionPath = [
      "${homeDirectory}/.local/bin"
    ];

    # Symlink claude-code to ~/.local/bin for easy access
    home.file.".local/bin/claude".source = getExe pkgs.claude-code-bin;
  };
}
