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

  # Seeded only when state.json is absent. PrintGuard owns the file at runtime
  # -- every settings change rewrites the whole thing -- so this bootstraps a
  # rebuilt host rather than trying to hold the file declaratively.
  seedFile = (pkgs.formats.json {}).generate "printguard-state.json" cfg.seed.state;

  seedScript = pkgs.writeShellScript "printguard-seed" ''
    set -euo pipefail
    state="${stateDir}/state.json"
    if [ -e "$state" ]; then
      exit 0
    fi
    umask 077
    # Built aside and renamed: redirecting straight onto $state truncates it
    # before jq runs, and PrintGuard treats an unparseable state.json as empty
    # without complaining -- a failure would look like a wiped config, and the
    # seed would never run again because the file now exists.
    tmp="$state.seed.$$"
    trap 'rm -f "$tmp"' EXIT
    ${
      if cfg.seed.mqttPasswordFile == null
      then ''cp ${seedFile} "$tmp"''
      else ''
        # Read it in its own statement. A substitution that fails inside an
        # argument does not trip errexit, so an unreadable secret would
        # otherwise sail through as an empty password and only surface as the
        # broker refusing the connection.
        if ! pw=$(cat ${cfg.seed.mqttPasswordFile}); then
          echo "printguard-seed: cannot read ${cfg.seed.mqttPasswordFile}" >&2
          exit 1
        fi
        if [ -z "$pw" ]; then
          echo "printguard-seed: ${cfg.seed.mqttPasswordFile} is empty" >&2
          exit 1
        fi
        ${lib.getExe pkgs.jq} --arg pw "$pw" \
          '.settings.mqtt.password = $pw' ${seedFile} > "$tmp"
      ''
    }
    chmod 0600 "$tmp"
    mv -n "$tmp" "$state"
  '';

  # PrintGuard's default "auto" runtime builds an ONNX session on the first
  # non-CPU execution provider offered, with no fallback. This host's
  # onnxruntime is a CUDA build, but its Pascal card is not in the default
  # capability set, so that session would fail and take engine startup with
  # it. Re-importing without CUDA yields the cache.nixos.org build and drops a
  # multi-gigabyte closure that would never have run.
  cpuPkgs = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {cudaSupport = false;};
  };

  printguardPackage = pkgs.printguard.override {
    printguardOnnxruntime = cpuPkgs.python3Packages.onnxruntime;
  };

  # PrintGuard supervises this binary itself and republishes every camera
  # through it, so the addresses have to be reservations rather than the
  # upstream defaults — go2rtc already holds the stock RTSP port.
  # JSON, not YAML: pkgs.formats.yaml prefixes the file with a `%YAML 1.1`
  # directive that MediaMTX rejects outright. JSON is valid YAML and carries
  # no directive.
  mediamtxConfig = (pkgs.formats.json {}).generate "mediamtx.yml" {
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
    seed = {
      enable = options.mkEnableOption "writing state.json on first start";

      state = options.mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = ''
          Initial contents of PrintGuard's `state.json`, written only when that
          file does not already exist. Its top-level keys are `cameras`,
          `printers`, `monitors` and `settings`.

          This lands in the Nix store, which is world-readable, so it must not
          contain credentials. The MQTT password is the one secret the seed
          needs, and {option}`seed.mqttPasswordFile` injects it at runtime
          instead.

          A camera whose id is `<printer-id>-<moonraker webcam uid>` claims the
          id the printer's own webcam discovery would use, so the discovered
          camera is never added and the source here wins permanently.
        '';
      };

      mqttPasswordFile = options.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          File whose contents replace `.settings.mqtt.password` in the seed as
          it is written, keeping the password out of the Nix store.
        '';
      };
    };

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
            MODEL_DIR = "${printguardPackage}/share/printguard/models";
            STATIC_DIR = "${printguardPackage}/share/printguard/web";

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
          ExecStartPre = lib.optional cfg.seed.enable seedScript;
          ExecStart = lib.getExe printguardPackage;
          User = "printguard";
          Group = "printguard";
          WorkingDirectory = stateDir;
          StateDirectory = "printguard";
          # state.json holds the MQTT password and printer credentials entered
          # through the web UI.
          StateDirectoryMode = "0700";
          Restart = "on-failure";
          RestartSec = 5;

          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = ["@system-service" "~@privileged"];
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
