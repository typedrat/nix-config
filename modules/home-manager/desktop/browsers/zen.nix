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
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

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

  zenFirefoxConfig = {
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

        search.force = true;
        search.engines = {
          nix-packages = {
            name = "Nix Packages";
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

          nix-options = {
            name = "Nix Options";
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
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@no"];
          };

          nixos-wiki = {
            name = "NixOS Wiki";
            urls = [
              {
                template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@nw"];
          };

          hm-options = {
            name = "Home Manager Options";
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
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@hm"];
          };

          noogle = {
            name = "Noogle";
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
            definedAliases = ["@ng" "@noog" "@noogle"];
          };

          npm = {
            name = "NPM";
            urls = [
              {
                template = "https://www.npmjs.com/search";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            favicon = "https://static.npmjs.com/f1786e9b7cba9753ca7b9c40e8b98f67.png";
            definedAliases = ["@npm"];
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
            granted
            indie-wiki-buddy
            metamask
            offline-qr-code-generator
            react-devtools
            return-youtube-dislikes
            sponsorblock
            stylus
            ublock-origin
            violentmonkey
            zotero-connector
          ];
        };
      };
    };
  };
in {
  imports = [
    inputs.zen-browser.homeModules.default
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (browsersCfg.zen.enable or false)) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/zen" ".cache/zen" ".mozilla" ".pki"];
    };

    programs.zen-browser = lib.attrsets.recursiveUpdate zenFirefoxConfig {
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

      nativeMessagingHosts = [
        (pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/io.commonfate.granted.json" (builtins.toJSON {
          name = "io.commonfate.granted";
          description = "Granted BrowserSupport";
          path = "${pkgs.granted}/bin/granted";
          type = "stdio";
          allowed_extensions = [
            "{b5e0e8de-ebfe-4306-9528-bcc18241a490}"
          ];
        }))
      ];
    };

    home.file.".config/zen/default/chrome/userContent.css".text = lib.strings.concatLines [
      (builtins.readFile "${inputs.catppuccin-zen}/themes/Latte/${zenRepoAccent}/userContent.css")
      (builtins.readFile "${inputs.catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/userContent.css")
    ];

    home.file.".config/zen/default/chrome/zen-logo-latte.svg".source = "${inputs.catppuccin-zen}/themes/Latte/${zenRepoAccent}/zen-logo-latte.svg";
    home.file.".config/zen/default/chrome/zen-logo-${flavor}.svg".source = "${inputs.catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/zen-logo-${flavor}.svg";
  };
}
