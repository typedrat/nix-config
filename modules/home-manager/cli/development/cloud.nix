{
  config,
  osConfig,
  inputs',
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

      # Kubernetes tools
      kubectl
      kubernetes-helm
      fluxcd
      cilium-cli
      istioctl
      inputs'.talhelper.packages.default

      # Infrastructure as Code
      opentofu
    ];
  };
}
