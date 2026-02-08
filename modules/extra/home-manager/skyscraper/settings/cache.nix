# Cache settings for Skyscraper.
{lib, ...}: {
  options = {
    covers = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Cache cover artwork when scraping.
        Disable to save space if covers are not used in your artwork configuration.
      '';
    };

    screenshots = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Cache screenshot images when scraping.
        Disable to save space if screenshots are not used in your artwork configuration.
      '';
    };

    wheels = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Cache wheel graphics when scraping.
        Disable to save space if wheels are not used in your artwork configuration.
      '';
    };

    marquees = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Cache marquee artwork when scraping.
        Disable to save space if marquees are not used in your artwork configuration.
      '';
    };

    textures = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Cache texture resources when scraping.
        Disable to save space if textures are not used in your artwork configuration.
      '';
    };

    resize = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Resize large artwork to save space before adding to the resource cache.

        When disabled, artwork is saved at original resolution as lossless
        PNGs, which can consume significant disk space.

        This only affects caching, not artwork compositing during game list generation.
      '';
    };

    forceRefresh = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Force all resources to be refetched from scraping servers,
        updating the cache with fresh data.

        **Use sparingly.** Only enable when you know data has changed at
        the source. Unnecessary use hammers the servers for no benefit.
      '';
    };

    jpegQuality = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 100);
      default = null;
      defaultText = lib.literalMD "`95`";
      description = ''
        JPEG quality level (0-100) when saving image resources to the cache.

        Screenshots and images with transparency are always saved as
        lossless PNGs regardless of this setting.
      '';
    };
  };
}
