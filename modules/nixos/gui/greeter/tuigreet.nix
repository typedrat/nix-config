{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatStringsSep;
  cfg = config.rat.gui;
  impermanenceCfg = config.rat.impermanence;
in {
  config = mkMerge [
    (mkIf (cfg.enable && cfg.greeter.variant == "tuigreet") {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            # NOTE: keep this on a single line (no embedded newlines). The
            # nixpkgs TOML generator serializes any string containing newlines
            # as a triple-quoted literal (''' ... '''), which greetd 0.10.3's
            # bundled TOML parser cannot read ("expected equals sign on line,
            # but found none"), leaving you with a black screen after Plymouth.
            # concatStringsSep " " produces a single-line basic string.
            command = let
              dmcfg = config.services.displayManager;
            in
              concatStringsSep " " [
                "${pkgs.tuigreet}/bin/tuigreet"
                "--debug"
                "--time"
                "--asterisks"
                "--remember-session"
                "--user-menu"
                "--theme 'text=white;container=black;border=magenta;greet=magenta;input=red;action=magenta;button=white'"
                "--power-shutdown '/run/current-system/systemd/bin/systemctl poweroff'"
                "--power-reboot '/run/current-system/systemd/bin/systemctl reboot'"
                "--sessions '${dmcfg.sessionData.desktops}/share/wayland-sessions'"
                "--session-wrapper '${pkgs.writeShellScript "quiet-session" "exec \"$@\" &>/dev/null"}'"
              ];
            user = "greeter";
          };
        };
      };

      systemd.services.greetd.serviceConfig = {
        Type = "idle";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "journal";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
      };

      systemd.tmpfiles.settings.tuigreet."/var/cache/tuigreet".d = {
        user = "greeter";
        group = "greeter";
        mode = "0755";
      };
    })
    (mkIf (cfg.enable && cfg.greeter.variant == "tuigreet" && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = ["/var/cache/tuigreet"];
      };
    })
  ];
}
