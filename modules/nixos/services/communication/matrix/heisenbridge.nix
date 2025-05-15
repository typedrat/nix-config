{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  inherit (config.rat.services) domainName;
  cfg = config.rat.services.heisenbridge;
  synapseCfg = config.rat.services.matrix-synapse;
in {
  options.rat.services.heisenbridge = {
    enable = options.mkEnableOption "Heisenbridge, a Matrix IRC bridge";

    subdomain = options.mkOption {
      type = types.str;
      default = "matrix-irc";
      description = "The subdomain to use for Heisenbridge";
    };

    owner = options.mkOption {
      type = types.str;
      description = "Matrix ID of the bridge owner in the format @user:domain";
      example = "@admin:example.com";
    };

    identd = {
      port = options.mkOption {
        type = types.port;
        default = 113;
        description = "Port for Identd service";
      };
    };
  };

  config = modules.mkIf (cfg.enable && synapseCfg.enable) {
    links = {
      matrix-irc = {
        protocol = "http";
      };
    };

    rat.services.traefik.routes.matrix-irc = {
      enable = true;
      inherit (cfg) subdomain;
      serviceUrl = config.links.matrix-irc.url;
    };

    services.heisenbridge = {
      enable = true;
      homeserver = "https://${synapseCfg.subdomain}.${domainName}";
      registrationUrl = "https://${cfg.subdomain}.${domainName}";
      inherit (config.links.matrix-irc) port;

      identd = {
        enable = true;
        inherit (cfg.identd) port;
      };

      inherit (cfg) owner;
    };

    services.matrix-synapse.settings.app_service_config_files = [
      "/var/lib/heisenbridge/registration.yml"
    ];

    networking.firewall.allowedTCPPorts = [cfg.identd.port];
  };
}
