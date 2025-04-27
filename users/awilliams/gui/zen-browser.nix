{
  self,
  self',
  inputs,
  inputs',
  pkgs,
  lib,
  osConfig,
  ...
}: let
  inherit (lib.modules) mkIf;

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

  commonConfig = {
    nativeMessagingHosts = with pkgs; [
      firefoxpwa
    ];

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
          "extensions.autoDisableScopes" = 0; # Don't auto-disable extensions
          "app.update.auto" = false;

          # Default to sans-serif font!
          "font.default.x-western" = "sans-serif";

          # Emoji font config
          "font.name-list.emoji" = "Apple Color Emoji";

          # Hebrew font config
          "font.name.sans-serif.he" = "SF Hebrew";
          "font.name.serif.he" = "Taamey Frank CLM";
          "font.name.monospace.he" = "Miriam Mono CLM";

          # Japanese font config
          "font.name.sans-serif.ja" = "M PLUS 1";
          "font.name.serif.ja" = "IPAexMincho";
          "font.name.monospace.ja" = "M Plus 1 Code";

          # Telemetry
          "app.shield.optoutstudies" = false;

          # Addon Recommendations
          "browser.discovery.enabled" = false;
          "extensions.getAddons.showPane" = false;
          "extensions.htmlaboutaddons.recommendations.enabled" = false;

          # Tracking
          "browser.contentblocking.category" = "strict";
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.pbmode.enabled" = true;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.trackingprotection.cryptomining.enabled" = true;
          "privacy.trackingprotection.fingerprinting.enabled" = true;

          # Query Tracking
          "privacy.query_stripping.enabled" = true;
          "privacy.query_stripping.enabled.pbmode" = true;

          # Phishing
          # Disables cross-origin sub-resources from opening HTTP authentication credentials dialogs
          "network.auth.subresource-http-auth-allow" = 1;

          # Enable `userChrome.css`
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

          # Configure extensions declaratively
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
        };

        extensions = {
          force = true;

          packages = with inputs'.firefox-addons.packages; [
            self'.packages.bypass-paywalls-clean
            pwas-for-firefox
            bitwarden
            greasemonkey
            metamask
            sponsorblock
            stylus
            ublock-origin
            react-devtools
            catppuccin-web-file-icons
            offline-qr-code-generator
          ];
        };
      };
    };
  };
in {
  imports = [
    self.homeModules.zen-browser
  ];

  config = mkIf osConfig.rat.gui.enable {
    home.packages = with pkgs; [
      firefoxpwa
    ];

    programs.zen-browser = lib.attrsets.recursiveUpdate commonConfig {
      enable = true;

      profiles = {
        default = {
          userChrome = lib.strings.concatLines [
            (builtins.readFile "${inputs.catppuccin-zen}/themes/Latte/${zenRepoAccent}/userChrome.css")
            (builtins.readFile "${inputs.catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/userChrome.css")
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
  };
}
