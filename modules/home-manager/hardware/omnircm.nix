{
  osConfig,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf osConfig.rat.hardware.omnircm.enable {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [
        # settings and downloaded payloads
        ".config/omnircm"
        ".local/share/OmniRCM"
      ];
    };

    # Auto-inject only happens while the app is running. Its own "launch on
    # boot" toggle writes an autostart entry pointing at the store path it
    # was started from, which goes stale on the next rebuild; this unit
    # doesn't, and the app's single-instance lock keeps the two from
    # doubling up.
    systemd.user.services.omnircm = {
      Unit = {
        Description = "OmniRCM Nintendo Switch payload injector";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };

      Service = {
        ExecStart = "${lib.getExe pkgs.omnircm} --minimized";
        Restart = "on-failure";
      };

      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
