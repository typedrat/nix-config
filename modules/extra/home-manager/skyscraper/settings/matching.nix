# Matching/search settings for Skyscraper.
{lib, ...}: {
  options = {
    minPercent = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 100);
      default = null;
      defaultText = lib.literalMD "`65`";
      description = ''
        Minimum percentage match required for a search result to be accepted.
        Lower values accept fuzzier matches.
      '';
    };

    maxDescriptionLength = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      defaultText = lib.literalMD "`2500`";
      description = "Maximum character length for game descriptions.";
    };

    tidyDescriptions = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Clean up common formatting issues in scraped descriptions:
        strip leading/trailing spaces, collapse multiple spaces, replace
        bullet characters with dashes, normalize ellipsis characters,
        and reduce excessive exclamation marks.
      '';
    };

    unpackArchives = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Extract compressed ROMs (zip/7z) before computing file checksums
        for identification.

        Use this when scraping modules fail to identify your compressed ROMs.

        **Note:** Significantly slows down scraping. Only enable if
        compressed ROMs are not being identified.
      '';
    };

    searchByStem = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = ".cue .gdi";
      description = ''
        File extensions for which Skyscraper should search by filename stem
        instead of file checksum when using the ScreenScraper module.

        Provide a space-separated list of extensions (e.g., `".cue .gdi"`)
        or `"all"` to apply to all extensions for the platform.

        Only affects ScreenScraper queries.
      '';
    };
  };
}
