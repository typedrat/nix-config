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
  guiCfg = userCfg.gui or {};
  productivityCfg = guiCfg.productivity or {};
  kritaCfg = productivityCfg.krita or {};

  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  kritaEnabled = guiCfg.enable && productivityCfg.enable && kritaCfg.enable;
  aiDiffusionEnabled = kritaEnabled && kritaCfg.aiDiffusion.enable;

  aiDiffusionPkg = pkgs.krita-ai-diffusion;
in {
  config = modules.mkIf kritaEnabled {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/krita" ".local/share/krita"];
    };

    home.packages = [pkgs.krita];

    # Krita only looks for pykrita plugins in ~/.local/share/krita/pykrita/
    # Symlink the plugin there
    xdg.dataFile = modules.mkIf aiDiffusionEnabled {
      "krita/pykrita/ai_diffusion".source = "${aiDiffusionPkg}/share/krita/pykrita/ai_diffusion";
      "krita/pykrita/ai_diffusion.desktop".source = "${aiDiffusionPkg}/share/krita/pykrita/ai_diffusion.desktop";
    };
  };
}
