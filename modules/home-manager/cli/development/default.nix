{
  config,
  osConfig,
  inputs,
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
  imports = [
    ./claude-code.nix
    ./cloud.nix
    ./git-spice.nix
    ./languages.nix
    ./nix-tools.nix
  ];

  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    home.packages = with pkgs; [
      # Compilers and build tools
      gcc

      # Development utilities
      devpod
      process-compose
      tokei
      rainfrog
      uv

      # VCS and GitHub
      github-to-sops

      # Docker tools
      dive
      docker-buildx
      docker-compose
      fuse-overlayfs
      lazydocker
      passt
    ];

    # GitHub CLI
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };

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

    xdg.userDirs.extraConfig.XDG_DEVELOPMENT_DIR = "$HOME/Development";

    # process-compose theme
    xdg.configFile."process-compose/theme.yaml".source = "${inputs.catppuccin-process-compose}/themes/catppuccin-${config.catppuccin.flavor}.yaml";

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".config/gh"
        ".local/share/gh"
        ".local/state/gh"
        ".config/mise"
        ".local/state/mise"
        ".config/docker"
        ".local/share/docker"
        "Development"
      ];
    };
  };
}
