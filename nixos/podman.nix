{
  virtualisation = {
    containers = {
      enable = true;
      registries.search = [
        "docker.io"
        "quay.io"
        "ghcr.io"
      ];

      storage.settings = {
        storage = rec {
          runroot = "/var/lib/containers";
          graphroot = "${runroot}/storage";
          driver = "zfs";
        };
      };
    };

    podman = {
      enable = true;
      autoPrune.enable = true;
      dockerCompat = true;

      defaultNetwork.settings.dns_enabled = true;
    };

    waydroid.enable = true;
  };

  fileSystems."/var/lib/containers" = {
    device = "zpool/containers";
    fsType = "zfs";
    options = ["zfsutil" "X-mount.mkdir"];
  };
}
