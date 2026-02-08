# Submodule types for Skyscraper configuration sections
# Based on https://gemba.github.io/skyscraper/CONFIGINI/
{lib}: let
  skyscraperTypes = import ./types.nix {inherit lib;};

  # Common option definitions that can be reused across sections
  options = {
    # Path options
    inputFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/user/roms";
      description = "Path to the ROM input directory.";
    };

    gameListFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/user/roms";
      description = "Path where game list files are exported.";
    };

    mediaFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/home/user/roms/media";
      description = "Path where media files (artwork, videos) are stored.";
    };

    cacheFolder = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the resource cache directory.";
    };

    # Localization
    region = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.region;
      default = null;
      example = "eu";
      description = ''
        Primary region preference for game data.
        See <https://gemba.github.io/skyscraper/REGIONS/>.
      '';
    };

    lang = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.lang;
      default = null;
      example = "en";
      description = ''
        Primary language preference for game data.
        See <https://gemba.github.io/skyscraper/LANGUAGES/>.
      '';
    };

    # General
    frontend = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.frontend;
      default = null;
      description = "The frontend to generate game lists for.";
    };

    verbosity = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 3);
      default = null;
      description = "Output verbosity level (0-3).";
    };

    hints = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''Whether to display "Did you know" hints.'';
    };

    pretend = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Preview output without generating files.";
    };

    interactive = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Manually select the best match from results.";
    };

    unattend = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Skip confirmation prompts.";
    };

    unattendSkip = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Skip existing entries without prompting.";
    };

    threads = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Number of parallel scraping threads.";
    };

    # Game list
    gameListBackup = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Create timestamped backup of existing game list.";
    };

    relativePaths = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Use relative paths in the game list.";
    };

    skipped = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Include ROMs with no cached data as generic entries.";
    };

    # Title formatting
    brackets = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Keep bracket notes in game titles.";
    };

    theInFront = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''Move "The" to the front of game titles.'';
    };

    forceFilename = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Use filename instead of scraped title.";
    };

    # Media
    videos = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Scrape and cache video files.";
    };

    manuals = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Scrape and cache game manuals (PDF).";
    };

    backcovers = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Scrape and cache back cover artwork.";
    };

    fanarts = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Scrape and cache fan art.";
    };

    symlink = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Create symlinks to cached videos instead of copying.";
    };

    videoSizeLimit = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Maximum video file size in MB.";
    };

    # Processing
    minMatch = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 100);
      default = null;
      description = "Minimum match percentage for search results.";
    };

    maxLength = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Maximum length of game descriptions.";
    };

    tidyDesc = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Clean up formatting in descriptions.";
    };

    cropBlack = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Crop black borders from screenshots.";
    };

    subdirs = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Include ROMs in subdirectories.";
    };

    onlyMissing = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Only scrape ROMs not already in cache.";
    };

    # Cache
    cacheCovers = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Cache cover artwork.";
    };

    cacheScreenshots = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Cache screenshot images.";
    };

    cacheWheels = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Cache wheel graphics.";
    };

    cacheMarquees = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Cache marquee artwork.";
    };

    cacheTextures = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Cache texture resources.";
    };

    cacheResize = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Resize large artwork before caching.";
    };

    cacheRefresh = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Force refetch from servers, ignoring cache.";
    };

    jpgQuality = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 100);
      default = null;
      description = "JPEG quality for cached images (0-100).";
    };

    # Frontend-specific
    artworkXml = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Custom artwork XML configuration file.";
    };

    emulator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Emulator name (for attractmode frontend).";
    };

    launch = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Launch command (for pegasus frontend).";
    };

    startAt = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Start processing at this filename.";
    };

    endAt = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Stop processing at this filename.";
    };

    # Scraper-specific
    userCreds = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "User credentials (user:pass or API key).";
    };

    videoPreferNormalized = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Prefer normalized videos from ScreenScraper.";
    };
  };

  # Select specific options for a submodule
  selectOptions = names: lib.genAttrs names (name: options.${name});
in {
  # [main] section - all options valid in main
  main = lib.types.submodule {
    options = selectOptions [
      # General (main only)
      "frontend"
      "hints"
      "backcovers"
      "fanarts"
      # General (main + others)
      "verbosity"
      "pretend"
      "interactive"
      "unattend"
      "unattendSkip"
      "threads"
      # Paths
      "inputFolder"
      "gameListFolder"
      "mediaFolder"
      "cacheFolder"
      # Localization
      "region"
      "lang"
      # Game list
      "gameListBackup"
      "relativePaths"
      "skipped"
      # Title formatting
      "brackets"
      "theInFront"
      "forceFilename"
      # Media
      "videos"
      "manuals"
      "symlink"
      "videoSizeLimit"
      # Processing
      "minMatch"
      "maxLength"
      "tidyDesc"
      "cropBlack"
      "subdirs"
      "onlyMissing"
      # Cache
      "cacheCovers"
      "cacheScreenshots"
      "cacheWheels"
      "cacheMarquees"
      "cacheTextures"
      "cacheResize"
      "cacheRefresh"
      "jpgQuality"
      # Frontend-specific
      "artworkXml"
      "emulator"
      "launch"
    ];
  };

  # [<platform>] section - platform-specific overrides
  platform = lib.types.submodule {
    options = selectOptions [
      # Paths
      "inputFolder"
      "gameListFolder"
      "mediaFolder"
      "cacheFolder"
      # Localization
      "region"
      "lang"
      # General
      "verbosity"
      "pretend"
      "interactive"
      "unattend"
      "unattendSkip"
      "threads"
      # Game list
      "relativePaths"
      "skipped"
      # Title formatting
      "brackets"
      "theInFront"
      "forceFilename"
      # Media
      "videos"
      "manuals"
      "symlink"
      "videoSizeLimit"
      # Processing
      "minMatch"
      "maxLength"
      "tidyDesc"
      "cropBlack"
      "subdirs"
      "onlyMissing"
      # Cache
      "cacheCovers"
      "cacheScreenshots"
      "cacheWheels"
      "cacheMarquees"
      "cacheTextures"
      "cacheResize"
      "jpgQuality"
      # Frontend-specific
      "artworkXml"
      "emulator"
      "launch"
      "startAt"
      "endAt"
    ];
  };

  # [<frontend>] section - frontend-specific overrides
  frontend = lib.types.submodule {
    options = selectOptions [
      # Paths
      "inputFolder"
      "gameListFolder"
      "mediaFolder"
      # General
      "verbosity"
      "unattend"
      "unattendSkip"
      # Game list
      "gameListBackup"
      "skipped"
      # Title formatting
      "brackets"
      "theInFront"
      "forceFilename"
      # Media
      "videos"
      "symlink"
      # Processing
      "maxLength"
      "cropBlack"
      # Frontend-specific
      "artworkXml"
      "emulator"
      "launch"
      "startAt"
      "endAt"
    ];
  };

  # [<scraper>] section - scraper-specific overrides
  scraper = lib.types.submodule {
    options = selectOptions [
      # General
      "interactive"
      "unattend"
      "unattendSkip"
      "threads"
      # Media
      "videos"
      "videoSizeLimit"
      # Processing
      "minMatch"
      "maxLength"
      "tidyDesc"
      "onlyMissing"
      # Cache
      "cacheCovers"
      "cacheScreenshots"
      "cacheWheels"
      "cacheMarquees"
      "cacheTextures"
      "cacheResize"
      "cacheRefresh"
      "jpgQuality"
      # Scraper-specific
      "userCreds"
      "videoPreferNormalized"
    ];
  };
}
