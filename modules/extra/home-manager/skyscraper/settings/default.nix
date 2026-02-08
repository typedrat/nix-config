# Main settings submodule for Skyscraper.
#
# Combines all settings groups into a single submodule type.
{
  lib,
  skyscraperTypes,
}: let
  # Import all settings submodules with the required arguments
  pathsModule = import ./paths.nix {inherit lib;};
  localizationModule = import ./localization.nix {inherit lib skyscraperTypes;};
  outputModule = import ./output.nix {inherit lib skyscraperTypes;};
  titlesModule = import ./titles.nix {inherit lib skyscraperTypes;};
  mediaModule = import ./media.nix {inherit lib;};
  cacheModule = import ./cache.nix {inherit lib;};
  matchingModule = import ./matching.nix {inherit lib;};
  filterModule = import ./filter.nix {inherit lib;};
  extensionsModule = import ./extensions.nix {inherit lib;};
  runtimeModule = import ./runtime.nix {inherit lib skyscraperTypes;};
in
  lib.types.submodule {
    options = {
      paths = lib.mkOption {
        type = lib.types.submodule pathsModule;
        default = {};
        description = ''
          Path settings for ROM input, game list output, media, and cache.

          In the main settings, `/<PLATFORM>` is automatically appended to paths.
          In platform-specific settings, paths are used exactly as specified.
        '';
      };

      localization = lib.mkOption {
        type = lib.types.submodule localizationModule;
        default = {};
        description = "Region and language preferences for scraped data.";
      };

      output = lib.mkOption {
        type = lib.types.submodule outputModule;
        default = {};
        description = "Frontend selection and game list output settings.";
      };

      titles = lib.mkOption {
        type = lib.types.submodule titlesModule;
        default = {};
        description = "Game title formatting options.";
      };

      media = lib.mkOption {
        type = lib.types.submodule mediaModule;
        default = {};
        description = "Media scraping settings (videos, manuals, artwork).";
      };

      cache = lib.mkOption {
        type = lib.types.submodule cacheModule;
        default = {};
        description = "Resource caching behavior and quality settings.";
      };

      matching = lib.mkOption {
        type = lib.types.submodule matchingModule;
        default = {};
        description = "Search matching and result processing settings.";
      };

      filter = lib.mkOption {
        type = lib.types.submodule filterModule;
        default = {};
        description = "File filtering and range selection settings.";
      };

      extensions = lib.mkOption {
        type = lib.types.submodule extensionsModule;
        default = {};
        description = "ROM file extension settings.";
      };

      runtime = lib.mkOption {
        type = lib.types.submodule runtimeModule;
        default = {};
        description = "Runtime behavior settings (verbosity, threads, etc.).";
      };

      # Main-only options that don't fit into a category
      scummIni = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        defaultText = lib.literalMD "`~/.scummvmrc`";
        description = ''
          Path to a ScummVM configuration file used to resolve game short
          names (e.g., `monkey2`) to full titles when scraping the `scummvm`
          platform.
        '';
      };
    };
  }
