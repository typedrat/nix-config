{
  config,
  inputs,
  inputs',
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    alejandra
    nixd
    uv
    nodejs
    corepack
    process-compose
    inputs'.catppuccin.packages.whiskers
    inputs'.fenix.packages.stable.defaultToolchain

    # kubernetes stuff
    kubectl
    kubernetes-helm
    fluxcd
    cilium-cli
    istioctl
    opentofu
  ];

  programs.mise = {
    enable = true;
    enableZshIntegration = true;

    globalConfig = {
      tools = {
        hk = "latest";
      };

      settings = {
        experimental = true;
        disable_tools = ["node"];
      };
    };
  };

  xdg.configFile."process-compose/theme.yaml".source = "${inputs.catppuccin-process-compose}/themes/catppuccin-${config.catppuccin.flavor}.yaml";
}
