{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  cfg = config.rat.sops;
  sshCfg = config.rat.ssh;
in {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  options.rat.sops = {
    enable = mkEnableOption "SOPS support" // {default = true;};
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = sshCfg.enable;
        message = "SOPS requires SSH to be enabled.";
      }
    ];

    environment.systemPackages = with pkgs; [
      sops
    ];

    sops = {
      defaultSopsFile = ../../secrets/default.yaml;
      age.sshKeyPaths = builtins.map (x: x.path) (
        builtins.filter (x: x.type == "ed25519") config.services.openssh.hostKeys
      );

      secrets = {
        "users/awilliams/hashedPassword" = {
          neededForUsers = true;
        };
        "users/root/hashedPassword" = {
          neededForUsers = true;
        };
      };
    };
  };
}
