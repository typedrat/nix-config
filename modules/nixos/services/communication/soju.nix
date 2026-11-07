{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  inherit (config.rat.services) domainName;
  cfg = config.rat.services.soju;
  hostName = "${cfg.subdomain}.${domainName}";
  certDir = config.security.acme.certs.${hostName}.directory;
  # A static group, because the service's own user is allocated at runtime and
  # so cannot be named as the owner of the certificate.
  certGroup = "soju-tls";
in {
  options.rat.services.soju = {
    enable = options.mkEnableOption "soju, an IRC bouncer";

    subdomain = options.mkOption {
      type = types.str;
      default = "irc";
      description = "The subdomain clients connect to.";
    };

    openPortsFrom = options.mkOption {
      type = types.listOf types.str;
      default = config.rat.networking.lanRanges;
      defaultText = lib.literalExpression "config.rat.networking.lanRanges";
      description = "Source ranges allowed to reach the IRC port.";
    };
  };

  config = modules.mkIf cfg.enable {
    links.soju = {
      protocol = "ircs";
      port = 6697;
    };

    services.soju = {
      enable = true;
      inherit hostName;
      listen = ["ircs://:${toString config.links.soju.port}"];
      tlsCertificate = "${certDir}/fullchain.pem";
      tlsCertificateKey = "${certDir}/key.pem";
      # The on-disk store discards message tags, and the database one is what
      # provides the search index.
      messageStoreDriver = "db";
      extraConfig = ''
        db postgres "host=/run/postgresql dbname=soju"
      '';
    };

    services.postgresql = {
      ensureUsers = [
        {
          name = "soju";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = ["soju"];
    };

    users.groups.${certGroup} = {};

    security.acme.certs.${hostName} = {
      group = certGroup;
      # soju re-reads its certificate on SIGHUP without dropping clients.
      reloadServices = ["soju.service"];
    };

    systemd.services.soju = {
      after = ["acme-${hostName}.service" "postgresql.target"];
      wants = ["acme-${hostName}.service"];
      requires = ["postgresql.target"];
      serviceConfig.SupplementaryGroups = [certGroup];
    };

    rat.networking.scopedPorts = [
      {
        ports = [config.links.soju.port];
        sources = cfg.openPortsFrom;
      }
    ];
  };
}
