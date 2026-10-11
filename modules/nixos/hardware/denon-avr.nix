# Hands the volume of the HDMI output wired to a Denon AVR over to the
# receiver: PipeWire's slider drives the receiver's master volume over its
# network control protocol, and changes made on the receiver itself show up in
# PipeWire. The upstream module swaps the system PipeWire and WirePlumber for
# builds patched with external volume control support.
{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.hardware.denon-avr;
in {
  imports = [inputs.denon-pipewire-audio-control.nixosModules.default];

  options.rat.hardware.denon-avr = {
    enable = options.mkEnableOption "Denon AVR volume control for the HDMI audio output";

    alsaDevice = options.mkOption {
      type = types.str;
      description = "PipeWire device name of the card wired to the receiver (see `pw-cli ls Device`).";
      example = "alsa_card.pci-0000_01_00.1";
    };

    pcInput = options.mkOption {
      type = types.str;
      description = "Receiver input the PC is plugged into, as the receiver names it.";
      example = "BD";
    };
  };

  config = modules.mkIf cfg.enable {
    services.denon-volume = {
      enable = true;
      inherit (cfg) alsaDevice pcInput;
    };
  };
}
