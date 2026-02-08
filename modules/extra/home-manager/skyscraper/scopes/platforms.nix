# Platform-specific settings submodule.
#
# Platforms can override most settings from [main], with these differences:
# - Paths are used exactly as specified (no /<PLATFORM> auto-append)
# - Some main-only options not available (frontend, platform, hints, etc.)
# - Has platform-only option: gameBaseFile
{
  lib,
  skyscraperTypes,
}: let
  # Import settings submodules
  pathsModule = import ../settings/paths.nix {inherit lib;};
  localizationModule = import ../settings/localization.nix {inherit lib skyscraperTypes;};
  titlesModule = import ../settings/titles.nix {inherit lib skyscraperTypes;};
  mediaModule = import ../settings/media.nix {inherit lib;};
  cacheModule = import ../settings/cache.nix {inherit lib;};
  matchingModule = import ../settings/matching.nix {inherit lib;};
  filterModule = import ../settings/filter.nix {inherit lib;};
  extensionsModule = import ../settings/extensions.nix {inherit lib;};
  runtimeModule = import ../settings/runtime.nix {inherit lib skyscraperTypes;};

  # Platform-specific output options (subset of main output)
  platformOutputModule = {lib, ...}: {
    options = {
      artworkXml = lib.mkOption {
        type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
        default = null;
        description = "Artwork XML configuration file for this platform.";
      };

      emulator = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Emulator name for attractmode frontend.";
      };

      launchCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Launch command for pegasus frontend.";
      };

      gameList = lib.mkOption {
        type = lib.types.submodule {
          options = {
            relativePaths = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Use relative paths in game list.";
            };

            includeSkipped = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Include ROMs with no cached data.";
            };
          };
        };
        default = {};
        description = "Game list settings for this platform.";
      };
    };
  };
in
  lib.types.submodule {
    options = {
      paths = lib.mkOption {
        type = lib.types.submodule pathsModule;
        default = {};
        description = ''
          Path settings for this platform.
          Paths are used exactly as specified (no `/<PLATFORM>` suffix).
        '';
      };

      localization = lib.mkOption {
        type = lib.types.submodule localizationModule;
        default = {};
        description = "Region and language preferences for this platform.";
      };

      output = lib.mkOption {
        type = lib.types.submodule platformOutputModule;
        default = {};
        description = "Output settings for this platform.";
      };

      titles = lib.mkOption {
        type = lib.types.submodule titlesModule;
        default = {};
        description = "Title formatting for this platform.";
      };

      media = lib.mkOption {
        type = lib.types.submodule mediaModule;
        default = {};
        description = "Media settings for this platform.";
      };

      cache = lib.mkOption {
        type = lib.types.submodule cacheModule;
        default = {};
        description = "Cache settings for this platform.";
      };

      matching = lib.mkOption {
        type = lib.types.submodule matchingModule;
        default = {};
        description = "Matching settings for this platform.";
      };

      filter = lib.mkOption {
        type = lib.types.submodule filterModule;
        default = {};
        description = "Filter settings for this platform.";
      };

      extensions = lib.mkOption {
        type = lib.types.submodule extensionsModule;
        default = {};
        description = "File extensions for this platform.";
      };

      runtime = lib.mkOption {
        type = lib.types.submodule runtimeModule;
        default = {};
        description = "Runtime settings for this platform.";
      };

      # Platform-only options
      gameBaseFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Absolute path to a GameBase SQLite3 database file for use with
          the `gamebase` scraping module.

          The database must first be converted from MS Access format using
          the `mdb2sqlite.sh` script from Skyscraper's supplementary folder.
        '';
      };
    };
  }
