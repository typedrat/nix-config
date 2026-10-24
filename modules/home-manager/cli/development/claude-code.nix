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
  claudeCfg =
    cliCfg.ai.claude-code or {
      context = "";
      rules = {};
      settings = {};
    };

  hasUserSecrets = builtins.pathExists (config.rat.userSecretsDir + "/github.yaml");
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
  inherit (config.programs.claude-code) configDir;
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    rat.userSecrets = lib.mkIf hasUserSecrets {
      github.personalAccessToken = {};
    };

    home.packages = [pkgs.cclogviewer];

    programs.claude-code = {
      enable = true;
      # nixpkgs' claude-code with skrabe's system-prompt + system-
      # reminder overrides applied via tweakcc-fixed at build time.
      # See packages/claude-code-patched.nix.
      package = osConfig.rat.agentSlice.wrap pkgs.claude-code-patched;
      enableMcpIntegration = true;

      settings = lib.mkMerge [
        claudeCfg.settings
        (modules.mkIf config.programs.peon-ping.enable {
          hooks = let
            peon = matcher: async: {
              inherit matcher;
              hooks = [
                ({
                    type = "command";
                    command = "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/peon.sh";
                    timeout = 10;
                  }
                  // lib.optionalAttrs async {inherit async;})
              ];
            };
          in {
            SessionStart = [(peon "" false)];
            SessionEnd = [(peon "" true)];
            SubagentStart = [(peon "" true)];
            SubagentStop = [(peon "" true)];
            UserPromptSubmit = [(peon "" true)];
            Stop = [(peon "" true)];
            Notification = [(peon "" true)];
            PermissionRequest = [(peon "" true)];
            PostToolUseFailure = [(peon "Bash" true)];
            PreCompact = [(peon "" true)];
          };
        })
      ];

      inherit (claudeCfg) context rules;
    };

    # These replace files that predate home-manager owning them. Changes made
    # from Claude Code's UI to the read-only settings.json last one session.
    home.file = lib.mkMerge [
      (modules.mkIf (claudeCfg.settings != {}) {
        "${configDir}/settings.json".force = true;
      })
      (modules.mkIf (claudeCfg.context != "") {
        "${configDir}/CLAUDE.md".force = true;
      })
      (lib.mapAttrs' (name: _: lib.nameValuePair "${configDir}/rules/${name}.md" {force = true;}) claudeCfg.rules)
      (modules.mkIf config.programs.peon-ping.enable {
        ".claude/hooks/peon-ping/peon.sh".source = "${config.programs.peon-ping.package}/share/peon-ping/peon.sh";
      })
    ];

    # Add ~/.local/bin to PATH
    home.sessionPath = [
      "${homeDirectory}/.local/bin"
    ];

    programs.git.ignores = [
      ".claude/settings.local.json"
      "AGENTS.local.md"
      "CLAUDE.local.md"
    ];

    programs.zsh.initContent = lib.mkIf hasUserSecrets (lib.mkBefore ''
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets."github/personalAccessToken".path})
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
