{
  imports = [
    ./providers.nix
    ./tunnel.nix
    ./dns.nix
  ];

  data.sops_file.cloudflare = {
    source_file = "../secrets/cloudflare.yaml";
  };

  data.sops_file.deploy = {
    source_file = "../secrets/deploy.yaml";
  };
}
