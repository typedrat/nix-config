{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.music-assistant;
  impermanenceCfg = config.rat.impermanence;

  stateDir = "/var/lib/music-assistant";

  # Reads back the merged list, which is what the upstream module keys its own
  # PATH and hardening off, rather than `cfg.providers` alone.
  enabled = provider: lib.elem provider config.services.music-assistant.providers;
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
        and Sendspin listeners, and the ephemeral ranges AirPlay's RTP sockets
        and Spotify's pairing endpoint draw from. None of those can stay on
        loopback.

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
          # ephemeral range and the speaker answers to whichever it drew.
          portRanges = lib.optional (enabled "airplay") {
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
          # The audio, control and timing sockets of an AirPlay 1 session, from
          # shairport-sync's `udp_port_base` and `udp_port_range` defaults --
          # the generated config leaves both alone.
          portRanges = lib.optional (enabled "airplay_receiver") {
            from = 6001;
            to = 6010;
          };
        }
        {
          sources = cfg.openPortsFrom;
          # The Spotify app reaches librespot's zeroconf endpoint to list and
          # pair the device, and either librespot build draws that port from
          # the ephemeral range on every launch -- neither provider pins it, so
          # there is nothing narrower to open.
          portRanges = lib.optional (enabled "spotify" || enabled "spotify_connect") {
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

        # shairport-sync prefers the avahi mDNS backend and only falls back to
        # its own bundled responder once the D-Bus system socket turns out to
        # be unreachable. Two responders answering for the same host makes
        # discovery a coin flip, so let it reach the avahi already running.
        RestrictAddressFamilies = lib.optionals (enabled "airplay_receiver") ["AF_UNIX"];
      };

      users.users.music-assistant = {
        isSystemUser = true;
        group = "music-assistant";
        home = stateDir;
      };
      users.groups.music-assistant = {};
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
