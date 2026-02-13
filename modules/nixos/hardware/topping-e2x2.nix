{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.rat.hardware.topping-e2x2;
in {
  options.rat.hardware.topping-e2x2.enable = mkEnableOption "Topping Professional E2x2 USB audio interface";

  config = mkIf cfg.enable {
    # Force 192kHz sample rate for the Topping E2x2 OTG (152a:8756)
    boot.extraModprobeConfig = ''
      options snd_usb_audio vid=0x152a pid=0x8756 rate=192000
    '';

    # PipeWire loopback modules to expose individual inputs/outputs as separate devices
    services.pipewire.extraConfig.pipewire."50-topping-e2x2" = {
      "context.modules" = [
        # XLR/Aux Input 1 (mono)
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Topping E2x2 IN1";
            "capture.props" = {
              "node.name" = "capture.E2x2_IN1";
              "audio.position" = ["AUX0"];
              "stream.dont-remix" = true;
              "target.object" = "alsa_input.usb-Topping_E2x2_OTG-00.pro-input-0";
              "node.passive" = true;
            };
            "playback.props" = {
              "node.name" = "E2x2_IN1";
              "media.class" = "Audio/Source";
              "audio.position" = ["MONO"];
            };
          };
        }
        # XLR/Aux Input 2 (mono)
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Topping E2x2 IN2";
            "capture.props" = {
              "node.name" = "capture.E2x2_IN2";
              "audio.position" = ["AUX1"];
              "stream.dont-remix" = true;
              "target.object" = "alsa_input.usb-Topping_E2x2_OTG-00.pro-input-0";
              "node.passive" = true;
            };
            "playback.props" = {
              "node.name" = "E2x2_IN2";
              "media.class" = "Audio/Source";
              "audio.position" = ["MONO"];
            };
          };
        }
        # Headphone output (stereo)
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Topping E2x2 Headphone";
            "capture.props" = {
              "node.name" = "E2x2_Headphone";
              "media.class" = "Audio/Sink";
              "audio.position" = ["FL" "FR"];
            };
            "playback.props" = {
              "node.name" = "playback.E2x2_Headphone";
              "audio.position" = ["AUX0" "AUX1"];
              "target.object" = "alsa_output.usb-Topping_E2x2_OTG-00.pro-output-0";
              "stream.dont-remix" = true;
              "node.passive" = true;
            };
          };
        }
      ];
    };
  };
}
