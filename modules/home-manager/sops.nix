{
  config,
  osConfig,
  inputs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/default.yaml;
    age.sshKeyPaths = ["${config.home.homeDirectory}/.ssh/id_ed25519"];
  };

  home.persistence.${persistDir} = mkIf impermanenceCfg.enable {
    directories = [".config/sops" ".config/sops-nix"];
  };
}
