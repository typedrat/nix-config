{
  lib,
  pkgs,
  settingsFormat,
  settingsTypes,
  skyscraperTypes,
}: let
  # Create an attrsOf type that validates attribute names against an enum
  attrsOfValidated = keyType: valueType:
    lib.types.addCheck (lib.types.attrsOf valueType) (
      attrs: lib.all (name: keyType.check name) (lib.attrNames attrs)
    )
    // {
      description = "attribute set with ${keyType.description} keys and ${valueType.description} values";
    };
in {
  enable = lib.mkEnableOption "Skyscraper, a powerful game scraper for emulation frontends";

  package = lib.mkPackageOption pkgs "skyscraper" {};

  enableXdg = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to enable XDG Base Directory support.

      When enabled, the package is built with XDG support and configuration
      is written to {file}`$XDG_CONFIG_HOME/skyscraper/config.ini`.

      When disabled, configuration is written to
      {file}`$HOME/.skyscraper/config.ini`.

      See <https://gemba.github.io/skyscraper/XDG/> for details.
    '';
  };

  configPath = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    example = "./skyscraper/config.ini";
    description = ''
      Path to a custom config.ini file to use.

      When set, this path is linked directly as the configuration file,
      and all other configuration options are ignored.
    '';
  };

  settings = lib.mkOption {
    type = settingsTypes.main;
    default = {};
    description = ''
      Global settings for Skyscraper's {file}`config.ini` `[main]` section.

      See <https://gemba.github.io/skyscraper/CONFIGINI/> for available options.
    '';
  };

  platforms = lib.mkOption {
    type = attrsOfValidated skyscraperTypes.platform settingsTypes.platform;
    default = {};
    example = lib.literalExpression ''
      {
        snes = {
          minMatch = 80;
          inputFolder = "/home/user/roms/snes";
        };
        megadrive = {
          region = "eu";
        };
      }
    '';
    description = ''
      Platform-specific settings that override the global settings.

      Each attribute name must be a valid platform identifier.
      See <https://gemba.github.io/skyscraper/PLATFORMS/> for the full list.
    '';
  };

  frontends = lib.mkOption {
    type = attrsOfValidated skyscraperTypes.frontend settingsTypes.frontend;
    default = {};
    example = lib.literalExpression ''
      {
        pegasus = {
          relativePaths = true;
          launch = "retroarch -L cores/{core}_libretro.so {file.path}";
        };
      }
    '';
    description = ''
      Frontend-specific settings that override platform and global settings.

      Valid frontends: `attractmode`, `batocera`, `emulationstation`,
      `esde`, `pegasus`, `retrobat`.
    '';
  };

  scrapers = lib.mkOption {
    type = attrsOfValidated skyscraperTypes.scraper settingsTypes.scraper;
    default = {};
    example = lib.literalExpression ''
      {
        screenscraper = {
          userCreds = "username:password";
          threads = 2;
          maxLength = 500;
        };
      }
    '';
    description = ''
      Scraper-specific settings that override all other settings.

      Valid scrapers: `arcadedb`, `igdb`, `mobygames`, `openretro`,
      `screenscraper`, `thegamesdb`, `zxinfo`, `esgamelist`, `gamebase`, `import`.
    '';
  };

  extraSettings = lib.mkOption {
    inherit (settingsFormat) type;
    default = {};
    example = lib.literalExpression ''
      {
        main = {
          spaceCheck = false;
          maxFails = 100;
        };
      }
    '';
    description = ''
      Additional freeform settings for Skyscraper's {file}`config.ini`.

      These settings are merged with the structured options, with extraSettings
      taking precedence. Use this for options not covered by the structured settings.

      See <https://gemba.github.io/skyscraper/CONFIGINI/> for available options.
    '';
  };
}
