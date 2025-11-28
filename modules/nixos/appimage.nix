{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.appimage.enable =
    mkEnableOption "AppImage"
    // {
      default = true;
    };

  config = mkIf config.rat.appimage.enable {
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
  };
}
