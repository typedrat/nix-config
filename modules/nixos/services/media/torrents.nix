{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.torrents;
  impermanenceCfg = config.rat.impermanence;

  # rtorrent "0.15.1" in nixpkgs is a broken commit from before the release was officially cut.
  #
  # This replaces it with... another somewhat broken commit from before 0.15.3 is officially cut,
  # but it fixes the completely trashed XML-RPC output.
  libtorrent = pkgs.libtorrent.overrideAttrs {
    version = "0.15.3-dev.270e7dc";
    src = pkgs.fetchFromGitHub {
      owner = "rakshasa";
      repo = "libtorrent";
      rev = "270e7dc4150f283037653f91af3ccc6a19bc826b";
      hash = "sha256-VZDByohyvwK5O1At+t4ll8ucWea+0a8Y0G4G/nw0hnw=";
    };
  };

  rtorrent =
    (pkgs.rtorrent.overrideAttrs {
      version = "0.15.3-dev.3d9c083";
      src = pkgs.fetchFromGitHub {
        owner = "rakshasa";
        repo = "rtorrent";
        rev = "3d9c083032ad3201863079c5262838884f096b06";
        hash = "sha256-uK/Xfs+avZn91Q1Gew6saMnRuJPrOBrgxHb/6MgdnNQ=";
      };
    }).override {
      libtorrent = libtorrent;
    };
in {
  options.rat.services.torrents = {
    enable = options.mkEnableOption "Torrent services";
    downloadDir = options.mkOption {
      type = types.path;
      description = "Directory for downloaded files";
    };
    subdomain = options.mkOption {
      type = types.str;
      default = "flood";
      description = "The subdomain for the Flood interface.";
    };
    optimizedSettings = options.mkOption {
      type = types.bool;
      default = false;
      description = "Enable optimized settings for rTorrent";
    };
    rpcExposed = options.mkOption {
      type = types.bool;
      default = false;
      description = "Expose the rTorrent RPC interface over HTTP with authentication on `localhost`.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.rtorrent = {
        enable = true;
        package = rtorrent;
        group = "media";

        port = 42069;
        openFirewall = true;
        inherit (cfg) downloadDir;
      };

      users.users.rtorrent.uid = 990;

      systemd.services.rtorrent-lighttpd = {
        description = "Lighttpd SCGI service for rtorrent";
        after = ["rtorrent.service"];

        serviceConfig = {
          ExecStart = let
            lighttpdConfig = pkgs.writeText "lighttpd.conf" ''
              server.bind = "${config.links.rtorrent.ipv4}"
              server.port = ${builtins.toString config.links.rtorrent.port}
              server.document-root = "/var/empty"

              server.modules += (
                "mod_authn_file"
              )
              auth.backend = "htpasswd"
              auth.backend.htpasswd.userfile = "${config.sops.secrets."rtorrent/htpasswd".path}"

              server.modules += (
                "mod_auth"
              )
              auth.require = (
                "/" => (
                  "method" => "basic",
                  "realm" => "rtorrent",
                  "require" => "valid-user"
                )
              )

              server.modules += (
                "mod_scgi"
              )
              scgi.server = (
                "/RPC2" => (
                  "127.0.0.1" => (
                    "socket" => "${config.services.rtorrent.rpcSocket}",
                    "check-local" => "disable"
                  )
                )
              )
            '';
          in "${pkgs.lighttpd}/bin/lighttpd -D -f ${lighttpdConfig}";
          Restart = "on-failure";
          RestartSec = "5s";

          User = config.services.rtorrent.user;
          Group = config.services.rtorrent.group;

          ReadOnlyPaths = [config.sops.secrets."rtorrent/htpasswd".path];
          CapabilityBoundingSet = "";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          SystemCallArchitectures = "native";
          SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
        };
      };

      sops.secrets."rtorrent/htpasswd" = {
        sopsFile = ../../../../secrets/rtorrent.yaml;
        key = "htpasswd";
        owner = config.services.rtorrent.user;
        group = config.services.rtorrent.group;
        restartUnits = ["rtorrent-lighttpd.service"];
      };

      services.flood = {
        enable = true;
        inherit (config.links.flood) port;
        extraArgs = [
          "--auth=none"
          "--allowedpath=${cfg.downloadDir}"
          "--rtsocket=${config.services.rtorrent.rpcSocket}"
        ];
      };

      systemd.services.flood.serviceConfig.SupplementaryGroups = [
        config.services.rtorrent.group
      ];

      links = {
        flood = {
          protocol = "http";
        };
        rtorrent = {
          protocol = "http";
        };
      };

      rat.services.traefik.routes.flood = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.flood.url;

        authentik = true;
        theme-park.app = "flood";
      };
    })
    (modules.mkIf (cfg.enable && cfg.optimizedSettings) {
      services.rtorrent.configText = ''
        pieces.memory.max.set = 16384M
        network.http.max_open.set = 64
        network.max_open_files.set = 32768
        network.max_open_sockets.set = 2048
        throttle.max_uploads.set = 100
        throttle.max_uploads.global.set = 500
        throttle.max_downloads.set = 100
        throttle.max_downloads.global.set = 500
        pieces.hash.on_completion.set = no
        pieces.preload.type.set = 0
        network.receive_buffer.size.set = 16M
        network.send_buffer.size.set = 16M
        network.tos.set = throughput
        system.file.allocate = 1
        network.http.dns_cache_timeout.set = 0
        schedule2 = session_save, 1200, 43200, ((session.save))
      '';

      systemd.services.rtorrent.serviceConfig.LimitNOFILE = 102400;

      boot.kernel.sysctl = {
        # Maximum Socket Receive Buffer. 16MB per socket - which sounds like a lot, but will virtually never consume that much. Default: 212992
        "net.core.rmem_max" = 16777216;
        # Maximum Socket Send Buffer. 16MB per socket - which sounds like a lot, but will virtually never consume that much. Default: 212992
        "net.core.wmem_max" = 16777216;
        # Increase the write-buffer-space allocatable: min 4KB, def 12MB, max 16MB. Default: 4096 16384 4194304
        "net.ipv4.tcp_wmem" = "4096 12582912 16777216";
        # Increase the read-buffer-space allocatable: min 4KB, def 12MB, max 16MB. Default: 4096 16384 4194304
        "net.ipv4.tcp_rmem" = "4096 12582912 16777216";

        # Tells the system whether it should start at the default window size only for new TCP connections or also for existing TCP connections that have been idle for too long. Default: 1
        "net.ipv4.tcp_slow_start_after_idle" = 0;
        # Allow reuse of sockets in TIME_WAIT state for new connections only when it is safe from the network stack’s perspective. Default: 0
        "net.ipv4.tcp_tw_reuse" = 1;
        # Minimum time a socket will stay in TIME_WAIT state (unusable after being used once). Default: 60
        "net.ipv4.tcp_fin_timeout" = 30;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.rtorrent.dataDir;
            inherit (config.services.rtorrent) user group;
          }
        ];
      };
    })
  ];
}
