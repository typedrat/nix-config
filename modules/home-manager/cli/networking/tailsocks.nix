{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) attrsets lists modules strings;
  inherit (config.home) username homeDirectory;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  proxies = cliCfg.networking.tailsocks or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  browserProxies = attrsets.filterAttrs (_name: proxy: proxy.browser.enable) proxies;

  profileDir = name: ".config/google-chrome-tailsocks-${name}";

  launcher = name: proxy:
    pkgs.writeShellApplication {
      name = "chrome-tailsocks-${name}";
      text = ''
        # Chrome resolves names through a SOCKS5 proxy already, but DNS
        # prefetching and WebRTC's direct UDP paths bypass it and expose the
        # real address. The resolver rule fails every local lookup outright.
        exec ${lib.getExe config.programs.google-chrome.finalPackage} \
          --user-data-dir=${strings.escapeShellArg "${homeDirectory}/${profileDir name}"} \
          --class=chrome-tailsocks-${name} \
          --proxy-server=socks5://127.0.0.1:${toString proxy.socksPort} \
          --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE 127.0.0.1" \
          --force-webrtc-ip-handling-policy=disable_non_proxied_udp \
          "$@"
      '';
    };
in {
  config = modules.mkIf (proxies != {}) {
    assertions = [
      {
        assertion = browserProxies == {} || config.programs.google-chrome.enable;
        message = "rat.users.${username}.cli.networking.tailsocks.*.browser needs Google Chrome enabled.";
      }
    ];

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      # The state directory holds the node key; losing it registers a new
      # device on the tailnet, which then needs logging in again.
      directories =
        [".local/state/tailsocks"]
        ++ lists.map profileDir (attrsets.attrNames browserProxies);
    };

    home.packages = attrsets.mapAttrsToList launcher browserProxies;

    xdg.desktopEntries =
      attrsets.mapAttrs' (name: proxy: {
        name = "chrome-tailsocks-${name}";
        value = {
          name = "Google Chrome (${name})";
          genericName = "Web Browser";
          comment = "Browse through the ${proxy.exitNode} exit node";
          exec = "${lib.getExe (launcher name proxy)} %U";
          icon = "google-chrome";
          categories = ["Network" "WebBrowser"];
          settings.StartupWMClass = "chrome-tailsocks-${name}";
        };
      })
      browserProxies;

    systemd.user.services =
      attrsets.mapAttrs' (name: proxy: {
        name = "tailsocks-${name}";
        value = {
          Unit = {
            Description = "SOCKS5 proxy through the ${proxy.exitNode} Tailscale exit node";
            After = ["network-online.target"];
          };
          Install.WantedBy = ["default.target"];

          Service = {
            # With no saved node key, the login URL is printed to the journal
            # and the proxy waits until it is approved.
            ExecStart = strings.escapeShellArgs ([
                (lib.getExe pkgs.tailsocks)
                "--exit-node=${proxy.exitNode}"
                "--hostname=${osConfig.networking.hostName}-${name}"
                "--state-dir=%S/tailsocks/${name}"
                "--socks-addr=127.0.0.1:${toString proxy.socksPort}"
              ]
              ++ lists.optional (proxy.httpPort != null)
              "--http-addr=127.0.0.1:${toString proxy.httpPort}");
            StateDirectory = "tailsocks/${name}";
            Restart = "on-failure";
            RestartSec = "10s";
          };
        };
      })
      proxies;
  };
}
