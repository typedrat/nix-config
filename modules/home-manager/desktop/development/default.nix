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
  guiCfg = userCfg.gui or {};
  developmentCfg = guiCfg.development or {};
in {
  imports = [
    ./imhex.nix
    ./vscode.nix
    ./zed.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (developmentCfg.enable or false)) {
    home.packages = with pkgs; [
      virt-manager
    ];
  };
}
