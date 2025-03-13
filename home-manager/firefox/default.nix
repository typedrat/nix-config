{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}: let
  catppuccin-zen = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "zen-browser";
    rev = "b048e8bd54f784d004812036fb83e725a7454ab4";
    hash = "sha256-SoaJV83rOgsQpLKO6PtpTyKFGj75FssdWfTITU7psXM=";
  };

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
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;

        settings = {
          "general.autoscroll" = true;
          "general.smoothScroll" = true;
          "media.ffmpeg.vaapi.enabled" = true;
          "widget.use-xdg-desktop-portal.file-picker" = 1; # Use KDE File Picker
          "extensions.autoDisableScopes" = 0; # Don't auto-disable extensions
          "app.update.auto" = false;

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

          packages = with pkgs.nur.repos.rycee.firefox-addons; [
            bitwarden
            greasemonkey
            metamask
            sponsorblock
            stylus
            ublock-origin
          ];
        };
      };
    };
  };

  zen-browser = inputs.zen-browser.packages."${pkgs.stdenv.system}".default;
in {
  programs.zen-browser = lib.attrsets.recursiveUpdate commonConfig {
    enable = true;
    package = zen-browser;

    profiles = {
      default = {
        userChrome = lib.strings.concatLines [
          (builtins.readFile "${catppuccin-zen}/themes/Latte/${zenRepoAccent}/userChrome.css")
          (builtins.readFile "${catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/userChrome.css")
        ];
      };
    };
  };

  home.file.".zen/default/search.json.mozlz4".force = lib.mkForce true;

  home.file.".zen/default/chrome/userContent.css".text = lib.strings.concatLines [
    (builtins.readFile "${catppuccin-zen}/themes/Latte/${zenRepoAccent}/userContent.css")
    (builtins.readFile "${catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/userContent.css")
  ];

  home.file.".zen/default/chrome/zen-logo-latte.svg".source = "${catppuccin-zen}/themes/Latte/${zenRepoAccent}/zen-logo-latte.svg";
  home.file.".zen/default/chrome/zen-logo-${flavor}.svg".source = "${catppuccin-zen}/themes/${zenRepoFlavor}/${zenRepoAccent}/zen-logo-${flavor}.svg";
}
