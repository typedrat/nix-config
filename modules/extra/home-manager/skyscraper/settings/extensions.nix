# File extension settings for Skyscraper.
{lib, ...}: {
  options = {
    set = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = ["sfc" "smc" "fig"];
      description = ''
        Completely replace the platform's default file extensions.
        Specify extensions without the `*.` prefix.

        If you just want to add extensions without replacing the defaults,
        use `add` instead.
      '';
    };

    add = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      defaultText = lib.literalMD ''`["zip" "7z"]`'';
      example = ["zip" "7z" "rar"];
      description = ''
        Additional file extensions to recognize, on top of the platform's
        built-in extensions.

        Specify extensions without the `*.` prefix.

        Only applied when `set` is not specified.
      '';
    };
  };
}
