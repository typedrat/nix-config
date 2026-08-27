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
      default = config.rat.networking.lanRanges;
      description = ''
        Client ranges reaching Spoolman without Authentik. Moonraker and the
        slicer tooling send no auth headers and cannot answer a forward-auth
        challenge, so they need an unauthenticated path.

        Everything in these ranges gets read/write access to the whole
        inventory.
      '';
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.spoolman.protocol = "http";

      # inline-snapshot reaches the build as one of FastAPI's test dependencies,
      # and its documentation tests assert that the code samples in the shipped
      # markdown match what the current black emits. They no longer do. The
      # tests skip themselves on every interpreter except 3.12, so nixpkgs'
      # default interpreter never runs them and the breakage is invisible
      # upstream; Spoolman pins 3.12, which is what exposes it. Scoped to
      # Spoolman's own interpreter so nothing else rebuilds.
      nixpkgs.overlays = [
        (_: prev: {
          spoolman = prev.spoolman.override {
            python312 = prev.python312.override {
              packageOverrides = _: pyPrev: {
                inline-snapshot = pyPrev.inline-snapshot.overridePythonAttrs (old: {
                  disabledTestPaths = (old.disabledTestPaths or []) ++ ["tests/test_docs.py"];
                });
              };
            };
          };
        })
      ];

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
