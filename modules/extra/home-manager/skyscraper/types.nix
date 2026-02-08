# Type definitions for Skyscraper configuration.
#
# Includes:
#   - Enum types for validated string values (region, lang, platform, etc.)
#   - Composite types (verbosity, articlePosition, credentials, extensions)
#
# Sources:
#   Platforms: https://gemba.github.io/skyscraper/PLATFORMS/
#   Regions:   https://gemba.github.io/skyscraper/REGIONS/
#   Languages: https://gemba.github.io/skyscraper/LANGUAGES/
#   Frontends: https://gemba.github.io/skyscraper/FRONTENDS/
#   Scrapers:  Skyscraper --help / -s option
{lib}: rec {
  # ── Enum Types ─────────────────────────────────────────────────────

  region = lib.types.enum [
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
  ];

  lang = lib.types.enum [
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
  ];

  frontend = lib.types.enum [
    "attractmode"
    "batocera"
    "emulationstation"
    "esde"
    "pegasus"
    "retrobat"
  ];

  platform = lib.types.enum [
    "3do"
    "3ds"
    "actionmax"
    "ags"
    "amiga"
    "amstradcpc"
    "apple2"
    "apple2gs"
    "arcade"
    "arcadia"
    "arduboy"
    "astrocade"
    "atari2600"
    "atari5200"
    "atari7800"
    "atari800"
    "atarijaguar"
    "atarijaguarcd"
    "atarilynx"
    "atarist"
    "atomiswave"
    "c128"
    "c64"
    "cd32"
    "cdi"
    "cdtv"
    "channelf"
    "coco"
    "coleco"
    "crvision"
    "daphne"
    "dragon32"
    "dreamcast"
    "easyrpg"
    "fba"
    "fds"
    "fm7"
    "fmtowns"
    "gameandwatch"
    "gamecom"
    "gamegear"
    "gb"
    "gba"
    "gbc"
    "gc"
    "gmaster"
    "intellivision"
    "j2me"
    "love"
    "macintosh"
    "mame"
    "mame-advmame"
    "mame-libretro"
    "mame-mame4all"
    "mastersystem"
    "megadrive"
    "megaduck"
    "moto"
    "msx"
    "msx2"
    "n64"
    "n64dd"
    "naomi"
    "naomi2"
    "nds"
    "neogeo"
    "neogeocd"
    "nes"
    "ngp"
    "ngpc"
    "openbor"
    "oric"
    "palm"
    "pc"
    "pc88"
    "pc98"
    "pcengine"
    "pcenginecd"
    "pcfx"
    "pico8"
    "plus4"
    "pokemini"
    "ports"
    "ps2"
    "ps3"
    "ps4"
    "ps5"
    "psp"
    "psvita"
    "psx"
    "pv1000"
    "samcoupe"
    "saturn"
    "scummvm"
    "scv"
    "sega32x"
    "segacd"
    "sg-1000"
    "snes"
    "solarus"
    "steam"
    "stratagus"
    "supervision"
    "switch"
    "symbian"
    "ti99"
    "tic80"
    "trs-80"
    "vectrex"
    "vic20"
    "videopac"
    "vircon32"
    "virtualboy"
    "vsmile"
    "wii"
    "wiiu"
    "wonderswan"
    "wonderswancolor"
    "x1"
    "x68000"
    "xbox"
    "xbox360"
    "zmachine"
    "zx81"
    "zxspectrum"
  ];

  scraper = lib.types.enum [
    # Web scrapers
    "arcadedb"
    "igdb"
    "mobygames"
    "openretro"
    "screenscraper"
    "thegamesdb"
    "zxinfo"
    # Aliases
    "worldofspectrum"
    "wos"
    # Local scrapers
    "esgamelist"
    "gamebase"
    "import"
  ];

  # ── Composite Types ────────────────────────────────────────────────

  # Verbosity: accepts either int 0-3 or descriptive enum
  verbosity =
    lib.types.either
    (lib.types.ints.between 0 3)
    (lib.types.enum ["quiet" "normal" "verbose" "debug"]);

  # Article position in titles: more descriptive than theInFront boolean
  articlePosition = lib.types.enum ["front" "end"];

  # Credentials: either inline text (insecure) or file path (secure)
  credentials = lib.types.submodule {
    options = {
      text = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Credentials as plain text (`user:password` or API key).

          **Security warning:** This value is stored in the world-readable
          Nix store. Only use for testing. For real credentials, use the
          `file` option with sops-nix or agenix.
        '';
      };

      file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to a file containing credentials.

          The file is read at activation time, making it compatible with
          sops-nix, agenix, or any other secrets manager. The file should
          contain the credentials in `user:password` format (or API key
          format, depending on the scraper).
        '';
      };
    };
  };

  # Extensions: override or additional
  extensions = lib.types.submodule {
    options = {
      set = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = ["sfc" "smc"];
        description = ''
          Completely replace the platform's default extensions.
          Specify extensions without the `*.` prefix.
        '';
      };

      add = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["zip" "7z"];
        description = ''
          Additional extensions to recognize, on top of defaults.
          Only applied when `set` is not specified.
          Specify extensions without the `*.` prefix.
        '';
      };
    };
  };

  # ── Helper Functions ───────────────────────────────────────────────

  # Convert verbosity to int for INI output
  verbosityToInt = v:
    if builtins.isInt v
    then v
    else
      {
        quiet = 0;
        normal = 1;
        verbose = 2;
        debug = 3;
      }
      .${
        v
      };

  # Convert articlePosition to theInFront boolean
  articlePositionToBool = pos: pos == "front";

  # Check if credentials are set (either text or file)
  hasCredentials = creds:
    (creds.text or null) != null || (creds.file or null) != null;

  # Get inline credential text (for template), or placeholder for file
  credentialsToTemplate = name: creds:
    if (creds.text or null) != null
    then creds.text
    else if (creds.file or null) != null
    then "@${lib.toUpper name}_CREDS@"
    else null;
}
