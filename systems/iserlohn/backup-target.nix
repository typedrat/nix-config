{
  # Accept syncoid pushes from ulysses. Dedicated key (see secrets syncoid/ssh_key
  # on ulysses); root receives so it can create datasets and zfs recv.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/itwZvaSnkmOFo2tmuitACdrI99heNMc3ZgIS8o85F syncoid@ulysses"
  ];

  # Prune the replicated copies with a longer retention than the source.
  # Snapshots arrive via syncoid (autosnap = false); sanoid only prunes here.
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
    datasets."zfspv-pool/backups/ulysses/persist".useTemplate = ["received"];
    datasets."zfspv-pool/backups/ulysses/hyperion-home".useTemplate = ["received"];
  };
}
