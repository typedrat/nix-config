{lib, ...}: let
  inherit (lib) options types;

  skyscraperOptions = types.submodule {
    options = {
      enable = options.mkEnableOption "Skyscraper ROM scraper";

      romsPath = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to ROM files. Defaults to ~/Games/roms.";
      };

      gameListsPath = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path for game list output. Defaults to romsPath.";
      };

      mediaPath = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path for media files. Defaults to romsPath.";
      };

      cachePath = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path for Skyscraper cache. Defaults to ~/.cache/skyscraper.";
      };

      region = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Primary region (e.g., us, eu, jp). Defaults to us.";
      };

      language = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Primary language (e.g., en, de, ja). Defaults to en.";
      };

      frontend = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Frontend to generate game lists for. Defaults to pegasus.";
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.skyscraper = options.mkOption {
        type = skyscraperOptions;
        default = {};
        description = "Skyscraper ROM scraper configuration";
      };
    });
  };
}
