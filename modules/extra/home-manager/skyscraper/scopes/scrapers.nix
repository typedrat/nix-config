# Scraper-specific settings submodule.
#
# Scrapers can override a subset of settings, with some options
# restricted to specific scraper names (e.g., videoPreferNormalized
# is only valid for screenscraper).
{
  lib,
  skyscraperTypes,
}:
# Use a function submodule to get access to the scraper name
lib.types.submodule ({name, ...}: {
  options = {
    credentials = lib.mkOption {
      type = skyscraperTypes.credentials;
      default = {};
      description = ''
        Authentication credentials for this scraper.

        Use `file` for secure credentials (read at activation time),
        or `text` for testing only (stored in Nix store).
      '';
    };

    media = lib.mkOption {
      type = lib.types.submodule (_: {
        options = {
          videos = lib.mkOption {
            type = lib.types.submodule (_: {
              options =
                {
                  enable = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Scrape video resources.";
                  };

                  maxSize = lib.mkOption {
                    type = lib.types.nullOr lib.types.ints.positive;
                    default = null;
                    description = "Maximum video file size in MB.";
                  };

                  convert = lib.mkOption {
                    type = lib.types.submodule (_: {
                      options = {
                        command = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Video conversion command.";
                        };

                        extension = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Converted video extension.";
                        };
                      };
                    });
                    default = {};
                    description = "Video conversion settings.";
                  };
                }
                # screenscraper only
                // lib.optionalAttrs (name == "screenscraper") {
                  preferNormalized = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    defaultText = lib.literalMD "`true`";
                    description = ''
                      Prefer ScreenScraper's normalized video versions.
                      Disable to fetch original videos.
                    '';
                  };
                };
            });
            default = {};
            description = "Video settings for this scraper.";
          };
        };
      });
      default = {};
      description = "Media settings for this scraper.";
    };

    cache = lib.mkOption {
      type = lib.types.submodule (_: {
        options = {
          covers = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Cache cover artwork.";
          };

          screenshots = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Cache screenshots.";
          };

          wheels = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Cache wheel graphics.";
          };

          marquees = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Cache marquee artwork.";
          };

          textures = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Cache textures.";
          };

          resize = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Resize artwork before caching.";
          };

          forceRefresh = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Force refetch from servers.";
          };

          jpegQuality = lib.mkOption {
            type = lib.types.nullOr (lib.types.ints.between 0 100);
            default = null;
            description = "JPEG quality (0-100).";
          };
        };
      });
      default = {};
      description = "Cache settings for this scraper.";
    };

    matching = lib.mkOption {
      type = lib.types.submodule (_: {
        options = {
          minPercent = lib.mkOption {
            type = lib.types.nullOr (lib.types.ints.between 0 100);
            default = null;
            description = "Minimum match percentage.";
          };

          maxDescriptionLength = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Maximum description length.";
          };

          tidyDescriptions = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Clean up description formatting.";
          };
        };
      });
      default = {};
      description = "Matching settings for this scraper.";
    };

    filter = lib.mkOption {
      type = lib.types.submodule (_: {
        options = {
          onlyMissing = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Only scrape ROMs not in cache.";
          };
        };
      });
      default = {};
      description = "Filter settings for this scraper.";
    };

    runtime = lib.mkOption {
      type = lib.types.submodule (_: {
        options = {
          threads = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Number of parallel threads.";
          };

          interactive = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Manually select matches.";
          };

          unattended = lib.mkOption {
            type = lib.types.submodule (_: {
              options = {
                enable = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Skip confirmation prompts.";
                };

                skipExisting = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Skip existing entries.";
                };
              };
            });
            default = {};
            description = "Unattended settings.";
          };
        };
      });
      default = {};
      description = "Runtime settings for this scraper.";
    };
  };
})
