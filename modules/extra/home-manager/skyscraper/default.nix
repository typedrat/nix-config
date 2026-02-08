# Skyscraper home-manager module.
#
# Provides declarative configuration for Skyscraper, a game scraper for
# emulation frontends. Supports nested Nix-native settings that are
# converted to flat INI format, with secure secrets handling via
# activation-time substitution.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.skyscraper;

  # Import type definitions
  skyscraperTypes = import ./types.nix {inherit lib;};

  # Import settings submodule types
  mainSettingsType = import ./settings/default.nix {inherit lib skyscraperTypes;};
  platformSettingsType = import ./scopes/platforms.nix {inherit lib skyscraperTypes;};
  frontendSettingsType = import ./scopes/frontends.nix {inherit lib skyscraperTypes;};
  scraperSettingsType = import ./scopes/scrapers.nix {inherit lib skyscraperTypes;};

  # Import conversion functions
  convert = import ./convert.nix {inherit lib;};

  # INI format with custom boolean rendering.
  # Skyscraper expects lowercase "true"/"false", not "True"/"False".
  settingsFormat = pkgs.formats.ini {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString = v:
        if lib.isBool v
        then lib.boolToString v
        else lib.generators.mkValueStringDefault {} v;
    } "=";
  };

  # ── Settings Conversion ─────────────────────────────────────────────
  #
  # Convert the nested Nix structure to flat INI sections.

  # Main section
  mainSection = convert.mainSettingsToIni cfg.settings;

  # Platform sections
  platformSections = lib.mapAttrs (_: convert.platformSettingsToIni) cfg.platforms;

  # Frontend sections
  frontendSections = lib.mapAttrs (_: convert.frontendSettingsToIni) cfg.frontends;

  # Scraper sections (with secrets extraction)
  scraperResults = lib.mapAttrs convert.scraperSettingsToIni cfg.scrapers;
  scraperSections = lib.mapAttrs (_: v: v.attrs) scraperResults;

  # Collect all secrets that need activation-time substitution
  # Format: [ { placeholder = "@SCREENSCRAPER_CREDS@"; file = "/run/secrets/..."; } ... ]
  secrets =
    lib.filter (s: s != null) (lib.mapAttrsToList (_: v: v.secret) scraperResults);

  hasSecrets = secrets != [];

  # ── INI Generation ──────────────────────────────────────────────────

  # Combine all structured settings, filtering out empty sections
  structuredSettings = let
    nonEmpty = lib.filterAttrs (_: v: v != {});
  in
    nonEmpty (
      {main = mainSection;}
      // platformSections
      // frontendSections
      // scraperSections
    );

  # Merge structured settings with extraSettings (extraSettings wins)
  finalSettings = lib.recursiveUpdate structuredSettings cfg.extraSettings;

  hasSettings = finalSettings != {};

  # Generate the config file (as a template if secrets exist)
  configFile = settingsFormat.generate "config.ini" finalSettings;

  # ── Config Path Resolution ──────────────────────────────────────────

  configDir =
    if cfg.enableXdg
    then "${config.xdg.configHome}/skyscraper"
    else "${config.home.homeDirectory}/.skyscraper";

  configFilePath = "${configDir}/config.ini";

  # ── Activation Script ───────────────────────────────────────────────
  #
  # When secrets are used, we:
  # 1. Copy the template config (from Nix store) to the config directory
  # 2. Set restrictive permissions (600)
  # 3. Substitute each secret placeholder with the file contents
  #
  # This ensures secrets are never in the Nix store while still allowing
  # declarative configuration.

  activationScript = let
    # Generate sed commands for each secret substitution
    sedCommands =
      lib.concatMapStringsSep " " (secret: let
        # Escape special characters in placeholder for sed
        file = lib.escapeShellArg (toString secret.file);
      in ''
        -e "s|${secret.placeholder}|$(cat ${file} | tr -d '\n')|g"
      '')
      secrets;
  in ''
    # Skyscraper config with secrets substitution
    config_dir=${lib.escapeShellArg configDir}
    config_file=${lib.escapeShellArg configFilePath}
    template=${lib.escapeShellArg (toString configFile)}

    # Ensure config directory exists
    mkdir -p "$config_dir"

    # Copy template and set permissions
    install -m 600 "$template" "$config_file"

    # Substitute secrets
    ${lib.optionalString hasSecrets ''
      sed -i ${sedCommands} "$config_file"
    ''}
  '';
in {
  meta.maintainers = [];

  options.programs.skyscraper = import ./options.nix {
    inherit
      lib
      pkgs
      skyscraperTypes
      mainSettingsType
      platformSettingsType
      frontendSettingsType
      scraperSettingsType
      settingsFormat
      ;
  };

  config = lib.mkIf cfg.enable {
    # Install the package
    home.packages = [
      (
        if cfg.enableXdg
        then cfg.package.override {enableXdg = true;}
        else cfg.package
      )
    ];

    # Handle configuration based on whether secrets are used
    #
    # If configPath is set: use it directly
    # If secrets are used: use activation script
    # Otherwise: use declarative file management

    xdg.configFile."skyscraper/config.ini" = lib.mkIf (cfg.enableXdg && !hasSecrets) (
      if cfg.configPath != null
      then {source = cfg.configPath;}
      else lib.mkIf hasSettings {source = configFile;}
    );

    home.file.".skyscraper/config.ini" = lib.mkIf (!cfg.enableXdg && !hasSecrets) (
      if cfg.configPath != null
      then {source = cfg.configPath;}
      else lib.mkIf hasSettings {source = configFile;}
    );

    # Use activation script when secrets need substitution
    home.activation.skyscraperConfig = lib.mkIf (hasSettings && hasSecrets && cfg.configPath == null) (
      lib.hm.dag.entryAfter ["writeBoundary"] activationScript
    );

    # Assertions for invalid configurations
    assertions = [
      {
        assertion = !(cfg.configPath != null && (cfg.settings != {} || cfg.platforms != {} || cfg.frontends != {} || cfg.scrapers != {} || cfg.extraSettings != {}));
        message = ''
          programs.skyscraper.configPath is set, but other configuration options
          are also defined. When using configPath, all other configuration options
          (settings, platforms, frontends, scrapers, extraSettings) are ignored.
          Either remove configPath or remove the other options.
        '';
      }
    ];
  };
}
