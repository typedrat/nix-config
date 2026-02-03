{
  config,
  osConfig,
  self',
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  imports = [
    ./cloud.nix
    ./git-spice.nix
    ./languages.nix
    ./nix-tools.nix
  ];

  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.development.enable or false)) {
    home.packages = with pkgs; [
      # Compilers and build tools
      gcc

      # Development utilities
      devpod
      process-compose
      rainfrog
      uv

      # AI/Editor tools
      claude-code-bin
      self'.packages.cclogviewer
      self'.packages.claude-powerline

      # VCS and GitHub
      github-cli
      github-to-sops

      # Docker tools
      dive
      docker-buildx
      docker-compose
      fuse-overlayfs
      lazydocker
      passt
    ];

    # mise - polyglot runtime manager
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

    # process-compose theme
    xdg.configFile."process-compose/theme.yaml".source = "${inputs.catppuccin-process-compose}/themes/catppuccin-${config.catppuccin.flavor}.yaml";
  };
}
