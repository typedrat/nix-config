# Frontend-specific settings submodule.
#
# Frontends can override a subset of settings, with some options
# restricted to specific frontend names.
{
  lib,
  skyscraperTypes,
}: let
  # Import settings submodules (subset for frontends)
  # Frontend-specific paths (no cache or import)
  frontendPathsModule = {lib, ...}: {
    options = {
      roms = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "ROM input directory for this frontend.";
      };

      gameLists = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Game list output directory for this frontend.";
      };

      media = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Media output directory for this frontend.";
      };
    };
  };
in
  # Use a function submodule to get access to the frontend name
  lib.types.submodule ({name, ...}: {
    options = {
      paths = lib.mkOption {
        type = lib.types.submodule frontendPathsModule;
        default = {};
        description = "Path settings for this frontend.";
      };

      output = lib.mkOption {
        type = lib.types.submodule (_: {
          options = {
            artworkXml = lib.mkOption {
              type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
              default = null;
              description = "Artwork XML for this frontend.";
            };

            emulator = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Emulator name (attractmode).";
            };

            launchCommand = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Launch command (pegasus).";
            };

            gameList = lib.mkOption {
              type = lib.types.submodule (_: {
                options =
                  {
                    filename = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Override game list filename.";
                    };

                    backup = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Create timestamped backups.";
                    };

                    relativePaths = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Use relative paths.";
                    };

                    includeSkipped = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Include ROMs with no cached data.";
                    };
                  }
                  # emulationstation, esde, retrobat only
                  // lib.optionalAttrs (lib.elem name ["emulationstation" "esde" "retrobat"]) {
                    includeFolders = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Generate folder metadata elements.";
                    };
                  }
                  # emulationstation, retrobat only
                  // lib.optionalAttrs (lib.elem name ["emulationstation" "retrobat"]) {
                    hiddenMediaFolder = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Use hidden .media folder.";
                    };
                  }
                  # emulationstation only
                  // lib.optionalAttrs (name == "emulationstation") {
                    variants = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [];
                      example = ["enable-manuals"];
                      description = "Gamelist variant options.";
                    };
                  };
              });
              default = {};
              description = "Game list settings.";
            };
          };
        });
        default = {};
        description = "Output settings for this frontend.";
      };

      titles = lib.mkOption {
        type = lib.types.submodule (_: {
          options = {
            keepBrackets = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Keep bracket notes in titles.";
            };

            articlePosition = lib.mkOption {
              type = lib.types.nullOr skyscraperTypes.articlePosition;
              default = null;
              description = "Article position in titles.";
            };

            forceFilename = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Use filename as game name.";
            };
          };
        });
        default = {};
        description = "Title formatting for this frontend.";
      };

      media = lib.mkOption {
        type = lib.types.submodule (_: {
          options = {
            videos = lib.mkOption {
              type = lib.types.submodule (_: {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Include videos in output.";
                  };

                  symlink = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Symlink videos instead of copying.";
                  };
                };
              });
              default = {};
              description = "Video settings.";
            };

            cropBlackBorders = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Crop black borders from screenshots.";
            };
          };
        });
        default = {};
        description = "Media settings for this frontend.";
      };

      matching = lib.mkOption {
        type = lib.types.submodule (_: {
          options = {
            maxDescriptionLength = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = "Max description length.";
            };
          };
        });
        default = {};
        description = "Matching settings for this frontend.";
      };

      filter = lib.mkOption {
        type = lib.types.submodule (_: {
          options = {
            excludePattern = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Exclude pattern.";
            };

            includePattern = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Include pattern.";
            };

            startAt = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Start at filename.";
            };

            endAt = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "End at filename.";
            };
          };
        });
        default = {};
        description = "Filter settings for this frontend.";
      };

      runtime = lib.mkOption {
        type = lib.types.submodule (_: {
          options = {
            verbosity = lib.mkOption {
              type = lib.types.nullOr skyscraperTypes.verbosity;
              default = null;
              description = "Verbosity level.";
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
        description = "Runtime settings for this frontend.";
      };
    };
  })
