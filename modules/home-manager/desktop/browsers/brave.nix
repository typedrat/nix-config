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
  browsersCfg = guiCfg.browsers or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && browsersCfg.brave.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/BraveSoftware"];
    };

    programs.brave = {
      enable = true;
      commandLineArgs = [
        "--no-default-browser-check"
        "--enable-features=UseOzonePlatform,Vulkan,VulkanFromANGLE,WebNN"
        "--use-angle=vulkan"
        "--ozone-platform=x11"
        "--enable-wayland-ime"
        "--wayland-text-input-version=3"
      ];
      extensions = [
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
        "lnjaiaapbakfhlbjenjkhffcdpoompki" # Catppuccin for Web File Explorer Icons
        "fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude
        "cjjieeldgoohbkifkogalkmfpddeafcm" # Granted
        "gcbommkclmclpchllfjekcdonpmejbdp" # HTTPS Everywhere
        "mbniclmhobmnbdlbpiphghaielnnpgdp" # Lightshot
        "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
      ];
    };

    programs.brave.nativeMessagingHosts = [
      (pkgs.writeTextDir "etc/chromium/native-messaging-hosts/com.anthropic.claude_code_browser_extension.json" (builtins.toJSON {
        name = "com.anthropic.claude_code_browser_extension";
        description = "Claude Code Browser Extension Native Host";
        path = "${config.home.homeDirectory}/.claude/chrome/chrome-native-host";
        type = "stdio";
        allowed_origins = [
          "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
        ];
      }))
      (pkgs.writeTextDir "etc/chromium/native-messaging-hosts/io.commonfate.granted.json" (builtins.toJSON {
        name = "io.commonfate.granted";
        description = "Granted BrowserSupport";
        path = "${pkgs.granted}/bin/granted";
        type = "stdio";
        allowed_origins = [
          "chrome-extension://cjjieeldgoohbkifkogalkmfpddeafcm/"
        ];
      }))
    ];
  };
}
