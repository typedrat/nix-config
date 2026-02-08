# Localization settings for Skyscraper.
{
  lib,
  skyscraperTypes,
  ...
}: {
  options = {
    region = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.region;
      default = null;
      example = "eu";
      description = ''
        Primary region preference for game data. Adds this region to the
        top of the internal region priority list.

        To completely replace the priority list, use `regionPriorities` instead.

        Setting a region overrides any region auto-detected from the ROM filename.

        See <https://gemba.github.io/skyscraper/REGIONS/>.
      '';
    };

    language = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.lang;
      default = null;
      example = "en";
      description = ''
        Primary language preference for game data. Adds this language to
        the top of the internal language priority list.

        To completely replace the priority list, use `languagePriorities` instead.

        See <https://gemba.github.io/skyscraper/LANGUAGES/>.
      '';
    };

    regionPriorities = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf skyscraperTypes.region);
      default = null;
      defaultText = lib.literalMD ''`["eu" "us" "ss" "uk" "wor" "jp" ...]`'';
      example = ["eu" "us" "jp"];
      description = ''
        Ordered list of region priorities. Completely replaces the internal
        region priority list.

        Any region auto-detected from the ROM filename is still added to
        the top of this list.

        See <https://gemba.github.io/skyscraper/REGIONS/>.
      '';
    };

    languagePriorities = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf skyscraperTypes.lang);
      default = null;
      defaultText = lib.literalMD ''`["en" "de" "fr" "es"]`'';
      example = ["en" "de" "fr"];
      description = ''
        Ordered list of language priorities. Completely replaces the internal
        language priority list.

        See <https://gemba.github.io/skyscraper/LANGUAGES/>.
      '';
    };
  };
}
