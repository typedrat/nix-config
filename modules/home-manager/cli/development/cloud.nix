{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.development.enable or false)) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.enable {
      directories = [
        {
          directory = ".aws";
          mode = "0700";
        }
        {
          directory = ".kube";
          mode = "0700";
        }
        ".config/gcloud"
        ".config/terraform"
      ];
    };
    home.packages = with pkgs; [
      # Cloud platforms
      google-cloud-sdk
      aws-vault
      awscli2
      ssm-session-manager-plugin

      # Kubernetes tools
      kubectl
      kubernetes-helm
      fluxcd
      cilium-cli
      istioctl

      # Infrastructure as Code
      opentofu
    ];
  };
}
