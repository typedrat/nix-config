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
  hyprlandCfg = guiCfg.hyprland or {};
  kdeCfg = hyprlandCfg.kde or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && hyprlandCfg.enable && kdeCfg.enable) {
    # KDE cruft to get Dolphin et al working
    home.packages = with pkgs; [
      kdePackages.plasma-workspace
      kdePackages.kio
      kdePackages.kdf
      kdePackages.kio-fuse
      kdePackages.kio-extras
      kdePackages.kio-admin
      kdePackages.qtwayland
      kdePackages.plasma-integration
      kdePackages.kdegraphics-thumbnailers
      kdePackages.breeze-icons
      kdePackages.qtsvg
      kdePackages.kservice
      shared-mime-info

      kdePackages.akonadi
      kdePackages.akonadi-search
      kdePackages.akonadi-mime
      kdePackages.akonadi-calendar
      kdePackages.akonadi-import-wizard
      kdePackages.merkuro
    ];

    xdg.configFile."menus/applications.menu".text = builtins.readFile ./applications.menu;

    home.persistence.${persistDir} = modules.mkIf (impermanenceCfg.home.enable && !osConfig.rat.gui.kde.enable) {
      directories = [
        # Akonadi PIM (Merkuro calendar/contacts data)
        ".local/share/akonadi"
        ".config/akonadi"
      ];
    };
  };
}
