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
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.shell.enable or false)) {
    sops.secrets = lib.mkIf hasUserSecrets {
      miseGithubToken = {};
      openrouterApiKey = {};
      vizioAuth = {};
      vizioIp = {};
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

      initContent = lib.mkBefore (''
          source ~/.p10k.zsh
          bindkey "^[[1;5C" forward-word
          bindkey "^[[1;5D" backward-word
        ''
        + lib.optionalString hasUserSecrets ''
          export MISE_GITHUB_TOKEN=$(cat ${config.sops.secrets.miseGithubToken.path})
          export OPENROUTER_API_KEY=$(cat ${config.sops.secrets.openrouterApiKey.path})
          export VIZO_IP=$(cat ${config.sops.secrets.vizioIp.path})
          export VIZIO_AUTH=$(cat ${config.sops.secrets.vizioAuth.path})
        '');

      history.size = 10000;
    };

    home.file.".p10k.zsh".source = ./p10k.zsh;
  };
}
