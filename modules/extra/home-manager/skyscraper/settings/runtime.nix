# Runtime behavior settings for Skyscraper.
{
  lib,
  skyscraperTypes,
  ...
}: {
  options = {
    verbosity = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.verbosity;
      default = null;
      defaultText = lib.literalMD "`0` (quiet)";
      example = "verbose";
      description = ''
        Output verbosity level.

        Accepts either an integer (0-3) or a descriptive string:
        - `0` / `"quiet"` — minimal output
        - `1` / `"normal"` — standard output
        - `2` / `"verbose"` — detailed output
        - `3` / `"debug"` — debug output (shows video conversion output)
      '';
    };

    threads = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      defaultText = lib.literalMD "`4`";
      description = ''
        Number of parallel threads for scraping or game list creation.

        Some modules enforce a lower maximum; values above the limit are
        auto-adjusted. Cannot exceed the system's ideal thread count.
      '';
    };

    pretend = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Disable the game list generator and artwork compositor, only
        printing potential results to the terminal.

        Only relevant when generating a game list (without `-s <SCRAPER>`).
      '';
    };

    interactive = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        When scraping, present a list of candidate matches and let you
        choose the correct one instead of having Skyscraper pick automatically.
      '';
    };

    hints = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''"Did you know" hint messages when running Skyscraper.'';
    };

    spaceCheck = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Monitor disk space and abort if either the game list export folder
        or the cache folder drops below 200 MB.

        Disable if your filesystem reports incorrect free space.
      '';
    };

    maxConsecutiveFails = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 1 200);
      default = null;
      defaultText = lib.literalMD "`42`";
      description = ''
        Maximum number of consecutive failed ROM lookups before Skyscraper
        aborts the scraping run.

        Protects against running an incompatible scraper/platform combination.
      '';
    };

    unattended = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Skip all confirmation prompts, overwriting existing game lists
              without asking.

              Also suppresses confirmation prompts for cache `purge:all` and
              `vacuum` operations.
            '';
          };

          skipExisting = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Skip existing game list entries without prompting, preserving
              them rather than recreating from cache.

              Has no effect when `enable` is true (entries are always recreated),
              when `--query` is used, or when the frontend generator does not
              support preserving entries.
            '';
          };
        };
      };
      default = {};
      description = "Unattended/non-interactive operation settings.";
    };
  };
}
