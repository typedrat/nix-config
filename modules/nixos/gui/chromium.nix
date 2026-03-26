{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  cfg = config.rat.gui;

  nativeMessagingHosts = {
    "com.anthropic.claude_code_browser_extension" = {
      name = "com.anthropic.claude_code_browser_extension";
      description = "Claude Code Browser Extension Native Host";
      path = "/etc/chromium/native-messaging-hosts/chrome-native-host-wrapper";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
      ];
    };
    "io.commonfate.granted" = {
      name = "io.commonfate.granted";
      description = "Granted BrowserSupport";
      path = "${pkgs.granted}/bin/granted";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://cjjieeldgoohbkifkogalkmfpddeafcm/"
      ];
    };
  };

  # Wrapper that finds the calling user's chrome-native-host binary
  chromeNativeHostWrapper = pkgs.writeShellScript "chrome-native-host-wrapper" ''
    exec "$HOME/.claude/chrome/chrome-native-host" "$@"
  '';

  nmhJson = name: value: {
    "chromium/native-messaging-hosts/${name}.json".text = builtins.toJSON value;
    "opt/chrome/native-messaging-hosts/${name}.json".text = builtins.toJSON (value
      // {
        path =
          builtins.replaceStrings
          ["/etc/chromium/native-messaging-hosts/"]
          ["/etc/opt/chrome/native-messaging-hosts/"]
          value.path;
      });
  };
in {
  options.rat.gui.browsers.chromium = {
    enable = mkEnableOption "Chromium-based browser with managed extensions";
  };

  config = mkIf (cfg.enable && cfg.browsers.chromium.enable) {
    programs.chromium = {
      enable = true;
      enablePlasmaBrowserIntegration = cfg.kde.enable;
      extensions = [
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
        "lnjaiaapbakfhlbjenjkhffcdpoompki" # Catppuccin for Web File Explorer Icons
        "fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude
        "cjjieeldgoohbkifkogalkmfpddeafcm" # Granted
        "gcbommkclmclpchllfjekcdonpmejbdp" # HTTPS Everywhere
        "mbniclmhobmnbdlbpiphghaielnnpgdp" # Lightshot
        "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
      ];
      extraOpts = {
        "ManagedSearchEngines" = [
          {
            "name" = "Nix Packages";
            "keyword" = "@np";
            "search_url" = "https://search.nixos.org/packages?query={searchTerms}";
          }
          {
            "name" = "Nix Options";
            "keyword" = "@no";
            "search_url" = "https://search.nixos.org/options?query={searchTerms}";
          }
          {
            "name" = "NixOS Wiki";
            "keyword" = "@nw";
            "search_url" = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
          }
          {
            "name" = "Home Manager Options";
            "keyword" = "@hm";
            "search_url" = "https://home-manager-options.extranix.com/?query={searchTerms}&release=master";
          }
          {
            "name" = "Noogle";
            "keyword" = "@ng";
            "search_url" = "https://noogle.dev/q?term={searchTerms}";
          }
          {
            "name" = "NPM";
            "keyword" = "@npm";
            "search_url" = "https://www.npmjs.com/search?q={searchTerms}";
          }
        ];
      };
    };

    environment.etc = lib.mkMerge (
      [
        {
          "chromium/native-messaging-hosts/chrome-native-host-wrapper".source = chromeNativeHostWrapper;
          "opt/chrome/native-messaging-hosts/chrome-native-host-wrapper".source = chromeNativeHostWrapper;
        }
      ]
      ++ lib.mapAttrsToList nmhJson nativeMessagingHosts
    );
  };
}
