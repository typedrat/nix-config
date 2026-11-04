{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types;

  cfg = config.rat.hardware.cec;
in {
  options.rat.hardware.cec = {
    enable = mkEnableOption "HDMI-CEC through the kernel CEC framework (/dev/cec*)";

    osdName = mkOption {
      type = types.strMatching ".{1,14}";
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Name the TV shows for this machine. CEC caps it at 14 characters.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.v4l-utils];

    # A kernel CEC adapter does nothing on the bus until it is given a logical
    # address. Claiming one as a playback device makes the TV list this
    # machine as a source, and with RC passthrough the kernel turns remote
    # presses into key events on an input device. DP-to-HDMI adapters
    # re-register their CEC device on every replug, so this runs per device
    # rather than once at boot.
    #
    # uaccess only takes effect when set before 73-seat-late.rules, which is
    # why these can't live in extraRules (99-local.rules).
    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/70-cec.rules" ''
        SUBSYSTEM=="cec", KERNEL=="cec[0-9]*", TAG+="uaccess"
        ACTION=="add", SUBSYSTEM=="cec", KERNEL=="cec[0-9]*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cec-configure@%k.service"
      '')
    ];

    systemd.services."cec-configure@" = {
      description = "Configure HDMI-CEC adapter %I as a playback device";
      bindsTo = ["dev-%i.device"];
      after = ["dev-%i.device"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.v4l-utils}/bin/cec-ctl --device /dev/%I --playback --osd-name ${lib.escapeShellArg cfg.osdName}";
      };
    };
  };
}
