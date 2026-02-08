# File filtering settings for Skyscraper.
{lib, ...}: {
  options = {
    includeSubdirs = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Include ROMs in subdirectories of the input folder.
        When disabled, only ROMs directly in the input folder are processed.
      '';
    };

    onlyMissing = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Only scrape ROMs that have no data in Skyscraper's cache.
        Cached entries are left untouched and not updated, even if
        `cache.forceRefresh` is set.
      '';
    };

    excludePattern = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "*[BIOS]*";
      description = ''
        Glob pattern to exclude matching files from processing.
        Use `\,` to match a literal comma.
      '';
    };

    includePattern = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "*.zip";
      description = ''
        Glob pattern to restrict processing to matching files only.
        Use `\,` to match a literal comma.
      '';
    };

    excludeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a text file listing ROMs to exclude, one full path per line.
        Can be generated with `--cache report:missing`.
      '';
    };

    includeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a text file listing the only ROMs to include, one full path
        per line. Can be generated with `--cache report:missing`.
      '';
    };

    startAt = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Begin processing at this ROM filename (alphabetical order).
        All ROMs before this filename are skipped.
      '';
    };

    endAt = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Stop processing at this ROM filename (alphabetical order).
        All ROMs after this filename are skipped.
      '';
    };
  };
}
