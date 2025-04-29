{
  config,
  pkgs,
  lib,
  ...
}: {
  sops.secrets = {
    miseGithubToken = {};
    openrouterApiKey = {};
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

    initContent = lib.mkBefore ''
      source ~/.p10k.zsh
      export MISE_GITHUB_TOKEN=$(cat ${config.sops.secrets.miseGithubToken.path})
      export OPENROUTER_API_KEY=$(cat ${config.sops.secrets.openrouterApiKey.path})
      export OPENAI_API_KEY=$OPENROUTER_API_KEY
      export OPENAI_BASE_URL="https://openrouter.ai/api/v1"
    '';

    history.size = 10000;
  };

  home.file.".p10k.zsh".source = ./p10k.zsh;
}
