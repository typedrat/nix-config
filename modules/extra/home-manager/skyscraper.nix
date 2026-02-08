{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.skyscraper;

  # INI format with custom key-value handling for Skyscraper
  # Skyscraper expects lowercase "true"/"false" for booleans
  settingsFormat = pkgs.formats.ini {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString = v:
        if lib.isBool v
        then lib.boolToString v
        else lib.generators.mkValueStringDefault {} v;
    } "=";
  };

  # Build settings from structured options
  mainSettings = lib.filterAttrs (_: v: v != null) {
    inherit (cfg) frontend;
    inputFolder =
      if cfg.inputFolder != null
      then toString cfg.inputFolder
      else null;
    gameListFolder =
      if cfg.gameListFolder != null
      then toString cfg.gameListFolder
      else null;
    mediaFolder =
      if cfg.mediaFolder != null
      then toString cfg.mediaFolder
      else null;
    cacheFolder =
      if cfg.cacheFolder != null
      then toString cfg.cacheFolder
      else null;
    inherit (cfg) videos;
    inherit (cfg) manuals;
    inherit (cfg) unattend;
    inherit (cfg) threads;
    inherit (cfg) region;
    inherit (cfg) lang;
  };

  structuredSettings = lib.optionalAttrs (mainSettings != {}) {main = mainSettings;};

  # Merge structured settings with extraSettings (extraSettings takes precedence)
  settings = lib.recursiveUpdate structuredSettings cfg.extraSettings;

  hasSettings = settings != {};
in {
  meta.maintainers = [];

  options.programs.skyscraper = {
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

    frontend = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "emulationstation"
        "esde"
        "pegasus"
        "retrobat"
        "attractmode"
      ]);
      default = null;
      description = ''
        The frontend to generate game lists for.
      '';
    };

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

    unattend = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Skip confirmation prompts and run non-interactively.
      '';
    };

    threads = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = ''
        Number of parallel scraping threads.
      '';
    };

    region = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "ame"
        "asi"
        "au"
        "bg"
        "br"
        "ca"
        "cl"
        "cn"
        "cus"
        "cz"
        "de"
        "dk"
        "eu"
        "fi"
        "fr"
        "gr"
        "hu"
        "il"
        "it"
        "jp"
        "kr"
        "kw"
        "mor"
        "nl"
        "no"
        "nz"
        "oce"
        "pe"
        "pl"
        "pt"
        "ru"
        "se"
        "sk"
        "sp"
        "ss"
        "tr"
        "tw"
        "uk"
        "us"
        "wor"
      ]);
      default = null;
      example = "eu";
      description = ''
        Primary region preference for game data.

        See <https://gemba.github.io/skyscraper/REGIONS/> for details.
      '';
    };

    lang = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "cz"
        "da"
        "de"
        "en"
        "es"
        "fi"
        "fr"
        "hu"
        "it"
        "ja"
        "ko"
        "nl"
        "no"
        "pl"
        "pt"
        "ru"
        "sk"
        "sv"
        "tr"
        "zh"
      ]);
      default = null;
      example = "en";
      description = ''
        Primary language preference for game data.

        See <https://gemba.github.io/skyscraper/LANGUAGES/> for details.
      '';
    };

    extraSettings = lib.mkOption {
      inherit (settingsFormat) type;
      default = {};
      example = lib.literalExpression ''
        {
          main = {
            minMatch = 80;
            maxLength = 500;
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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (
        if cfg.enableXdg
        then cfg.package.override {enableXdg = true;}
        else cfg.package
      )
    ];

    xdg.configFile."skyscraper/config.ini" = lib.mkIf cfg.enableXdg (
      if cfg.configPath != null
      then {source = cfg.configPath;}
      else lib.mkIf hasSettings {source = settingsFormat.generate "config.ini" settings;}
    );

    home.file.".skyscraper/config.ini" = lib.mkIf (!cfg.enableXdg) (
      if cfg.configPath != null
      then {source = cfg.configPath;}
      else lib.mkIf hasSettings {source = settingsFormat.generate "config.ini" settings;}
    );
  };
}
