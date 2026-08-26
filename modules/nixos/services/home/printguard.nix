{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.printguard;
  impermanenceCfg = config.rat.impermanence;
  inherit (config.rat.services) domainName;

  stateDir = "/var/lib/printguard";

  # PrintGuard supervises this binary itself and republishes every camera
  # through it, so the addresses have to be reservations rather than the
  # upstream defaults — go2rtc already holds the stock RTSP port.
  mediamtxConfig = (pkgs.formats.yaml {}).generate "mediamtx.yml" {
    api = true;
    apiAddress = config.links.printguard-mediamtx-api.tuple;

    # Without a permissive internal user PrintGuard cannot publish to or read
    # from the instance it just spawned.
    authInternalUsers = [
      {
        user = "any";
        permissions = [
          {action = "publish";}
          {action = "read";}
          {action = "playback";}
          {action = "api";}
        ];
      }
    ];

    rtsp = true;
    rtspAddress = config.links.printguard-mediamtx-rtsp.tuple;
    rtspTransports = ["tcp"];

    hls = true;
    hlsAddress = config.links.printguard-mediamtx-hls.tuple;
    hlsVariant = "fmp4";
    hlsSegmentCount = 3;
    hlsSegmentDuration = "1s";

    # Nothing here publishes over RTMP, and its default 1935 has no `links`
    # reservation standing behind it.
    rtmp = false;
    webrtc = false;
    srt = false;

    paths.all_others = null;
  };
in {
  options.rat.services.printguard = {
    enable = options.mkEnableOption "PrintGuard 3D print failure detection";

    subdomain = options.mkOption {
      type = types.str;
      default = "printguard";
      description = "The subdomain for PrintGuard.";
    };

    enableTraefik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Traefik reverse proxy for PrintGuard.";
    };

    authentik = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Put the web UI behind Authentik forward auth. Home Assistant reaches
        PrintGuard over MQTT rather than HTTP, so nothing machine-driven needs
        the HTTP surface — but forward auth does block the scoped-token REST
        and MCP API, so turn this off to use those.
      '';
    };

    plugins = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Run the QuickJS-on-wasmtime plugin sandbox. Disabling sets
        `PRINTGUARD_PLUGINS=off`, which the hub reports at startup.
      '';
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.printguard.protocol = "http";
      links.printguard-mediamtx-api.protocol = "http";
      links.printguard-mediamtx-rtsp.protocol = "rtsp";
      links.printguard-mediamtx-hls.protocol = "http";

      users.users.printguard = {
        isSystemUser = true;
        group = "printguard";
        home = stateDir;
      };
      users.groups.printguard = {};

      systemd.services.printguard = {
        description = "PrintGuard 3D print failure detection";
        after = ["network-online.target" "mosquitto.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        environment =
          {
            HOST = config.links.printguard.ipv4;
            PORT = config.links.printguard.portStr;

            DATA_DIR = stateDir;
            MODEL_DIR = "${pkgs.printguard}/share/printguard/models";
            STATIC_DIR = "${pkgs.printguard}/share/printguard/web";

            MEDIAMTX_BINARY = lib.getExe pkgs.mediamtx;
            MEDIAMTX_CONFIG = "${mediamtxConfig}";
            MEDIAMTX_API = config.links.printguard-mediamtx-api.url;
            MEDIAMTX_RTSP = config.links.printguard-mediamtx-rtsp.url;
            MEDIAMTX_HLS = config.links.printguard-mediamtx-hls.url;

            PRINTGUARD_ORIGINS = "https://${cfg.subdomain}.${domainName}";
          }
          // lib.optionalAttrs (!cfg.plugins) {
            PRINTGUARD_PLUGINS = "off";
          };

        serviceConfig = {
          ExecStart = lib.getExe pkgs.printguard;
          User = "printguard";
          Group = "printguard";
          WorkingDirectory = stateDir;
          StateDirectory = "printguard";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })

    (modules.mkIf (cfg.enable && cfg.enableTraefik) {
      rat.services.traefik.routes.printguard = {
        enable = true;
        inherit (cfg) subdomain authentik;
        serviceUrl = config.links.printguard.url;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = stateDir;
            user = "printguard";
            group = "printguard";
          }
        ];
      };
    })
  ];
}
