{pkgs, ...}: {
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

    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };

  security.wrappers = {
    docker-rootlesskit = {
      owner = "root";
      group = "root";
      capabilities = "cap_net_bind_service+ep";
      source = "${pkgs.rootlesskit}/bin/rootlesskit";
    };
  };

  fileSystems."/var/lib/containers" = {
    device = "zpool/containers";
    fsType = "zfs";
    options = ["zfsutil" "X-mount.mkdir"];
  };
}
