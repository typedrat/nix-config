{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # xmage ships its window icon only inside the client jar, so the desktop
  # entry's themed icon name has nothing to resolve to without this.
  xmageIcon = pkgs.runCommand "xmage-icon" {nativeBuildInputs = [pkgs.unzip];} ''
    mkdir -p $out/share/icons/hicolor/48x48/apps
    unzip -p ${pkgs.xmage}/xmage/mage-client/lib/mage-client-*.jar icon-mage.png \
      > $out/share/icons/hicolor/48x48/apps/xmage.png
  '';
in {
  config = mkIf osConfig.rat.gaming.enable {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".local/share/xmage"];
    };
    home.packages = [
      pkgs.xmage
      xmageIcon
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
