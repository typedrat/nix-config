{
  virtualisation = {
    containers = true;

    podman = {
      enable = true;
      dockerCompat = true;

      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
