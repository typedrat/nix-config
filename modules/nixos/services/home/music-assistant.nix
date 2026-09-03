{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.music-assistant;
  impermanenceCfg = config.rat.impermanence;

  stateDir = "/var/lib/music-assistant";

  # Reads back the merged list, which is what the upstream module keys its own
  # PATH and hardening off, rather than `cfg.providers` alone.
  enabled = provider: lib.elem provider config.services.music-assistant.providers;

  airplay2 = cfg.airplay2 && enabled "airplay_receiver";

  shairportSync =
    (pkgs.shairport-sync-airplay2.override {
      # Only the avahi backend publishes the secondary TXT records that carry
      # the `_airplay._tcp` advertisement, so the bundled tinysvcmdns responder
      # would leave the receiver invisible to AirPlay 2 senders while looking
      # like it started fine. Dropping it turns that into a startup failure.
      enableTinySVCmDNS = false;
    })
    .overrideAttrs (old: {
      postPatch =
        old.postPatch
        + ''
          substituteInPlace audio_pipe.c \
            --replace-fail \
              'parse_audio_options("pipe", (1 << SPS_FORMAT_S32_LE), (1 << SPS_RATE_48000), (1 << 2));' \
              'parse_audio_options("pipe", (1 << SPS_FORMAT_S16_LE), (1 << SPS_RATE_44100), (1 << 2));'
        '';
    });
in {
  options.rat.services.music-assistant = {
    enable = options.mkEnableOption "Music Assistant";

    subdomain = options.mkOption {
      type = types.str;
      default = "music";
      description = "The subdomain for Music Assistant.";
    };

    providers = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Providers whose Python dependencies are installed into the server.
        A provider still has to be added and configured in the web UI; this
        only decides whether it can be.

        Providers listed in the package's `providersBuiltins` are always
        available and do not need to be repeated here.
      '';
      example = ["jellyfin" "spotify"];
    };

    airplay2 = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Build the AirPlay receiver against AirPlay 2 rather than classic
        AirPlay, so senders can group it with their other AirPlay 2 speakers.

        This costs a second daemon: AirPlay 2 derives its timing from
        {command}`nqptp`, which has to hold UDP 319 and 320 exclusively and is
        started alongside Music Assistant. Turn it off to fall back to the
        classic receiver, which needs neither.

        Only meaningful with the `airplay_receiver` provider.
      '';
    };

    enableTraefik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Traefik reverse proxy for Music Assistant.";
    };

    authentik = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Put Music Assistant behind Authentik forward auth. It has an account
        system of its own, so this is a second gate rather than the only one.
      '';
    };

    lanBypass = options.mkOption {
      type = types.listOf types.str;
      default = ["127.0.0.1/32" "::1/128" "10.0.0.0/24" "fdb1:d67d:2e17::/48"];
      description = ''
        Client ranges reaching Music Assistant without Authentik.

        Home Assistant's config flow authenticates by redirecting the browser
        to this host and reading back a token from the query string; a
        forward-auth challenge landing mid-redirect breaks the exchange. The
        loopback entries cover Home Assistant's own connection if it is
        pointed at the public URL rather than straight at the port.

        No forward-auth trust is placed in `X-Forwarded-For` anywhere, so
        Traefik matches these against the real peer address and an outside
        client cannot claim one of them.

        As with Spoolman this deliberately omits the ISP-delegated IPv6
        prefix that `rat.networking.lanRanges` carries: a stale delegation
        here would hand a stranger's /64 a bypass around the outer gate.
      '';
    };

    openPortsFrom = options.mkOption {
      type = types.listOf types.str;
      default = ["10.0.0.0/24" "fdb1:d67d:2e17::/48"];
      description = ''
        Source ranges allowed to reach Music Assistant directly rather than
        through Traefik: the web/API port it advertises over mDNS, the audio
        stream port every player fetches from, the AirPlay, AirPlay receiver
        and Sendspin listeners, the PTP ports AirPlay 2 clocks against, and the
        ephemeral ranges AirPlay's RTP sockets and Spotify's pairing endpoint
        draw from. None of those can stay on loopback.

        These ranges are already exempt from Authentik via
        {option}`lanBypass`, so the direct path grants them nothing the
        proxied one does not.
      '';
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      # Both ports are compiled in -- `DEFAULT_PORT` in the server's
      # constants, and a fixed stream port -- and neither takes a flag, so
      # they are pinned rather than hashed. Declaring them still gets the
      # port-conflict assertion and a URL for Traefik.
      links.music-assistant = {
        protocol = "http";
        port = 8095;
      };

      links.music-assistant-stream = {
        protocol = "http";
        port = 8097;
      };

      services.music-assistant = {
        enable = true;
        inherit (cfg) providers;
        # The upstream flag opens every player port on every address the host
        # answers on, including the routable IPv6 prefix. AirPlay's share of
        # that is the whole ephemeral UDP range.
        openFirewall = false;
      };

      rat.networking.scopedPorts = [
        {
          sources = cfg.openPortsFrom;
          ports =
            [
              # Advertised over mDNS as _mass._tcp, which is how Home Assistant
              # and the mobile app find the server -- discovery hands out this
              # port, so leaving it proxy-only advertises a dead address.
              config.links.music-assistant.port
              config.links.music-assistant-stream.port
            ]
            ++ lib.optional (enabled "airplay") 7000
            ++ lib.optional (enabled "sendspin") 8927;
        }
        {
          sources = cfg.openPortsFrom;
          protocol = "udp";
          # libraop picks its RTP timing and control sockets out of the
          # ephemeral range and the speaker answers to whichever it drew. An
          # AirPlay 2 session's control socket is bound the same way, by asking
          # for port 0 rather than from `udp_port_base`.
          portRanges = lib.optional (enabled "airplay" || airplay2) {
            from = 32768;
            to = 65535;
          };
        }
        {
          sources = cfg.openPortsFrom;
          # shairport-sync's RTSP port is `7000 + hash(instance_id) % 1000`,
          # and Python salts `hash` per process, so a receiver lands somewhere
          # else in that span every time the server restarts.
          portRanges = lib.optional (enabled "airplay_receiver") {
            from = 7000;
            to = 7999;
          };
        }
        {
          sources = cfg.openPortsFrom;
          protocol = "udp";
          # The audio, control and timing sockets of a classic AirPlay
          # session, from shairport-sync's `udp_port_base` and `udp_port_range`
          # defaults -- the generated config leaves both alone. An AirPlay 2
          # build still needs them, because a sender can drop back to classic.
          portRanges = lib.optional (enabled "airplay_receiver") {
            from = 6001;
            to = 6010;
          };
        }
        {
          sources = cfg.openPortsFrom;
          protocol = "udp";
          # nqptp's PTP sockets. The sender is the clock master and drives the
          # whole AirPlay 2 timing exchange over these, so a session set up
          # over the RTSP port still fails without them.
          ports = lib.optionals airplay2 [319 320];
        }
        {
          sources = cfg.openPortsFrom;
          # The Spotify app reaches librespot's zeroconf endpoint to list and
          # pair the device, and either librespot build draws that port from
          # the ephemeral range on every launch -- neither provider pins it, so
          # there is nothing narrower to open. An AirPlay 2 session's event,
          # data and buffered-audio sockets are bound the same way.
          portRanges = lib.optional (enabled "spotify" || enabled "spotify_connect" || airplay2) {
            from = 32768;
            to = 65535;
          };
        }
      ];

      # DynamicUser puts the state directory at /var/lib/private behind a
      # symlink, owned by a UID allocated at runtime -- so impermanence would
      # persist the symlink and bind-mount against a UID that does not match.
      # Losing this directory costs the library database and every provider's
      # stored credentials.
      systemd.services.music-assistant.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "music-assistant";
        Group = "music-assistant";
        StateDirectoryMode = "0700";

        # Restores what DynamicUser implied. The rest of the upstream
        # hardening is set explicitly there and survives on its own.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        RemoveIPC = true;

        # shairport-sync reaches avahi over the D-Bus system socket to publish
        # the receiver. The classic build would quietly fall back to its own
        # bundled responder and leave two of them answering for this host; the
        # AirPlay 2 build has no fallback at all.
        RestrictAddressFamilies = lib.optionals (enabled "airplay_receiver") ["AF_UNIX"];
      };

      users.users.music-assistant = {
        isSystemUser = true;
        group = "music-assistant";
        home = stateDir;
      };
      users.groups.music-assistant = {};
    })

    (modules.mkIf (cfg.enable && airplay2) {
      systemd.services.music-assistant = {
        # The provider takes whichever `shairport-sync` PATH resolves first, so
        # putting ours in front leaves the classic build the upstream module
        # adds sitting behind it, unused. The two share nearly all of their
        # dependencies, so keeping both costs little more than the binary.
        path = modules.mkBefore [shairportSync];

        # shairport-sync probes for the clock once at startup and quietly
        # settles for classic AirPlay if nothing answers, so a receiver that
        # came up first would advertise itself as AirPlay 1 and stay that way.
        after = ["nqptp.service"];
        wants = ["nqptp.service"];
      };

      # shairport-sync reads the sender's clock out of a /dev/shm segment this
      # daemon owns and steers it over UDP 9000 on loopback. The segment is
      # world-readable, so the two need no shared user, but they do need the
      # same /dev/shm -- which is why neither may isolate it.
      systemd.services.nqptp = {
        description = "NQPTP PTP clock monitor for AirPlay 2";
        documentation = ["https://github.com/mikebrady/nqptp"];

        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          ExecStart = lib.getExe pkgs.nqptp;
          DynamicUser = true;

          # 319 and 320 are privileged, and nothing but this daemon may hold
          # them -- a second PTP service on the host breaks AirPlay 2 outright.
          AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
          CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];

          # It asks for SCHED_FIFO to keep its clock samples evenly spaced, so
          # `RestrictRealtime` stays off here.
          LimitRTPRIO = 6;

          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
          RestrictNamespaces = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = ["@system-service" "~@privileged"];
          UMask = "0022";
        };
      };
    })

    (modules.mkIf (cfg.enable && cfg.enableTraefik) {
      rat.services.traefik.routes.music-assistant = {
        enable = true;
        inherit (cfg) subdomain authentik;
        authentikBypassFrom = cfg.lanBypass;
        serviceUrl = config.links.music-assistant.url;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = stateDir;
            user = "music-assistant";
            group = "music-assistant";
          }
        ];
      };
    })
  ];
}
