{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  cfg = config.rat.backup;
  target = "root@iserlohn";
  targetBase = "zfspv-pool/backups/ulysses";
in {
  options.rat.backup.enable = mkEnableOption "sanoid snapshots + syncoid replication to iserlohn";

  config = mkIf cfg.enable {
    # Snapshot the irreplaceable datasets; tank and local/* are excluded.
    services.sanoid = {
      enable = true;
      templates.irreplaceable = {
        hourly = 24;
        daily = 30;
        monthly = 3;
        autosnap = true;
        autoprune = true;
      };
      datasets."zpool/safe/persist".useTemplate = ["irreplaceable"];
      datasets."zpool/safe/hyperion-home".useTemplate = ["irreplaceable"];
    };

    # Push those snapshots to iserlohn. --no-sync-snap: replicate sanoid's
    # snapshots rather than taking syncoid's own. accept-new avoids a first-run
    # host-key failure (the syncoid user has no prior known_hosts for iserlohn).
    services.syncoid = {
      enable = true;
      interval = "*-*-* *:15:00"; # hourly at :15, after sanoid's hourly snap
      sshKey = config.sops.secrets."syncoid/ssh_key".path;
      commonArgs = ["--no-sync-snap" "--sshoption=StrictHostKeyChecking=accept-new"];
      commands."persist" = {
        source = "zpool/safe/persist";
        target = "${target}:${targetBase}/persist";
      };
      commands."hyperion-home" = {
        source = "zpool/safe/hyperion-home";
        target = "${target}:${targetBase}/hyperion-home";
      };
    };

    # syncoid's SSH key must be readable by the syncoid service user.
    sops.secrets."syncoid/ssh_key".owner = config.services.syncoid.user;
  };
}
