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
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.development.enable or false)) {
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
