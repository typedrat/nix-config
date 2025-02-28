{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    package = pkgs.wrapFirefox pkgs.firefox-bin-unwrapped {
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
          "widget.use-xdg-desktop-portal.file-picker" = 1; # Use KDE File Picker
          "extensions.autoDisableScopes" = 0; # Don't auto-disable extensions
          "app.update.auto" = false;

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

        extensions = {
          packages = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            bitwarden
          ];
        };
      };
    };
  };
}
