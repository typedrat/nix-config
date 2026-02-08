{
  imports = [
    ./providers.nix
    ./webhooks.nix
  ];

  data.sops_file.github = {
    source_file = "../secrets/github.yaml";
  };

  data.sops_file.deploy = {
    source_file = "../secrets/deploy.yaml";
  };
}
