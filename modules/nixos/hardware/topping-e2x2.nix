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
    # PipeWire loopback modules to expose individual inputs/outputs as separate devices.
    # The E2x2 uses the analog-surround-21 profile by default, which exposes 3 channels:
    # FL (IN1), FR (IN2), LFE (unused for capture). These loopbacks split the two
    # physical inputs into individual mono source nodes.
    services.pipewire.extraConfig.pipewire."50-topping-e2x2" = {
      "context.modules" = [
        # XLR/Aux Input 1 (mono) - captures from FL channel
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Topping E2x2 IN1";
            "capture.props" = {
              "node.name" = "capture.E2x2_IN1";
              "audio.position" = ["FL"];
              "stream.dont-remix" = true;
              "target.object" = "alsa_input.usb-Topping_E2x2-00.analog-surround-21";
            };
            "playback.props" = {
              "node.name" = "E2x2_IN1";
              "media.class" = "Audio/Source";
              "audio.position" = ["MONO"];
            };
          };
        }
        # XLR/Aux Input 2 (mono) - captures from FR channel
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Topping E2x2 IN2";
            "capture.props" = {
              "node.name" = "capture.E2x2_IN2";
              "audio.position" = ["FR"];
              "stream.dont-remix" = true;
              "target.object" = "alsa_input.usb-Topping_E2x2-00.analog-surround-21";
            };
            "playback.props" = {
              "node.name" = "E2x2_IN2";
              "media.class" = "Audio/Source";
              "audio.position" = ["MONO"];
            };
          };
        }
        # Headphone output (stereo) - plays to FL/FR channels
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
              "audio.position" = ["FL" "FR"];
              "target.object" = "alsa_output.usb-Topping_E2x2-00.analog-surround-21";
              "stream.dont-remix" = true;
            };
          };
        }
      ];
    };
  };
}
