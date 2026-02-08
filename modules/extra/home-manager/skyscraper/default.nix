{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.skyscraper;

  skyscraperTypes = import ./types.nix {inherit lib;};
  settingsTypes = import ./settings.nix {inherit lib;};

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

  # Convert a settings attrset to INI-compatible format
  # Handles path conversion and filters out null values
  convertSettings = settings:
    lib.filterAttrs (_: v: v != null) (lib.mapAttrs (
        name: value:
          if lib.elem name ["inputFolder" "gameListFolder" "mediaFolder" "cacheFolder"]
          then pathToString value
          else value
      )
      settings);

  # Build the main section from cfg.settings
  mainSection = convertSettings cfg.settings;

  # Build platform sections
  platformSections = lib.mapAttrs (_: convertSettings) cfg.platforms;

  # Build frontend sections
  frontendSections = lib.mapAttrs (_: convertSettings) cfg.frontends;

  # Build scraper sections
  scraperSections = lib.mapAttrs (_: convertSettings) cfg.scrapers;

  # Combine all structured settings
  structuredSettings = let
    # Filter out empty sections
    nonEmpty = lib.filterAttrs (_: v: v != {});
  in
    nonEmpty (
      {main = mainSection;}
      // platformSections
      // frontendSections
      // scraperSections
    );

  # Merge structured settings with extraSettings (extraSettings takes precedence)
  finalSettings = lib.recursiveUpdate structuredSettings cfg.extraSettings;

  hasSettings = finalSettings != {};
in {
  meta.maintainers = [];

  options.programs.skyscraper = import ./options.nix {
    inherit lib pkgs settingsFormat settingsTypes skyscraperTypes;
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
