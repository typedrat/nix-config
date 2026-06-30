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

  # Broadcasts a notification to every active wayland/x11 session.
  # Usage: switch-rcm-notify <urgency> <summary> <body>
  notifyBroadcast = pkgs.writeShellApplication {
    name = "switch-rcm-notify";
    runtimeInputs = [pkgs.systemd pkgs.libnotify pkgs.coreutils pkgs.gawk pkgs.util-linux];
    text = ''
      urgency="$1"
      summary="$2"
      body="$3"

      # Enumerate session IDs, keep graphical + active ones, notify each user.
      loginctl list-sessions --no-legend | awk '{print $1}' | while read -r sid; do
        [ -n "$sid" ] || continue
        stype="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)"
        sstate="$(loginctl show-session "$sid" -p State --value 2>/dev/null || true)"
        suid="$(loginctl show-session "$sid" -p User --value 2>/dev/null || true)"
        suser="$(loginctl show-session "$sid" -p Name --value 2>/dev/null || true)"

        case "$stype" in
          wayland|x11) ;;
          *) continue ;;
        esac
        [ "$sstate" = "active" ] || continue
        [ -n "$suid" ] || continue
        [ -n "$suser" ] || continue
        [ -S "/run/user/$suid/bus" ] || continue

        runuser -u "$suser" -- \
          env "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$suid/bus" \
          notify-send --app-name="Switch RCM" --urgency="$urgency" "$summary" "$body" \
          || true
      done || true
    '';
  };
in {
  options.rat.hardware.nintendoSwitch.rcm = {
    enable = mkEnableOption "automatic hekate RCM payload injection for Nintendo Switch";

    payload = mkOption {
      type = types.path;
      default = "${pkgs.hekate-payload}/share/hekate/hekate_ctcaer.bin";
      defaultText = lib.literalExpression ''"''${pkgs.hekate-payload}/share/hekate/hekate_ctcaer.bin"'';
      description = "Path to the RCM payload (.bin) sent when a Switch is detected in RCM mode.";
    };

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
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0955", ATTRS{idProduct}=="7321", GROUP="games"
    '';

    systemd.services.switch-rcm-inject = {
      description = "Inject hekate RCM payload into Nintendo Switch";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.fusee-nano} ${cfg.payload}";
        # ExecStartPost runs only after a successful ExecStart (success path).
        # The leading "-" makes the notification best-effort: a failed
        # notification can never flip the injection itself to a failed state
        # (which would spuriously fire onFailure below).
        ExecStartPost = mkIf cfg.notify [
          ''-${lib.getExe notifyBroadcast} normal "Nintendo Switch" "hekate payload sent successfully."''
        ];
      };

      onFailure = mkIf cfg.notify ["switch-rcm-notify-fail.service"];
    };

    systemd.services.switch-rcm-notify-fail = mkIf cfg.notify {
      description = "Notify that Nintendo Switch RCM injection failed";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${lib.getExe notifyBroadcast} critical "Nintendo Switch" "hekate payload injection FAILED. Check: journalctl -u switch-rcm-inject"'';
      };
    };
  };
}
