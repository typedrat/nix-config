# Path settings for Skyscraper.
#
# Note: In [main] scope, /<PLATFORM> is auto-appended to paths.
# In platform-specific sections, paths are used exactly as specified.
{lib, ...}: {
  options = {
    roms = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalMD "`/home/<USER>/RetroPie/roms/<PLATFORM>`";
      example = "/home/user/roms";
      description = ''
        Path to the ROM input directory.

        In the main settings, `/<PLATFORM>` is automatically appended.
        In platform-specific settings, the path is used exactly as specified.
      '';
    };

    gameLists = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalMD "`/home/<USER>/RetroPie/roms/<PLATFORM>`";
      example = "/home/user/gamelists";
      description = ''
        Path where game list files are exported.

        In the main settings, `/<PLATFORM>` is automatically appended.
        In platform-specific settings, the path is used exactly as specified.
      '';
    };

    media = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalMD "`/home/<USER>/RetroPie/roms/<PLATFORM>/media`";
      example = "/home/user/media";
      description = ''
        Path where media files (artwork, videos) are stored.

        In the main settings, `/<PLATFORM>` is automatically appended.
        In platform-specific settings, the path is used exactly as specified.
      '';
    };

    cache = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalMD "`/home/<USER>/.skyscraper/cache/<PLATFORM>`";
      description = ''
        Path to the resource cache directory.

        Only change this if you have a specific reason, such as caching
        to a USB drive or network storage.
      '';
    };

    import = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalMD "`/home/<USER>/.skyscraper/import/<PLATFORM>`";
      description = ''
        Path to the folder used by the `-s import` scraping module.
        Skyscraper looks for a `/<PLATFORM>` subdirectory inside this folder.

        See <https://gemba.github.io/skyscraper/IMPORT/>.
      '';
    };
  };
}
