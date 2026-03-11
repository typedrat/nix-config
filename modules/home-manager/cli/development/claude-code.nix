{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules getExe;
  inherit (config.home) username homeDirectory;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};

  hasUserSecrets = username == "awilliams";
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    sops.secrets = lib.mkIf hasUserSecrets {
      githubPersonalAccessToken = {};
    };

    home.packages = with pkgs; [
      claude-code-bin
      cclogviewer
      happy-coder
    ];

    # Add ~/.local/bin to PATH
    home.sessionPath = [
      "${homeDirectory}/.local/bin"
    ];

    programs.git.ignores = [
      ".claude/settings.local.json"
      "CLAUDE.local.md"
    ];
    home.file = {
      # Symlink claude-code to ~/.local/bin to shut up the native install check
      ".local/bin/claude".source = getExe pkgs.claude-code-bin;
    };

    programs.zsh.initContent = lib.mkIf hasUserSecrets (lib.mkBefore ''
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.githubPersonalAccessToken.path})
    '');

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".claude"
        ".config/codebook"
        ".local/share/codebook"
      ];
      files = [".claude.json"];
    };
  };
}
