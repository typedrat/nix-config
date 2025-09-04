{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.attic;
  impermanenceCfg = config.rat.impermanence;
in {
  imports = [
    inputs.attic.nixosModules.atticd
  ];

  options.rat.services.attic = {
    enable = options.mkEnableOption "attic";
    subdomain = options.mkOption {
      type = types.str;
      default = "attic";
      description = "The subdomain for attic.";
    };
    bucket = options.mkOption {
      type = types.str;
      description = "The Backblaze B2 bucket name for storage.";
    };
    region = options.mkOption {
      type = types.str;
      default = "us-west-002";
      description = "The Backblaze B2 region.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.atticd = {
        enable = true;
        mode = "monolithic";
        environmentFile = config.sops.templates."attic-env".path;

        settings = {
          listen = "[::]:${toString config.links.attic.port}";

          database = {
            url = "postgresql:///atticd?host=/run/postgresql";
          };

          storage = {
            type = "s3";
            inherit (cfg) region;
            inherit (cfg) bucket;
            endpoint = "https://s3.${cfg.region}.backblazeb2.com";
          };

          chunking = {
            nar-size-threshold = 65536;
            min-size = 16384;
            avg-size = 65536;
            max-size = 262144;
          };

          garbage-collection = {
            default-retention-period = "14d";
          };
        };
      };

      services.postgresql = {
        enable = true;
        ensureDatabases = ["atticd"];
        ensureUsers = [
          {
            name = "atticd";
            ensureDBOwnership = true;
          }
        ];
      };

      sops.templates."attic-env" = {
        content = ''
          ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder."attic/tokenSecret"}
          AWS_ACCESS_KEY_ID=${config.sops.placeholder."attic/b2/keyId"}
          AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."attic/b2/applicationKey"}
        '';
        owner = "atticd";
        group = "atticd";
        mode = "0600";
        restartUnits = ["atticd.service"];
      };

      sops.secrets = {
        "attic/tokenSecret" = {
          sopsFile = ../../../../secrets/attic.yaml;
          key = "tokenSecret";
          owner = "atticd";
          group = "atticd";
          mode = "0600";
        };
        "attic/b2/keyId" = {
          sopsFile = ../../../../secrets/default.yaml;
          key = "b2/keyId";
          owner = "atticd";
          group = "atticd";
          mode = "0600";
        };
        "attic/b2/applicationKey" = {
          sopsFile = ../../../../secrets/default.yaml;
          key = "b2/applicationKey";
          owner = "atticd";
          group = "atticd";
          mode = "0600";
        };
      };

      links = {
        attic = {
          protocol = "http";
        };
      };

      rat.services.traefik.routes.attic = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.attic.url;
      };

      systemd.services.atticd.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "atticd";
        Group = "atticd";
      };

      users = {
        users.atticd = {
          isSystemUser = true;
          home = "/var/lib/atticd";
          createHome = true;
          group = "atticd";
        };

        groups.atticd = {};
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/atticd";
            user = "atticd";
            group = "atticd";
          }
        ];
      };
    })
  ];
}
