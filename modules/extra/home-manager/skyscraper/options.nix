# Top-level options for the Skyscraper home-manager module.
#
# This module provides a user-friendly nested interface for configuring
# Skyscraper, which is then converted to flat INI format at build time.
{
  lib,
  pkgs,
  skyscraperTypes,
  mainSettingsType,
  platformSettingsType,
  frontendSettingsType,
  scraperSettingsType,
  settingsFormat,
}: let
  # Create an attrsOf type that validates attribute names against an enum.
  # This catches typos like `platforms.sness` at evaluation time.
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
      and all other configuration options ({option}`settings`,
      {option}`platforms`, {option}`frontends`, {option}`scrapers`,
      {option}`extraSettings`) are ignored.
    '';
  };

  settings = lib.mkOption {
    type = mainSettingsType;
    default = {};
    description = ''
      Global settings for Skyscraper's {file}`config.ini` `[main]` section.

      These are applied to all scraping runs regardless of platform,
      frontend, or module, unless overridden by a more specific section.

      See <https://gemba.github.io/skyscraper/CONFIGINI/> for details.
    '';
  };

  platforms = lib.mkOption {
    type = attrsOfValidated skyscraperTypes.platform platformSettingsType;
    default = {};
    example = lib.literalExpression ''
      {
        snes = {
          matching.minPercent = 80;
          paths.roms = "/home/user/roms/snes";
        };
        megadrive = {
          localization.region = "eu";
        };
      }
    '';
    description = ''
      Platform-specific settings that override global settings when
      scraping for that platform.

      Each attribute name must be a valid platform identifier.
      See <https://gemba.github.io/skyscraper/PLATFORMS/> for the full list.
    '';
  };

  frontends = lib.mkOption {
    type = attrsOfValidated skyscraperTypes.frontend frontendSettingsType;
    default = {};
    example = lib.literalExpression ''
      {
        pegasus = {
          output.gameList.filename = "metadata.txt";
        };
        emulationstation = {
          output.gameList.includeFolders = true;
          output.gameList.variants = [ "enable-manuals" ];
        };
      }
    '';
    description = ''
      Frontend-specific settings that override platform and global
      settings when generating game lists for that frontend.

      Available options vary by frontend — for example, `includeFolders` is
      only available for `emulationstation`, `esde`, and `retrobat`.

      Valid frontends: `attractmode`, `batocera`, `emulationstation`,
      `esde`, `pegasus`, `retrobat`.
    '';
  };

  scrapers = lib.mkOption {
    type = attrsOfValidated skyscraperTypes.scraper scraperSettingsType;
    default = {};
    example = lib.literalExpression ''
      {
        screenscraper = {
          credentials.file = config.sops.secrets.screenscraper.path;
          media.videos.preferNormalized = false;
          runtime.threads = 2;
        };
        igdb = {
          credentials.text = "clientId:clientSecret";  # For testing only!
        };
      }
    '';
    description = ''
      Scraper-specific settings with the highest precedence (after CLI
      options). These override frontend, platform, and global settings.

      For secure credential handling, use `credentials.file` with a path
      to a secrets file (compatible with sops-nix or agenix). The file
      is read at activation time, not build time.

      Available options vary by scraper — for example,
      `media.videos.preferNormalized` is only available for `screenscraper`.

      Valid scrapers: `arcadedb`, `igdb`, `mobygames`, `openretro`,
      `screenscraper`, `thegamesdb`, `zxinfo`, `esgamelist`, `gamebase`,
      `import`.
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

      These settings are merged with the structured options, with
      {option}`extraSettings` taking precedence. Use this for options
      not yet covered by the structured settings, or for unusual
      configurations.

      Section names correspond to Skyscraper's INI sections: `main`,
      platform names (e.g. `snes`), frontend names (e.g. `pegasus`),
      or scraper names (e.g. `screenscraper`).

      See <https://gemba.github.io/skyscraper/CONFIGINI/> for available
      options.
    '';
  };
}
