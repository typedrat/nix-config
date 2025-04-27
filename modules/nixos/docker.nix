{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
in {
  options.rat.virtualization.docker = {
    enable = mkEnableOption "Docker";

    dnsServers = mkOption {
      type = types.listOf types.str;
      default = ["8.8.8.8" "8.8.4.4"];
      example = ["8.8.8.8" "8.8.4.4"];
      description = "DNS server to configure for the Docker daemon.";
    };
  };

  config = mkIf config.rat.virtualization.docker.enable {
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
            dns = config.rat.virtualization.docker.dnsServers;
          };
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
  };
}
