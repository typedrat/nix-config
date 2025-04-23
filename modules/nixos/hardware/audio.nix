{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.audio.enable =
    mkEnableOption "audio"
    // {
      default = config.rat.gui.enable;
    };

  config = mkIf config.rat.audio.enable {
    security.rtkit.enable = true;
    services.avahi.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
