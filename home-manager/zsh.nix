{
  pkgs,
  config,
  ...
}: {
  sops.secrets."miseGithubToken" = {};

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

    initExtraFirst = ''
      source ~/.p10k.zsh
      export MISE_GITHUB_TOKEN=$(cat ${config.sops.secrets.miseGithubToken.path})
    '';

    history.size = 10000;
  };
}
