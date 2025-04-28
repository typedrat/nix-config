{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.traefik;
  inherit (config.rat.services) domainName;
in {
  imports = [
    ./theme-park.nix
  ];

  options.rat.services.traefik = {
    enable = options.mkEnableOption "Traefik";
    routes = options.mkOption {
      default = {};
      description = "Traefik routes configuration.";
      type = types.attrsOf (types.submodule (_: {
        options = {
          enable = options.mkEnableOption "Traefik route";
          subdomain = options.mkOption {
            type = types.str;
            description = "Subdomain for the service.";
          };
          serviceUrl = options.mkOption {
            type = types.str;
            description = "Backend service URL (e.g., http://127.0.0.1:8080).";
          };
          authentik = options.mkOption {
            type = types.bool;
            default = false;
            description = "Enable Authentik forward auth.";
          };
          extraMiddlewares = options.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional Traefik middlewares.";
          };
          priority = options.mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Router priority.";
          };
        };
      }));
    };
  };

  config = modules.mkIf cfg.enable {
    links = {
      traefik-http = {
        protocol = "http";
        port = 80;
      };

      traefik-https = {
        protocol = "https";
        port = 443;
      };

      traefik-metrics = {
        protocol = "http";
        port = 9100;
      };
    };

    services.traefik = {
      enable = true;

      staticConfigOptions = {
        entryPoints = {
          web = {
            address = ":80";
            http.redirections.entryPoint = {
              to = "websecure";
              scheme = "https";
              permanent = true;
            };
          };

          websecure = {
            address = ":443";
            http3 = {};
          };

          metrics = {
            address = ":${toString config.links.traefik-metrics.port}";
          };
        };

        api = {
          dashboard = true;
          insecure = false;
        };

        metrics.prometheus = {
          addEntryPointsLabels = true;
          addServicesLabels = true;
          entryPoint = "metrics";
        };

        log = {
          level = "INFO";
        };
      };

      dynamicConfigOptions = {
        tls.stores.default.defaultCertificate = {
          certFile = "/var/lib/acme/${domainName}/fullchain.pem";
          keyFile = "/var/lib/acme/${domainName}/key.pem";
        };

        http = {
          middlewares.authentik = {
            forwardAuth = {
              address = config.links.authentik.url + "/outpost.goauthentik.io/auth/traefik";
              trustForwardHeader = true;
              authResponseHeaders = [
                "X-authentik-username"
                "X-authentik-groups"
                "X-authentik-email"
                "X-authentik-name"
                "X-authentik-uid"
              ];
            };
          };

          routers = lib.mkMerge [
            (
              lib.mapAttrs (
                name: route:
                  modules.mkIf route.enable {
                    rule = "Host(`${route.subdomain}.${domainName}`)";
                    service = name;
                    entryPoints = ["websecure"];
                    tls = true;
                    middlewares = (lib.optionals route.authentik ["authentik"]) ++ route.extraMiddlewares;
                  }
                  // (lib.optionalAttrs (route.priority != null) {inherit (route) priority;})
              )
              cfg.routes
            )

            {
              dashboard = {
                rule = "Host(`traefik.${domainName}`)";
                service = "api@internal";
                entryPoints = ["websecure"];
                tls = true;
                middlewares = ["authentik"];
              };
            }
          ];
          services =
            lib.mapAttrs (
              _name: route:
                modules.mkIf route.enable {
                  loadBalancer.servers = [{url = route.serviceUrl;}];
                }
            )
            cfg.routes;
        };
      };
    };

    # A hack to make Traefik not barf at the sight of plugins
    systemd.services.traefik.serviceConfig.WorkingDirectory = "/var/lib/traefik";

    networking.firewall = {
      allowedTCPPorts = [
        80
        443
      ];
      allowedUDPPorts = [
        443
      ];
    };

    security.acme.certs.${domainName} = {
      extraDomainNames = [
        "*.${domainName}"
      ];
      group = "traefik";
    };

    environment.persistence = lib.mkIf config.rat.impermanence.enable {
      "${config.rat.impermanence.persistDir}".directories = [
        {
          directory = "/var/lib/traefik";
          user = "traefik";
          group = "traefik";
          mode = "0755";
        }
      ];
    };
  };
}
