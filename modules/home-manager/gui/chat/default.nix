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
  chatCfg = guiCfg.chat or {};
in {
  imports = [
    ./discord
    ./element.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (chatCfg.enable or false)) {
    home.packages = with pkgs; [
      telegram-desktop
      slack
    ];
  };
}
