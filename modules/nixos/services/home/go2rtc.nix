{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.go2rtc;

  # Byte-identical to the file the upstream module generates, so this resolves
  # to the same store path rather than a second copy.
  configFile =
    (pkgs.formats.yaml {}).generate "go2rtc.yaml"
    config.services.go2rtc.settings;

  mutableConfig = "/var/lib/go2rtc/go2rtc.yaml";
in {
  options.rat.services.go2rtc = {
    enable = options.mkEnableOption "go2rtc, a camera restreaming server";

    streams = options.mkOption {
      type = types.attrsOf (types.either types.str (types.listOf types.str));
      default = {};
      description = ''
        Stream sources keyed by stream name. Each name is served as
        `''${config.links.go2rtc-rtsp.url}/<name>`, and over WebRTC and MSE
        from the API port.

        A list gives one stream several producers; go2rtc picks whichever one
        can satisfy the codecs a consumer asks for.
      '';
      example = options.literalExpression ''
        {
          driveway = "rtsp://192.168.1.10:554/stream1";
          doorbell = [
            "rtsp://192.168.1.11:554/stream1"
            "ffmpeg:doorbell#audio=aac"
          ];
        }
      '';
    };

    ffmpegTemplates = options.mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        Named ffmpeg argument templates. A key used as a stream's `#video=` or
        `#audio=` value supplies encoder arguments; one used as `#input=`
        supplies input arguments and must contain `{input}`. Names matching
        go2rtc's built-ins (`h264`, `opus`, `rtsp`, ...) override them.
      '';
      example = options.literalExpression ''
        {
          h264 = "-codec:v libx264 -g:v 30 -preset:v superfast";
          nobuffer = "-fflags nobuffer -i {input}";
        }
      '';
    };

    webrtcPort = options.mkOption {
      type = types.port;
      default = 8555;
      description = ''
        TCP and UDP port carrying WebRTC media. Browsers exchange media with
        this port directly; Home Assistant and any reverse proxy only broker
        the connection, so proxying this port accomplishes nothing.
      '';
    };

    webrtcCandidates = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Extra ICE candidates to advertise, highest priority first. go2rtc
        already discovers its own local addresses; these cover the paths it
        cannot infer. `stun:<port>` asks a STUN server for this host's public
        address, which only helps once that port is forwarded here.
      '';
      example = ["stun:8555" "203.0.113.4:8555"];
    };

    openFirewall = options.mkOption {
      type = types.bool;
      default = false;
      description = "Open {option}`webrtcPort` for WebRTC media.";
    };

    credentials = options.mkOption {
      type = types.attrsOf types.path;
      default = {};
      description = ''
        Files whose contents are substituted into the configuration wherever
        `''${NAME}` appears. go2rtc looks these up in systemd's credentials
        directory before falling back to the environment, which keeps
        passwords out of the world-readable config in the Nix store.

        A value interpolated into a URL — a password in `rtsp://` or `tapo://`
        — is substituted before the URL is parsed, so it has to be
        percent-encoded in the file.
      '';
      example = options.literalExpression ''
        {
          CAMERA_PASSWORD = config.sops.secrets."go2rtc/camera_password".path;
        }
      '';
    };
  };

  config = modules.mkIf cfg.enable {
    links.go2rtc.protocol = "http";
    links.go2rtc-rtsp.protocol = "rtsp";

    services.go2rtc = {
      enable = true;
      settings = {
        api.listen = config.links.go2rtc.tuple;
        rtsp.listen = config.links.go2rtc-rtsp.tuple;
        webrtc = {
          listen = ":${toString cfg.webrtcPort}";
          candidates = cfg.webrtcCandidates;
        };
        ffmpeg = cfg.ffmpegTemplates;
        inherit (cfg) streams;
      };
    };

    # systemd opens these as root before dropping to the unit's DynamicUser,
    # so the referenced files stay owner-only.
    systemd.services.go2rtc.serviceConfig.LoadCredential =
      lib.mapAttrsToList (name: file: "${name}:${file}") cfg.credentials;

    # Changes made over the API — Home Assistant turning on preload for a
    # camera, say — are written back to the config file, and go2rtc writes to
    # whichever file it was given first. Pointed at only the generated one it
    # answers those calls with a 500 about a read-only file system, so give it
    # a writable file in the state directory ahead of the generated config.
    # Later files override earlier ones, so the declarative settings still win
    # and only the runtime additions survive in the mutable copy. The file need
    # not exist; go2rtc skips it while reading and creates it on first write.
    systemd.services.go2rtc.serviceConfig.ExecStart = lib.mkForce (
      lib.concatStringsSep " " [
        (lib.getExe config.services.go2rtc.package)
        "-config"
        mutableConfig
        "-config"
        "${configFile}"
      ]
    );

    networking.firewall = modules.mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.webrtcPort];
      allowedUDPPorts = [cfg.webrtcPort];
    };
  };
}
