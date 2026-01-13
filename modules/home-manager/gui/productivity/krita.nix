{
  self',
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

  kritaEnabled = (guiCfg.enable or false) && (productivityCfg.enable or false) && (kritaCfg.enable or false);
  aiDiffusionEnabled = kritaEnabled && (kritaCfg.aiDiffusion.enable or false);

  aiDiffusionPkg = self'.packages.krita-ai-diffusion;
in {
  config = modules.mkIf kritaEnabled {
    home.packages = [pkgs.krita];

    # Krita only looks for pykrita plugins in ~/.local/share/krita/pykrita/
    # Symlink the plugin there
    xdg.dataFile = modules.mkIf aiDiffusionEnabled {
      "krita/pykrita/ai_diffusion".source = "${aiDiffusionPkg}/share/krita/pykrita/ai_diffusion";
      "krita/pykrita/ai_diffusion.desktop".source = "${aiDiffusionPkg}/share/krita/pykrita/ai_diffusion.desktop";
    };
  };
}
