{inputs, ...}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/default.yaml;
    age.sshKeyPaths = ["/home/awilliams/.ssh/id_ed25519"];
  };
}
