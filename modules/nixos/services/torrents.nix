{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.torrents;
  impermanenceCfg = config.rat.impermanence;
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
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.rtorrent = {
        enable = true;
        group = "media";

        port = 42069;
        openFirewall = true;
        inherit (cfg) downloadDir;
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

      links.flood = {
        protocol = "http";
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
