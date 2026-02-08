{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.skyscraper;

  skyscraperTypes = import ./types.nix {inherit lib;};

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

  # Helper to convert path to string if not null
  pathToString = p:
    if p != null
    then toString p
    else null;

  # Build settings from structured options
  mainSettings = lib.filterAttrs (_: v: v != null) {
    # General
    inherit (cfg.settings) frontend verbosity hints pretend interactive unattend threads;

    # Paths
    inputFolder = pathToString cfg.settings.inputFolder;
    gameListFolder = pathToString cfg.settings.gameListFolder;
    mediaFolder = pathToString cfg.settings.mediaFolder;
    cacheFolder = pathToString cfg.settings.cacheFolder;

    # Localization
    inherit (cfg.settings) region lang;

    # Game list
    inherit (cfg.settings) gameListBackup relativePaths skipped;

    # Title formatting
    inherit (cfg.settings) brackets theInFront;

    # Media
    inherit (cfg.settings) videos manuals backcovers fanarts symlink;

    # Processing
    inherit (cfg.settings) minMatch maxLength tidyDesc cropBlack subdirs;

    # Cache options
    cacheCovers = cfg.settings.cache.covers;
    cacheScreenshots = cfg.settings.cache.screenshots;
    cacheWheels = cfg.settings.cache.wheels;
    cacheMarquees = cfg.settings.cache.marquees;
    cacheTextures = cfg.settings.cache.textures;
    cacheResize = cfg.settings.cache.resize;
    cacheRefresh = cfg.settings.cache.refresh;
  };

  structuredSettings = lib.optionalAttrs (mainSettings != {}) {main = mainSettings;};

  # Merge structured settings with extraSettings (extraSettings takes precedence)
  finalSettings = lib.recursiveUpdate structuredSettings cfg.extraSettings;

  hasSettings = finalSettings != {};
in {
  meta.maintainers = [];

  options.programs.skyscraper = import ./options.nix {
    inherit lib pkgs skyscraperTypes settingsFormat;
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
      else lib.mkIf hasSettings {source = settingsFormat.generate "config.ini" finalSettings;}
    );

    home.file.".skyscraper/config.ini" = lib.mkIf (!cfg.enableXdg) (
      if cfg.configPath != null
      then {source = cfg.configPath;}
      else lib.mkIf hasSettings {source = settingsFormat.generate "config.ini" finalSettings;}
    );
  };
}
