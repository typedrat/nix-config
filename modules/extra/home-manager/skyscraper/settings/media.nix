# Media scraping settings for Skyscraper.
{lib, ...}: {
  options = {
    videos = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Scrape and cache video resources.

              Videos require significant disk space. See `symlink` to save
              space by linking instead of copying.
            '';
          };

          maxSize = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            defaultText = lib.literalMD "`100`";
            description = ''
              Maximum allowed video file size in megabytes.
              Videos exceeding this size are not cached.
            '';
          };

          symlink = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Create symbolic links to cached videos instead of copying them
              when generating game list media.

              Saves disk space but the links break if the cache is cleared.
              Only relevant when `enable` is true.
            '';
          };

          preferNormalized = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`true`";
            description = ''
              Prefer ScreenScraper's normalized (standardized) video versions
              over the originals.

              Disable to fetch original videos, which vary in codec, color
              format, and resolution—consider using `convert` to standardize
              them yourself.

              Only applies to the `screenscraper` scraping module.
            '';
          };

          convert = lib.mkOption {
            type = lib.types.submodule {
              options = {
                command = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "ffmpeg -i %i -y -pix_fmt yuv420p -t 00:00:10 -c:v libx264 -crf 23 %o";
                  description = ''
                    Shell command to convert video files after download.

                    The placeholders `%i` (input) and `%o` (output) are required
                    and are replaced with temporary filenames managed by Skyscraper.

                    If your command does not convert a given video, it should
                    copy the input to the output with `cp %i %o`.
                  '';
                };

                extension = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "mp4";
                  description = ''
                    Force a specific file extension for converted videos.
                    Ensure `command` actually produces files in this format.
                  '';
                };
              };
            };
            default = {};
            description = "Video conversion settings.";
          };
        };
      };
      default = {};
      description = "Video scraping and processing settings.";
    };

    manuals = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Scrape and cache game manuals (PDFs).

        Not all scraping modules provide manuals, and only some frontends
        support PDF display. ES-DE and Batocera output manuals automatically.
      '';
    };

    backcovers = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Scrape and cache back cover artwork.

        Not all scraping modules provide this data. ES-DE and Batocera
        output backcovers automatically during game list creation.
      '';
    };

    fanart = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Scrape and cache fan art.

        Not all scraping modules provide this data. ES-DE and Batocera
        output fan art automatically.
      '';
    };

    cropBlackBorders = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Crop black borders from screenshot resources when compositing
        final artwork.
      '';
    };
  };
}
