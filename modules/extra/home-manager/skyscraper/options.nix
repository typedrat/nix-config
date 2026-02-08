{
  lib,
  pkgs,
  skyscraperTypes,
  settingsFormat,
}: {
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

  settings = {
    # General options
    frontend = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.frontend;
      default = null;
      description = ''
        The frontend to generate game lists for.
      '';
    };

    verbosity = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 3);
      default = null;
      description = ''
        Sets how verbose Skyscraper should be when running.
        Higher values produce more output (0-3).
      '';
    };

    hints = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether to display "Did you know" hints when running.
      '';
    };

    pretend = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Disable game list generation and only output potential results
        to the terminal. Useful for previewing changes.
      '';
    };

    interactive = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Enable interactive mode to manually select the best match
        from returned entries.
      '';
    };

    unattend = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Skip confirmation prompts and run non-interactively.
        Useful for scripting.
      '';
    };

    threads = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        Number of parallel scraping threads.
      '';
    };

    # Path options
    inputFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/user/roms";
      description = ''
        Path to the ROM input directory.
      '';
    };

    gameListFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/user/roms";
      description = ''
        Path where game list files are exported.
      '';
    };

    mediaFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/user/roms/media";
      description = ''
        Path where media files (artwork, videos) are stored.
      '';
    };

    cacheFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the resource cache directory.
      '';
    };

    # Localization options
    region = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.region;
      default = null;
      example = "eu";
      description = ''
        Primary region preference for game data.

        See <https://gemba.github.io/skyscraper/REGIONS/> for details.
      '';
    };

    lang = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.lang;
      default = null;
      example = "en";
      description = ''
        Primary language preference for game data.

        See <https://gemba.github.io/skyscraper/LANGUAGES/> for details.
      '';
    };

    # Game list options
    gameListBackup = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Create a timestamped backup of the existing game list before
        generating a new one.
      '';
    };

    relativePaths = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Use relative paths for ROM and media files in the game list.
      '';
    };

    skipped = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Include ROMs with no cached data as generic entries in the game list.
      '';
    };

    # Title formatting options
    brackets = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Keep bracket notes (e.g., region tags like `(Europe)` or `[AGA]`)
        in game titles.
      '';
    };

    theInFront = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Move "The" to the front of game titles instead of the end.
      '';
    };

    # Media options
    videos = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether to scrape and cache video files.
      '';
    };

    manuals = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether to scrape and cache game manuals (PDF).
      '';
    };

    backcovers = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether to scrape and cache game back cover artwork.
      '';
    };

    fanarts = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether to scrape and cache fan art.
      '';
    };

    symlink = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Create symlinks to cached videos instead of copying them.
        Saves space but links break if cache is cleared.
      '';
    };

    # Processing options
    minMatch = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 100);
      default = null;
      description = ''
        Minimum match percentage for search results to be accepted.
      '';
    };

    maxLength = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        Maximum length of game descriptions.
      '';
    };

    tidyDesc = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Clean up formatting in scraped descriptions (fix spacing,
        bullet points, multiple exclamation marks, etc.).
      '';
    };

    cropBlack = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Crop black borders from screenshot resources.
      '';
    };

    subdirs = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Include ROMs in subdirectories of the input folder.
      '';
    };

    # Cache options
    cache = {
      covers = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to cache cover artwork.
        '';
      };

      screenshots = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to cache screenshot images.
        '';
      };

      wheels = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to cache wheel graphics.
        '';
      };

      marquees = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to cache marquee artwork.
        '';
      };

      textures = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to cache texture resources.
        '';
      };

      resize = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Resize large artwork before caching to save space.
        '';
      };

      refresh = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Force refetch of all data from servers, ignoring cached data.
        '';
      };
    };
  };

  extraSettings = lib.mkOption {
    inherit (settingsFormat) type;
    default = {};
    example = lib.literalExpression ''
      {
        main = {
          jpgQuality = 90;
          videoSizeLimit = 50;
        };
        snes = {
          inputFolder = "/home/user/roms/snes";
        };
        screenscraper = {
          userCreds = "username:password";
        };
      }
    '';
    description = ''
      Additional configuration settings for Skyscraper's {file}`config.ini`.

      These settings are merged with the structured options, with extraSettings
      taking precedence.

      Settings are organized into sections:
      - {var}`main`: Global default settings
      - {var}`<platform>`: Platform-specific settings (e.g., `snes`, `megadrive`)
      - {var}`<frontend>`: Frontend-specific settings (e.g., `emulationstation`, `pegasus`)
      - {var}`<scraper>`: Scraper module settings (e.g., `screenscraper`, `thegamesdb`)

      See <https://gemba.github.io/skyscraper/CONFIGINI/> for available options.
    '';
  };
}
