{
  virtualisation = {
    containers = {
      enable = true;
      registries.search = [
        "docker.io"
        "quay.io"
        "ghcr.io"
      ];
    };

    podman = {
      enable = true;
      autoPrune.enable = true;
      dockerCompat = true;

      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
