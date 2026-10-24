{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) attrsets lists modules strings;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  proxies = cliCfg.networking.tailsocks or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  browserProxies = attrsets.filterAttrs (_name: proxy: proxy.browser.enable) proxies;

  profileName = name: "tailsocks-${name}";
  windowClass = name: "zen-tailsocks-${name}";

  launcher = name:
    pkgs.writeShellApplication {
      name = "zen-tailsocks-${name}";
      text = ''
        exec ${lib.getExe config.programs.zen-browser.finalPackage} \
          --profile ${strings.escapeShellArg "${config.programs.zen-browser.configPath}/${profileName name}"} \
          --name ${windowClass name} \
          "$@"
      '';
    };
in {
  config = modules.mkIf (proxies != {}) {
    assertions = [
      {
        assertion = browserProxies == {} || config.programs.zen-browser.enable;
        message = "rat.users.${username}.cli.networking.tailsocks.*.browser needs Zen enabled.";
      }
    ];

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      # The state directory holds the node key; losing it registers a new
      # device on the tailnet, which then needs logging in again.
      directories = [".local/state/tailsocks"];
    };

    # Profile ids must be unique across all Zen profiles; the default one is 0.
    programs.zen-browser.profiles = attrsets.listToAttrs (lists.imap1 (i: name: let
      proxy = browserProxies.${name};
    in {
      name = profileName name;
      value = {
        id = 100 + i;
        name = profileName name;
        settings = {
          "network.proxy.type" = 1;
          "network.proxy.socks" = "127.0.0.1";
          "network.proxy.socks_port" = proxy.socksPort;
          "network.proxy.socks_version" = 5;
          "network.proxy.socks_remote_dns" = true;
          "network.proxy.socks5_remote_dns" = true;
          # Without these, a dead proxy silently falls back to a direct
          # connection, and DNS-over-HTTPS and WebRTC's ICE candidates can
          # reveal the real address.
          "network.proxy.failover_direct" = false;
          "network.trr.mode" = 5;
          "media.peerconnection.ice.proxy_only" = true;

          # Geolocation reports the real location whatever the proxy says.
          "geo.enabled" = false;
          "permissions.default.geolocation" = 2;

          "media.eme.enabled" = true;
          "media.gmp-widevinecdm.enabled" = true;
          "browser.shell.checkDefaultBrowser" = false;
        };
      };
    }) (attrsets.attrNames browserProxies));

    home.packages = lists.map launcher (attrsets.attrNames browserProxies);

    xdg.desktopEntries =
      attrsets.mapAttrs' (name: proxy: {
        name = "zen-tailsocks-${name}";
        value = {
          name = "Zen Browser (${name})";
          genericName = "Web Browser";
          comment = "Browse through the ${proxy.exitNode} exit node";
          exec = "${lib.getExe (launcher name)} %U";
          icon = "zen-browser";
          categories = ["Network" "WebBrowser"];
          settings.StartupWMClass = windowClass name;
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
