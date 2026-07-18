{
  config,
  ...
}: {
  # The tank pool is managed manually (created once, out of band) rather than by
  # disko: nixos-rebuild only ever mounts it, never recreates it, so the reserved
  # free space on the same disk (for a later Windows install) stays safe.
  #
  # /tank backs an impermanence persistence root, and impermanence requires every
  # persistence filesystem to be neededForBoot — i.e. mounted in the initrd. The
  # pool's key lives on the (already initrd-mounted) /persist, so we import the
  # pool and load its key in the initrd, before the /tank mount, mirroring how the
  # root pool is unlocked. `nofail` keeps a tank problem from blocking boot: worst
  # case the system comes up without /tank rather than hanging.
  fileSystems."/tank" = {
    device = "tank";
    fsType = "zfs";
    neededForBoot = true;
    options = ["zfsutil" "nofail"];
  };

  boot.initrd.systemd.services.zfs-load-key-tank = {
    description = "Load the tank pool key from /persist (initrd)";
    requiredBy = ["sysroot-tank.mount"];
    before = ["sysroot-tank.mount"];
    after = ["zfs-import-tank.service" "sysroot-persist.mount"];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # zfs is copied into the initrd and put on PATH via `path`. In the initrd
    # /persist is mounted at /sysroot/persist, so the on-pool keylocation
    # (file:///persist/...) doesn't resolve yet — point at the initrd path.
    path = [config.rat.zfs.package];
    script = ''
      zfs load-key -L file:///sysroot/persist/.tank.key tank
    '';
  };

  rat.impermanence.tank.enable = true;
}
