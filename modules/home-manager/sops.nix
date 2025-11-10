{
  config,
  inputs,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/default.yaml;
    age.sshKeyPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
  };
}
