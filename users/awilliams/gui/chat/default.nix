{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  imports = [
    ./discord
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.packages = with pkgs; [
      telegram-desktop
      fluffychat
      slack
    ];
  };
}
