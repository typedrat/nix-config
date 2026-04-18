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

  # Check if user has specific secrets configured (awilliams-specific)
  hasUserSecrets = username == "awilliams";
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.shell.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/state/zsh"
        ".zsh"
      ];
    };
    sops.secrets = lib.mkIf hasUserSecrets {
      miseGithubToken = {};
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
      ];

      initContent = lib.mkBefore (
        ''
          source ~/.p10k.zsh
          bindkey "^[[1;5C" forward-word
          bindkey "^[[1;5D" backward-word

          # Auto-add node_modules/.bin to PATH based on current directory
          autoload -Uz add-zsh-hook
          _node_bins_update() {
            # Strip previously-added node_modules/.bin entries
            local clean_path=("''${(@)path:#*/node_modules/.bin}")
            local bins=()
            local dir="$PWD"
            while [[ "$dir" != "/" ]]; do
              [[ -d "$dir/node_modules/.bin" ]] && bins+=("$dir/node_modules/.bin")
              dir="''${dir:h}"
            done
            path=("''${bins[@]}" "''${clean_path[@]}")
          }
          add-zsh-hook chpwd _node_bins_update
          _node_bins_update  # run once for initial directory
        ''
        + lib.optionalString hasUserSecrets ''
          export MISE_GITHUB_TOKEN=$(cat ${config.sops.secrets.miseGithubToken.path})
        ''
      );

      history.size = 10000;
    };

    home.file.".p10k.zsh".source = ./p10k.zsh;
  };
}
