# Output/frontend settings for Skyscraper.
{
  lib,
  skyscraperTypes,
  ...
}: {
  options = {
    frontend = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.frontend;
      default = null;
      defaultText = lib.literalMD "`emulationstation`";
      description = ''
        Frontend to generate game lists for.

        See <https://gemba.github.io/skyscraper/FRONTENDS/>.
      '';
    };

    platform = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.platform;
      default = null;
      description = ''
        Default platform, applied when no `-p` command line switch is given.
      '';
    };

    artworkXml = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
      defaultText = lib.literalMD "`artwork.xml`";
      example = "artwork-pegasus.xml";
      description = ''
        Path to an artwork XML configuration file for compositing.

        Accepts an absolute path, a Nix store path, or a filename relative
        to the Skyscraper configuration directory.

        See <https://gemba.github.io/skyscraper/ARTWORK/>.
      '';
    };

    emulator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Emulator name used when generating game lists for the `attractmode`
        frontend. On RetroPie, this is typically the same as the platform name.
      '';
    };

    launchCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Launch command used when generating game lists for the `pegasus` frontend.
      '';
    };

    gameList = lib.mkOption {
      type = lib.types.submodule {
        options = {
          filename = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "metadata.txt";
            description = ''
              Override the game list filename. Useful for avoiding duplicate
              entries, e.g., generating `metadata.txt` instead of
              `metadata.pegasus.txt` when using Pegasus with EmuDeck.
            '';
          };

          variants = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            example = ["enable-manuals"];
            description = ''
              List of gamelist variant options.

              Currently only `enable-manuals` is supported, which generates
              `<manual/>` entries for scraped game manuals.

              Only supported for the `emulationstation` frontend.
              Not needed for ES-DE (which handles manuals automatically).
            '';
          };

          backup = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Create a timestamped backup of the existing game list each time
              Skyscraper runs in game list generation mode.
            '';
          };

          relativePaths = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Force ROM and media paths inside the game list to be relative
              to the game list file's directory.

              Has no effect when the frontend is set to `attractmode`.
            '';
          };

          includeSkipped = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Include ROMs with no cached data as generic entries (containing
              only path and name) instead of omitting them entirely.
            '';
          };

          includeFolders = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Generate `<folder/>` metadata elements in the gamelist XML for
              each directory containing ROMs.

              Only supported for `emulationstation`, `esde`, and `retrobat` frontends.
            '';
          };

          hiddenMediaFolder = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            defaultText = lib.literalMD "`false`";
            description = ''
              Use a hidden `.media` folder instead of `media` for frontend artwork.
              Can speed up initial frontend loading on slow storage.

              Only supported for `emulationstation` and `retrobat` frontends.
              Ignored if `paths.media` is set explicitly.
            '';
          };
        };
      };
      default = {};
      description = "Game list output settings.";
    };
  };
}
