{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.spoolman;
  impermanenceCfg = config.rat.impermanence;

  stateDir = "/var/lib/spoolman";
in {
  options.rat.services.spoolman = {
    enable = options.mkEnableOption "Spoolman filament spool inventory";

    subdomain = options.mkOption {
      type = types.str;
      default = "spoolman";
      description = "The subdomain for Spoolman.";
    };

    enableTraefik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Traefik reverse proxy for Spoolman.";
    };

    authentik = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Put Spoolman behind Authentik forward auth. Spoolman has no
        authentication of its own, so this is the only thing between the public
        internet and a writable API.
      '';
    };

    lanBypass = options.mkOption {
      type = types.listOf types.str;
      default = ["10.0.0.0/24" "fdb1:d67d:2e17::/48"];
      description = ''
        Client ranges reaching Spoolman without Authentik. Moonraker and the
        slicer tooling send no auth headers and cannot answer a forward-auth
        challenge, so they need an unauthenticated path.

        Everything in these ranges gets read/write access to the whole
        inventory, so this is deliberately NOT `rat.networking.lanRanges`:
        that list includes the ISP-delegated IPv6 prefix, which rotates on
        re-delegation and has gone stale before. A stray stale prefix here
        would hand a stranger's /64 unauthenticated write access rather than
        just breaking monitoring. Nothing that needs the bypass (the printer,
        ulysses, Home Assistant on loopback) uses a global IPv6 source, and
        the domain has no AAAA records at all.
      '';
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.spoolman.protocol = "http";

      services.spoolman = {
        enable = true;
        listen = config.links.spoolman.ipv4;
        port = config.links.spoolman.port;

        environment = {
          # SQLite is the default, and is what makes the two settings below
          # work at all -- Spoolman's backups are implemented only for it.
          SPOOLMAN_AUTOMATIC_BACKUP = "TRUE";
          SPOOLMAN_DIR_BACKUPS = "${stateDir}/backups";
          SPOOLMAN_METRICS_ENABLED = "TRUE";
        };
      };

      # The upstream module runs this under DynamicUser, which relocates the
      # state directory to /var/lib/private and leaves a symlink behind. That
      # symlink is what impermanence would persist, so the database would not
      # survive a reboot.
      systemd.services.spoolman.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "spoolman";
        Group = "spoolman";
        # spoolman.db and spoolman.log live here.
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = 5;

        # DynamicUser implies ProtectSystem=strict, ProtectHome=read-only,
        # PrivateTmp, NoNewPrivileges, RestrictSUIDSGID and RemoveIPC; forcing
        # it off above drops all of that too, so it's restored explicitly
        # here. AF_INET/AF_INET6 stay allowed and nothing IP-address-scoped is
        # added: Spoolman calls out to donkie.github.io at startup and on a
        # schedule to sync the external filament database.
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

      users.users.spoolman = {
        isSystemUser = true;
        group = "spoolman";
        home = stateDir;
      };
      users.groups.spoolman = {};
    })

    (modules.mkIf (cfg.enable && cfg.enableTraefik) {
      rat.services.traefik.routes.spoolman = {
        enable = true;
        inherit (cfg) subdomain authentik;
        authentikBypassFrom = cfg.lanBypass;
        serviceUrl = config.links.spoolman.url;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = stateDir;
            user = "spoolman";
            group = "spoolman";
          }
        ];
      };
    })
  ];
}
