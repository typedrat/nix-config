{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf osConfig.rat.games.enable {
    home.packages = [
      pkgs.xmage
    ];

    xdg.dataFile."xmage/.keep".text = "";

    xdg.desktopEntries.xmage = {
      name = "XMage";
      genericName = "Magic: The Gathering Client";
      comment = "Play Magic: The Gathering online";
      exec = "xmage";
      settings = {
        Path = "${config.home.homeDirectory}/.local/share/xmage";
      };
      icon = "xmage";
      categories = ["Game" "CardGame"];
      terminal = false;
      type = "Application";
      startupNotify = true;
    };
  };
}
