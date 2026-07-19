{
  config,
  pkgs,
  ...
}: let
  # Per-source-host subtree; delegate scoped perms so the key can only receive
  # backups here, never root. Grows by adding a user + subtree per source host.
  targetParent = "zfspv-pool/backups/ulysses";
  allowPerms = "change-key,compression,create,destroy,hold,mount,mountpoint,receive,release,rollback,bookmark";
  zfs = "${config.boot.zfs.package}/bin/zfs";
in {
  # Unprivileged receiver for ulysses's syncoid pushes (dedicated key; see
  # secrets syncoid/ulysses/ssh_key on ulysses).
  users.users.syncoid = {
    description = "syncoid backup receiver";
    isSystemUser = true;
    group = "syncoid";
    home = "/var/lib/syncoid";
    createHome = true;
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/itwZvaSnkmOFo2tmuitACdrI99heNMc3ZgIS8o85F syncoid@ulysses"
    ];
  };
  users.groups.syncoid = {};

  # syncoid's transport helpers, found on the syncoid user's SSH-command PATH.
  environment.systemPackages = [pkgs.mbuffer pkgs.lzop];

  # Create the per-host subtree (root-owned) and delegate scoped zfs permissions
  # to the syncoid user, so its SSH key can only receive into this subtree.
  systemd.services.syncoid-target-delegate = {
    description = "Prepare ${targetParent} and delegate zfs perms to syncoid";
    wantedBy = ["multi-user.target"];
    after = ["zfs-import.target" "zfs-mount.service"];
    path = [config.boot.zfs.package];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${zfs} list -H -o name ${targetParent} >/dev/null 2>&1 \
        || ${zfs} create -p -o mountpoint=none ${targetParent}
      ${zfs} allow -u syncoid ${allowPerms} ${targetParent}
    '';
  };

  # Prune the replicated (raw, keyless) copies with a longer retention than the
  # source. Snapshots arrive via syncoid (autosnap = false); sanoid only prunes.
  services.sanoid = {
    enable = true;
    templates.received = {
      hourly = 0;
      daily = 30;
      monthly = 6;
      yearly = 1;
      autosnap = false;
      autoprune = true;
    };
    datasets."${targetParent}/persist".useTemplate = ["received"];
    datasets."${targetParent}/hyperion-home".useTemplate = ["received"];
  };
}
