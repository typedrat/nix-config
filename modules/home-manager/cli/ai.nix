{
  config,
  osConfig,
  inputs,
  inputs',
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

  # Check if user has specific secrets configured (awilliams-specific)
  hasUserSecrets = username == "awilliams";
  hasNvidia = osConfig.rat.hardware.nvidia.enable;
  gpuVram = osConfig.rat.hardware.gpu.vram;
  hasLargeVram = gpuVram >= 16;
  peonPingCfg = cliCfg.ai.peon-ping or {};
  peonSettings = peonPingCfg.settings or {};
in {
  imports = [
    inputs.peon-ping.homeManagerModules.default
  ];

  config = modules.mkIf (cliCfg.enable && cliCfg.ai.enable) {
    xdg.userDirs.extraConfig.XDG_AI_DIR = "$HOME/AI";

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        "AI"
        ".gstack"
      ];
    };

    sops.secrets = lib.mkIf hasUserSecrets {
      civitaiApiToken = {};
      hfToken = {};
      openrouterApiKey = {};
    };

    home.packages =
      (with pkgs; [
        llm
        python3Packages.huggingface-hub
      ])
      ++ lib.optional (hasNvidia && hasLargeVram) inputs'.llama-cpp.packages.cuda;

    home.sessionVariables = {
      HF_HUB_ENABLE_HF_TRANSFER = "1";
    };

    programs.comfy-cli = {
      enable = true;
      package = pkgs.comfy-cli;
    };

    programs.opencode.enable = true;

    programs.peon-ping = modules.mkIf peonPingCfg.enable {
      enable = true;
      package = inputs'.peon-ping.packages.default;
      installPacks = peonPingCfg.packs;
      settings = lib.filterAttrs (_: v: v != null) peonSettings;
    };

    programs.zsh.initContent = lib.mkIf hasUserSecrets (lib.mkBefore ''
      export CIVITAI_API_TOKEN=$(cat ${config.sops.secrets.civitaiApiToken.path})
      export HF_TOKEN=$(cat ${config.sops.secrets.hfToken.path})
      export OPENROUTER_API_KEY=$(cat ${config.sops.secrets.openrouterApiKey.path})
    '');
  };
}
