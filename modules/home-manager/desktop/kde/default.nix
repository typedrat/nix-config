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
  kdeCfg = guiCfg.kde or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);

  flavorName = capitalizeFirst config.catppuccin.flavor;
  accentName = capitalizeFirst config.catppuccin.accent;
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && kdeCfg.enable
      && osConfig.rat.gui.kde.enable
    ) {
      programs.plasma = {
        enable = true;
        overrideConfig = false;

        workspace = {
          theme = "default";
          lookAndFeel = "Catppuccin-${flavorName}-${accentName}";
          windowDecorations = {
            library = "org.kde.kwin.aurorae";
            theme = "__aurorae__svg__Catppuccin${flavorName}-Modern";
          };
          splashScreen.theme = "Catppuccin-${flavorName}-${accentName}";
        };

        fonts = {
          general = {
            family = "SF Pro Display";
            pointSize = 13;
          };
          fixedWidth = {
            family = "SF Mono";
            pointSize = 12;
          };
        };

        kwin = {
          effects = {
            translucency.enable = true;
            blur.enable = true;
          };
        };

        configFile = {
          kdeglobals = {
            KDE.AnimationDurationFactor = 0.5;
          };
        };
      };

      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [
          ".local/share/baloo"
          ".local/share/kactivitymanagerd"
          ".local/share/kwalletd"
          ".local/share/kscreen"
          ".config/kde.org"
          ".config/kdedefaults"
        ];
        files = [
          ".config/kwinrc"
          ".config/plasma-org.kde.plasma.desktop-appletsrc"
          ".config/plasmashellrc"
          ".config/kconf_updaterc"
        ];
      };
    };
}
