{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types;
  cfg = config.rat.backup;

  host = config.networking.hostName;
  # Per-host so more hosts can push to the same target as this grows: each host
  # has its own key (syncoid/<host>/ssh_key) and its own backups/<host>/ subtree.
  keyPath = "syncoid/${host}/ssh_key";
  # Unprivileged, zfs-allow-scoped receiver on iserlohn (not root).
  targetHost = "syncoid@iserlohn";
  targetBase = "zfspv-pool/backups/${host}";

  shortName = dataset: lib.last (lib.splitString "/" dataset);
in {
  options.rat.backup = {
    enable = mkEnableOption "sanoid snapshots + syncoid replication to iserlohn";

    datasets = mkOption {
      type = types.listOf types.str;
      default = ["zpool/safe/persist"];
      description = "Source datasets to snapshot and replicate to iserlohn.";
    };
  };

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
      datasets = lib.genAttrs cfg.datasets (_: {useTemplate = ["irreplaceable"];});
    };

    # Push those snapshots to iserlohn. --no-sync-snap: replicate sanoid's
    # snapshots rather than taking syncoid's own. accept-new avoids a first-run
    # host-key failure (the syncoid user has no prior known_hosts for iserlohn).
    services.syncoid = {
      enable = true;
      interval = "*-*-* *:15:00"; # hourly at :15, after sanoid's hourly snap
      sshKey = config.sops.secrets.${keyPath}.path;
      commonArgs = ["--no-sync-snap" "--sshoption=StrictHostKeyChecking=accept-new"];
      commands = lib.listToAttrs (map (dataset:
        lib.nameValuePair (shortName dataset) {
          source = dataset;
          target = "${targetHost}:${targetBase}/${shortName dataset}";
          # Raw send: iserlohn stores the already-encrypted blocks and can never
          # read the backup (zfspv-pool itself is unencrypted). recv -u so the
          # keyless received dataset is never mounted on the target.
          sendOptions = "w";
          recvOptions = "u";
        })
      cfg.datasets);
    };

    # syncoid's SSH key must be readable by the syncoid service user.
    sops.secrets.${keyPath}.owner = config.services.syncoid.user;
  };
}
