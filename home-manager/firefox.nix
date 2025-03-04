{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  cascade = pkgs.fetchFromGitHub {
    owner = "cascadefox";
    repo = "cascade";
    rev = "8239e304844beb854c068a273f1171f7fadd5212";
    hash = "sha256-Ab9KPCt1bWRj2+yU3s5n0SVCctVxeIPuT6H+HQqheQQ=";
  };
in {
  programs.firefox = {
    enable = true;
    package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
      extraPolicies = {
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFirefoxAccounts = false;
        NoDefaultBookmarks = true;

        FirefoxHome = {
          Search = true;
          Pocket = false;
          Snippets = false;
          TopSites = false;
          Highlights = false;
        };
      };
    };

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
          packages = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            bitwarden
            stylus
          ];
        };

        userChrome = let
          flavor =
            if osConfig.catppuccin.flavor == "latte"
            then "mocha"
            else osConfig.catppuccin.flavor;
        in
          lib.strings.concatLines [
            (builtins.readFile "${cascade}/chrome/includes/cascade-config.css")
            (builtins.readFile "${cascade}/chrome/includes/cascade-layout.css")
            (builtins.readFile "${cascade}/chrome/includes/cascade-responsive.css")
            (builtins.readFile "${cascade}/chrome/includes/cascade-floating-panel.css")
            (builtins.readFile "${cascade}/chrome/includes/cascade-nav-bar.css")
            (builtins.readFile "${cascade}/chrome/includes/cascade-tabs.css")
            (builtins.readFile "${cascade}/integrations/catppuccin/cascade-${flavor}.css")
          ];
      };
    };
  };
}
