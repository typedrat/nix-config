{
  config,
  inputs,
  inputs',
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    alejandra
    corepack
    devpod
    elan
    gcc
    google-cloud-sdk
    inputs'.catppuccin.packages.whiskers
    inputs'.fenix.packages.stable.defaultToolchain
    nixd
    nodejs
    process-compose
    (python3.withPackages (ps:
      with ps; [
        ipython
        matplotlib
        numpy
        pandas
        polars
        pynput
        scipy
        seaborn
        sympy
      ]))
    uv

    # kubernetes stuff
    kubectl
    kubernetes-helm
    fluxcd
    cilium-cli
    istioctl
    opentofu
    inputs'.talhelper.packages.default
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
        disable_tools = ["node" "rust"];
        idiomatic_version_file_enable_tools = [];
      };
    };
  };

  xdg.configFile."process-compose/theme.yaml".source = "${inputs.catppuccin-process-compose}/themes/catppuccin-${config.catppuccin.flavor}.yaml";
}
