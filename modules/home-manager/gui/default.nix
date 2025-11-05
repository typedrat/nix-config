{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
in {
  imports = [
    ./chat
    ./devtools
    ./easyeffects
    ./firefox
    ./games
    ./ghostty
    ./graphics.nix
    ./hyprland
    ./media
    ./productivity
    ./security.nix
    ./utilities.nix
    ./browsers.nix
    ./wezterm
  ];

  config = modules.mkIf (guiCfg.enable or false) {
    # Base GUI configuration
  };
}
