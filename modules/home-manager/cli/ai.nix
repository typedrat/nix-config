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
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.ai.enable or false)) {
    sops.secrets = lib.mkIf hasUserSecrets {
      civitaiApiToken = {};
      hfToken = {};
      openrouterApiKey = {};
    };

    home.packages = with pkgs; [
      llm
      python3Packages.huggingface-hub
    ];

    home.sessionVariables = {
      HF_HUB_ENABLE_HF_TRANSFER = "1";
    };

    programs.zsh.initContent = lib.mkIf hasUserSecrets (lib.mkBefore ''
      export CIVITAI_API_TOKEN=$(cat ${config.sops.secrets.civitaiApiToken.path})
      export HF_TOKEN=$(cat ${config.sops.secrets.hfToken.path})
      export OPENROUTER_API_KEY=$(cat ${config.sops.secrets.openrouterApiKey.path})
    '');
  };
}
