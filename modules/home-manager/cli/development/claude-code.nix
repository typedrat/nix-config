{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
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
      claude-code
      cclogviewer
    ];

    # Add ~/.local/bin to PATH
    home.sessionPath = [
      "${homeDirectory}/.local/bin"
    ];

    home.sessionVariables = {
      "CLAUDE_CODE_NO_FLICKER" = 1;
    };

    programs.git.ignores = [
      ".claude/settings.local.json"
      "AGENTS.local.md"
      "CLAUDE.local.md"
    ];

    programs.zsh.initContent = lib.mkIf hasUserSecrets (lib.mkBefore ''
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.githubPersonalAccessToken.path})
    '');

    home.file.".claude/hooks/peon-ping/peon.sh" = modules.mkIf config.programs.peon-ping.enable {
      source = "${config.programs.peon-ping.package}/share/peon-ping/peon.sh";
    };

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
