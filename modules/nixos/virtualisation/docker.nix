{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.virtualisation.docker;
in {
  options.rat.virtualisation.docker = {
    enable = options.mkEnableOption "Docker";

    nvidia.enable =
      options.mkEnableOption "NVIDIA GPU support in Docker containers via the NVIDIA Container Toolkit (CDI)";

    dnsServers = options.mkOption {
      type = types.listOf types.str;
      default = ["8.8.8.8" "8.8.4.4"];
      example = ["8.8.8.8" "8.8.4.4"];
      description = "DNS server to configure for the Docker daemon.";
    };
  };

  config = modules.mkIf cfg.enable {
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
          daemon.settings = {
            dns = cfg.dnsServers;
          };
        };
      };
    };

    # CDI-based GPU access. Works with rootless Docker (25.0+): run containers
    # with `docker run --device nvidia.com/gpu=all ...`. The toolkit regenerates
    # the CDI spec at /var/run/cdi on boot.
    hardware.nvidia-container-toolkit.enable = cfg.nvidia.enable;

    security.wrappers = {
      docker-rootlesskit = {
        owner = "root";
        group = "root";
        capabilities = "cap_net_bind_service+ep";
        source = "${pkgs.rootlesskit}/bin/rootlesskit";
      };
    };
  };
}
