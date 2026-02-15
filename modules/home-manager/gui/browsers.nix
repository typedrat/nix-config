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
  guiCfg = userCfg.gui or {};
  browsersCfg = guiCfg.browsers or {};

  capitalizeFirst = str:
    (lib.strings.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);

  flavor =
    if osConfig.catppuccin.flavor == "latte"
    then "mocha"
    else osConfig.catppuccin.flavor;
  accent = osConfig.catppuccin.accent or "mauve";

  zenRepoFlavor = capitalizeFirst flavor;
  zenRepoAccent = capitalizeFirst accent;

  commonFirefoxConfig = {
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;

        settings = {
          "general.autoscroll" = true;
          "general.smoothScroll" = true;
          "media.ffmpeg.vaapi.enabled" = true;
          "widget.use-xdg-desktop-portal.file-picker" = 1;
          "extensions.autoDisableScopes" = 0;
          "app.update.auto" = false;

          "font.default.x-western" = "sans-serif";
          "font.name-list.emoji" = "Apple Color Emoji";
          "font.name.sans-serif.he" = "SF Hebrew";
          "font.name.serif.he" = "Taamey Frank CLM";
          "font.name.monospace.he" = "Miriam Mono CLM";
          "font.name.sans-serif.ja" = "M PLUS 1";
          "font.name.serif.ja" = "IPAexMincho";
          "font.name.monospace.ja" = "M Plus 1 Code";

          "app.shield.optoutstudies" = false;
          "browser.discovery.enabled" = false;
          "extensions.getAddons.showPane" = false;
          "extensions.htmlaboutaddons.recommendations.enabled" = false;

          "browser.contentblocking.category" = "strict";
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.pbmode.enabled" = true;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.trackingprotection.cryptomining.enabled" = true;
          "privacy.trackingprotection.fingerprinting.enabled" = true;

          "privacy.query_stripping.enabled" = true;
          "privacy.query_stripping.enabled.pbmode" = true;

          "network.auth.subresource-http-auth-allow" = 1;

          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

          "extensions.webextensions.ExtensionStorageIDB.enabled" = false;
        };

        search.engines = {
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@np"];
          };
          "Nix Options" = {
            definedAliases = ["@no"];
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
          };

          "Home Manager Options" = {
            definedAliases = ["@hm"];
            urls = [
              {
                template = "https://home-manager-options.extranix.com/";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                  {
                    name = "release";
                    value = "master";
                  }
                ];
              }
            ];
          };

          "Noogle" = {
            definedAliases = ["@ng" "@noog" "@noogle"];
            urls = [
              {
                template = "https://noogle.dev/q";
                params = [
                  {
                    name = "term";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
          };
        };

        extensions = {
          force = true;

          packages = with inputs'.firefox-addons.packages; [
            pkgs.bypass-paywalls-clean
            pkgs.ttv-lol-pro

            augmented-steam
            bitwarden
            catppuccin-web-file-icons
            consent-o-matic
            downthemall
            indie-wiki-buddy
            metamask
            offline-qr-code-generator
            react-devtools
            return-youtube-dislikes
            sponsorblock
            stylus
            ublock-origin
            violentmonkey
          ];
        };
      };
    };
  };
in {
  imports = [
    inputs.zen-browser.homeModules.default
    ./firefox
  ];

  config = modules.mkMerge [
    # Brave
    (modules.mkIf ((guiCfg.enable or false) && (browsersCfg.brave.enable or false)) {
      programs.brave = {
        enable = true;
        commandLineArgs = [
          "--no-default-browser-check"
          "--enable-features=UseOzonePlatform,Vulkan,VulkanFromANGLE"
          "--enable-unsafe-webgpu"
          "--use-angle=vulkan"
          "--ozone-platform=wayland"
          "--enable-wayland-ime"
          "--wayland-text-input-version=3"
        ];
        extensions = [
          "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
          "mbniclmhobmnbdlbpiphghaielnnpgdp" # Lightshot
          "gcbommkclmclpchllfjekcdonpmejbdp" # HTTPS Everywhere
          "lnjaiaapbakfhlbjenjkhffcdpoompki" # Catppuccin for Web File Explorer Icons
          "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
          "fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude
        ];
      };

      # Claude Code native messaging host for Brave
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
      ];
    })

    # Zen Browser
    (modules.mkIf ((guiCfg.enable or false) && (browsersCfg.zen.enable or false)) {
      programs.zen-browser = lib.attrsets.recursiveUpdate commonFirefoxConfig {
        enable = true;

        profiles = {
          default = {
            userChrome = let
              patchCss = file:
                pkgs.runCommand "patched-css" {} ''
                  ARROWPANEL_COLOR=''$(${pkgs.gnugrep}/bin/grep -o -- '--arrowpanel-color: [^;]*' ${file} | ${pkgs.coreutils}/bin/cut -d' ' -f2)
                  ARROWPANEL_BG=''$(${pkgs.gnugrep}/bin/grep -o -- '--arrowpanel-background: [^;]*' ${file} | ${pkgs.coreutils}/bin/cut -d' ' -f2)

                  ${pkgs.gnused}/bin/sed \
                    -e '/--arrowpanel-color:/d' \
                    -e '/--arrowpanel-background:/d' \
                    -e '/^}$/i\\n  #mainPopupSet > menupopup, panel,tooltip {\n    --arrowpanel-color: '"$ARROWPANEL_COLOR"';\n    --arrowpanel-background: '"$ARROWPANEL_BG"';\n  }' \
                    ${file} > $out
                '';
            in
              lib.strings.concatLines [
                (builtins.readFile (patchCss "${inputs.catppuccin-zen}/themes/Latte/${zenRepoAccent}/userChrome.css"))
                (builtins.readFile (patchCss "${inputs.catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/userChrome.css"))
              ];
          };
        };
      };

      home.file.".zen/default/search.json.mozlz4".force = lib.mkForce true;

      home.file.".zen/default/chrome/userContent.css".text = lib.strings.concatLines [
        (builtins.readFile "${inputs.catppuccin-zen}/themes/Latte/${zenRepoAccent}/userContent.css")
        (builtins.readFile "${inputs.catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/userContent.css")
      ];

      home.file.".zen/default/chrome/zen-logo-latte.svg".source = "${inputs.catppuccin-zen}/themes/Latte/${zenRepoAccent}/zen-logo-latte.svg";
      home.file.".zen/default/chrome/zen-logo-${flavor}.svg".source = "${inputs.catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/zen-logo-${flavor}.svg";
    })
  ];
}
