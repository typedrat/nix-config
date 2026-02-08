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

    settings = lib.mkOption {
      inherit (settingsFormat) type;
      default = {};
      example = lib.literalExpression ''
        {
          main = {
            frontend = "emulationstation";
            inputFolder = "/home/user/roms";
            cacheFolder = "/home/user/.skyscraper/cache";
            videos = true;
            unattend = true;
          };
          snes = {
            inputFolder = "/home/user/roms/snes";
            minMatch = 80;
          };
          screenscraper = {
            userCreds = "username:password";
            threads = 2;
          };
        }
      '';
      description = ''
        Configuration settings for Skyscraper's {file}`config.ini`.

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

    xdg.configFile."skyscraper/config.ini" = lib.mkIf (cfg.enableXdg && cfg.settings != {}) {
      source = settingsFormat.generate "config.ini" cfg.settings;
    };

    home.file.".skyscraper/config.ini" = lib.mkIf (!cfg.enableXdg && cfg.settings != {}) {
      source = settingsFormat.generate "config.ini" cfg.settings;
    };
  };
}
