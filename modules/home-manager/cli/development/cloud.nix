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
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        {
          directory = ".aws";
          mode = "0700";
        }
        {
          directory = ".kube";
          mode = "0700";
        }
        ".config/granted"
        ".cloudflared"
        ".config/gcloud"
        ".config/terraform"
        ".cache/terraform/plugins"
      ];
    };
    home.packages = with pkgs; [
      # Cloud platforms
      google-cloud-sdk
      aws-vault
      ssm-session-manager-plugin

      # Kubernetes tools
      kubectl
      kubectl-cnpg
      kubernetes-helm
      cilium-cli

      # Infrastructure as Code
      opentofu
    ];

    programs.awscli.enable = true;

    programs.kubecolor = {
      enable = true;
      enableAlias = true;
    };

    programs.granted.enable = true;
  };
}
