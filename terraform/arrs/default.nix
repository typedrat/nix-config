{
  imports = [
    ./lidarr.nix
    ./providers.nix
    ./prowlarr.nix
    ./radarr.nix
    ./sonarr.nix
  ];

  data.sops_file.arrs = {
    source_file = "../secrets/arrs.yaml";
  };
}
