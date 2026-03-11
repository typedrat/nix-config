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
  themingCfg = userCfg.theming or {};

  palette =
    (builtins.fromJSON
      (builtins.readFile "${config.catppuccin.sources.palette}/palette.json"))
    .${
      config.catppuccin.flavor
    }
    .colors;

  accentColor = config.catppuccin.accent;

  rgb = c: "${toString c.rgb.r},${toString c.rgb.g},${toString c.rgb.b}";
  accent = rgb palette.${accentColor};

  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);

  flavorName = capitalizeFirst config.catppuccin.flavor;
  accentName = capitalizeFirst accentColor;

  commonForeground = {
    ForegroundActive = rgb palette.peach;
    ForegroundInactive = rgb palette.subtext0;
    ForegroundLink = accent;
    ForegroundNegative = rgb palette.red;
    ForegroundNeutral = rgb palette.yellow;
    ForegroundNormal = rgb palette.text;
    ForegroundPositive = rgb palette.green;
    ForegroundVisited = rgb palette.mauve;
  };
in {
  config = modules.mkIf (themingCfg.enable && guiCfg.enable) {
    rat.kdeglobals = {
      "ColorEffects:Disabled" = {
        Color = rgb palette.base;
        ColorAmount = "0.3";
        ColorEffect = 2;
        ContrastAmount = "0.1";
        ContrastEffect = 0;
        IntensityAmount = -1;
        IntensityEffect = 0;
      };

      "ColorEffects:Inactive" = {
        ChangeSelectionColor = true;
        Color = rgb palette.base;
        ColorAmount = "0.5";
        ColorEffect = 3;
        ContrastAmount = 0;
        ContrastEffect = 0;
        Enable = true;
        IntensityAmount = 0;
        IntensityEffect = 0;
      };

      "Colors:Button" =
        {
          BackgroundAlternate = accent;
          BackgroundNormal = rgb palette.surface0;
          DecorationFocus = accent;
          DecorationHover = rgb palette.surface0;
        }
        // commonForeground;

      "Colors:Complementary" =
        {
          BackgroundAlternate = rgb palette.crust;
          BackgroundNormal = rgb palette.mantle;
          DecorationFocus = accent;
          DecorationHover = rgb palette.surface0;
        }
        // commonForeground;

      "Colors:Header" =
        {
          BackgroundAlternate = rgb palette.crust;
          BackgroundNormal = rgb palette.mantle;
          DecorationFocus = accent;
          DecorationHover = rgb palette.surface0;
        }
        // commonForeground;

      "Colors:Selection" =
        {
          BackgroundAlternate = accent;
          BackgroundNormal = accent;
          DecorationFocus = accent;
          DecorationHover = rgb palette.surface0;
        }
        // commonForeground
        // {
          ForegroundInactive = rgb palette.mantle;
          ForegroundNormal = rgb palette.crust;
        };

      "Colors:Tooltip" =
        {
          BackgroundAlternate = rgb palette.crust;
          BackgroundNormal = rgb palette.base;
          DecorationFocus = accent;
          DecorationHover = rgb palette.surface0;
        }
        // commonForeground;

      "Colors:View" =
        {
          BackgroundAlternate = rgb palette.mantle;
          BackgroundNormal = rgb palette.base;
          DecorationFocus = accent;
          DecorationHover = rgb palette.surface0;
        }
        // commonForeground;

      "Colors:Window" =
        {
          BackgroundAlternate = rgb palette.crust;
          BackgroundNormal = rgb palette.mantle;
          DecorationFocus = accent;
          DecorationHover = rgb palette.surface0;
        }
        // commonForeground;

      General = {
        ColorScheme = "Catppuccin${flavorName}${accentName}";
        Name = "Catppuccin ${flavorName} ${accentName}";
        accentActiveTitlebar = false;
        shadeSortColumn = true;
      };

      KDE = {
        contrast = 4;
      };

      WM = {
        activeBackground = rgb palette.base;
        activeBlend = rgb palette.text;
        activeForeground = rgb palette.text;
        inactiveBackground = rgb palette.crust;
        inactiveBlend = rgb palette.subtext0;
        inactiveForeground = rgb palette.subtext0;
      };
    };
  };
}
