{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types;

  cfg = config.rat.hardware.nintendoSwitch.rcm;
in {
  options.rat.hardware.nintendoSwitch.rcm = {
    enable = mkEnableOption "automatic hekate RCM payload injection for Nintendo Switch";

    payload = mkOption {
      type = types.path;
      default = "${pkgs.hekate-payload}/share/hekate/hekate_ctcaer.bin";
      defaultText = lib.literalExpression ''"''${pkgs.hekate-payload}/share/hekate/hekate_ctcaer.bin"'';
      description = "Path to the RCM payload (.bin) sent when a Switch is detected in RCM mode.";
    };

    # Consumed by switch-rcm-inject.service (added in a later commit), not in
    # this module's config block.
    notify = mkOption {
      type = types.bool;
      default = true;
      description = "Broadcast a desktop notification to active graphical sessions on injection success/failure.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.fusee-nano];

    # Tag the Switch RCM device (APX mode, 0955:7321) and have systemd start
    # the injection service when it appears.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0955", ATTRS{idProduct}=="7321", TAG+="systemd", ENV{SYSTEMD_WANTS}="switch-rcm-inject.service"
    '';
  };
}
