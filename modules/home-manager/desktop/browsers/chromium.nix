{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  browsersCfg = guiCfg.browsers or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && browsersCfg.chromium.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/google-chrome"];
    };

    programs.google-chrome = {
      enable = true;
      commandLineArgs = [
        "--no-default-browser-check"
        "--enable-features=UseOzonePlatform,Vulkan,VulkanFromANGLE,WebNN"
        "--use-angle=vulkan"
        "--ozone-platform=x11"
        "--enable-wayland-ime"
        "--wayland-text-input-version=3"
      ];
    };
  };
}
