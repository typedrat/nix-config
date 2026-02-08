# Skyscraper configuration for ROM scraping.
#
# Enable with: rat.users.<name>.skyscraper.enable = true
{
  config,
  lib,
  osConfig,
  ...
}: let
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  skyscraperCfg = userCfg.skyscraper or {};
in {
  config = lib.mkIf (skyscraperCfg.enable or false) {
    # Declare the screenscraper secrets
    sops.secrets."skyscraper/screenscraper/username" = {
      sopsFile = ../../secrets/skyscraper.yaml;
    };
    sops.secrets."skyscraper/screenscraper/password" = {
      sopsFile = ../../secrets/skyscraper.yaml;
    };

    # Declare the IGDB secrets
    sops.secrets."skyscraper/igdb/clientId" = {
      sopsFile = ../../secrets/skyscraper.yaml;
    };
    sops.secrets."skyscraper/igdb/clientSecret" = {
      sopsFile = ../../secrets/skyscraper.yaml;
    };

    # Template to combine username:password
    sops.templates."skyscraper-screenscraper-creds".content = "${config.sops.placeholder."skyscraper/screenscraper/username"}:${config.sops.placeholder."skyscraper/screenscraper/password"}";

    # Template to combine clientId:clientSecret
    sops.templates."skyscraper-igdb-creds".content = "${config.sops.placeholder."skyscraper/igdb/clientId"}:${config.sops.placeholder."skyscraper/igdb/clientSecret"}";

    programs.skyscraper = {
      enable = true;

      settings = {
        # Path configuration
        paths = {
          roms = skyscraperCfg.romsPath or "/home/${username}/Games/roms";
          gameLists = skyscraperCfg.gameListsPath or "/home/${username}/Games/roms";
          media = skyscraperCfg.mediaPath or "/home/${username}/Games/roms";
          cache = skyscraperCfg.cachePath or "/home/${username}/.cache/skyscraper";
        };

        # Localization
        localization = {
          region = skyscraperCfg.region or "us";
          language = skyscraperCfg.language or "en";
          regionPriorities = ["us" "wor" "eu" "jp"];
          languagePriorities = ["en" "ja"];
        };

        # Output configuration
        output = {
          frontend = skyscraperCfg.frontend or "pegasus";
        };

        # Title formatting
        titles = {
          articlePosition = "end"; # "Legend of Zelda, The" for better sorting
        };

        # Runtime settings
        runtime = {
          verbosity = "normal";
          inherit (osConfig.rat.hardware.cpu) threads;
          unattended.enable = true;
        };

        # Media settings
        media = {
          videos = {
            enable = true;
            symlink = true; # Save disk space
          };
          manuals = true;
          backcovers = true;
        };

        # File extensions
        extensions.add = ["zip" "7z"];

        # Include subdirectories
        filter.includeSubdirs = true;
      };

      # Frontend-specific settings
      frontends = {
        # Batocera for handheld - separate ROM folder
        batocera = {
          paths = {
            roms = "/home/${username}/Games/batocera";
            gameLists = "/home/${username}/Games/batocera";
            media = "/home/${username}/Games/batocera";
          };
        };
      };

      # Platform-specific settings
      platforms = {
        # Nintendo
        nes = {};
        snes = {};
        n64 = {};
        gb = {};
        gbc = {};
        gba = {};

        # Sega
        megadrive = {};
        saturn = {};
        dreamcast = {};

        # Sony
        psx = {};
        ps2 = {};
        psp = {};

        # Arcade
        mame = {};
        fba = {};
      };

      # Scraper credentials
      scrapers = {
        screenscraper = {
          credentials.file = config.sops.templates."skyscraper-screenscraper-creds".path;
          # ScreenScraper has stricter rate limits
          runtime.threads = lib.min 6 osConfig.rat.hardware.cpu.threads;
        };
        igdb = {
          credentials.file = config.sops.templates."skyscraper-igdb-creds".path;
        };
      };
    };
  };
}
