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

  hasUserSecrets = builtins.pathExists (config.rat.userSecretsDir + "/github.yaml");
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    rat.userSecrets = lib.mkIf hasUserSecrets {
      github.personalAccessToken = {};
    };

    home.packages = with pkgs; [
      # nixpkgs' claude-code with skrabe's system-prompt + system-
      # reminder overrides applied via tweakcc-fixed at build time.
      # See packages/claude-code-patched.nix.
      (osConfig.rat.agentSlice.wrap claude-code-patched)
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

    # nixpkgs' claude-code wrapper prefixes LD_LIBRARY_PATH with alsa-lib so
    # voice mode can dlopen libasound, and every process Claude spawns inherits
    # it. LD_LIBRARY_PATH beats rpath, so a project's binaries built from an
    # older nixpkgs (a devshell's ffmpeg or Chromium) load this newer libasound
    # and die on a missing GLIBC_2.xx symbol. Claude keeps the entry; its
    # shells drop it. envExtra, not initContent: tool shells are `zsh -c`.
    programs.zsh.envExtra = ''
      if [[ -n $CLAUDECODE && -n $LD_LIBRARY_PATH ]]; then
        () {
          local -a parts=("''${(@s/:/)LD_LIBRARY_PATH}")
          parts=("''${(@)parts:#/nix/store/*-alsa-lib-*/lib}")
          if (( $#parts )); then export LD_LIBRARY_PATH="''${(j/:/)parts}"; else unset LD_LIBRARY_PATH; fi
        }
      fi
    '';

    programs.zsh.initContent = lib.mkIf hasUserSecrets (lib.mkBefore ''
      export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets."github/personalAccessToken".path})
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
