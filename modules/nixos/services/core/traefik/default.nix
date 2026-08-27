{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.traefik;
  inherit (config.rat.services) domainName;

  # Shared by a route's main router and its Authentik-bypass twin, so the two
  # can never drift apart on host or path matching.
  routeRule = route: let
    hostRule =
      if route.subdomain != null
      then "Host(`${route.subdomain}.${domainName}`)"
      else "Host(`${domainName}`)";
    pathRule =
      if route.pathRegex != null
      then "&& PathRegexp(`${route.pathRegex}`)"
      else if route.path != null
      then "&& PathPrefix(`${route.path}`)"
      else "";
  in "${hostRule} ${pathRule}";
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
            type = types.nullOr types.str;
            description = "Subdomain for the service. Use null to serve at the root domain.";
          };
          path = options.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Subpath for the service (e.g., /api). Use null to serve at the root path.";
          };
          pathRegex = options.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Regular expression for matching the path.
              Takes precedence over `path` if both are specified.
              Example: "^/api/v[0-9]+/users/[0-9]+$"
            '';
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
          authentikBypassFrom = options.mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              Client IP ranges that reach the service without passing Authentik
              forward auth, as an additional higher-priority router.

              For backends whose clients cannot answer a forward-auth
              challenge. The ranges are only as trustworthy as the network they
              name, so the backend is fully exposed to anything inside them.

              Has no effect unless {option}`authentik` is enabled.
            '';
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
          stripPrefix = options.mkOption {
            type = types.bool;
            default = false;
            description = "Whether to strip the path prefix before forwarding the request.";
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
      };
    };

    services.traefik = {
      enable = true;

      staticConfigOptions = {
        entryPoints = {
          # Override the upstream module's default `http` entrypoint
          http = lib.mkForce {};

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
            transport = {
              respondingTimeouts = {
                readTimeout = 0;
              };
            };
          };

          metrics = {
            address = "127.0.0.1:${toString config.links.traefik-metrics.port}";
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
        tls.certificates = [
          {
            certFile = "/var/lib/acme/${domainName}-rsa4096/fullchain.pem";
            keyFile = "/var/lib/acme/${domainName}-rsa4096/key.pem";
          }
          {
            certFile = "/var/lib/acme/${domainName}-ec256/fullchain.pem";
            keyFile = "/var/lib/acme/${domainName}-ec256/key.pem";
          }
        ];

        http = {
          middlewares = lib.mkMerge [
            {
              authentik = {
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
            }
            (
              lib.concatMapAttrs (
                name: route:
                  if (route.enable && route.stripPrefix && route.path != null)
                  then {
                    "${name}-stripprefix" = {
                      stripPrefix = {
                        prefixes = [route.path];
                      };
                    };
                  }
                  else {}
              )
              cfg.routes
            )
          ];

          routers = lib.mkMerge [
            (
              lib.mapAttrs (
                name: route:
                  modules.mkIf route.enable {
                    rule = routeRule route;
                    service = name;
                    entryPoints = ["websecure"];
                    tls = true;
                    middlewares =
                      (lib.optionals route.authentik ["authentik"])
                      ++ (lib.optionals (route.stripPrefix && route.path != null) ["${name}-stripprefix"])
                      ++ route.extraMiddlewares;
                  }
                  // (lib.optionalAttrs (route.priority != null) {inherit (route) priority;})
              )
              cfg.routes
            )

            (
              lib.concatMapAttrs (
                name: route:
                  if (route.enable && route.authentik && route.authentikBypassFrom != [])
                  then {
                    "${name}-bypass" =
                      {
                        # ClientIP takes one range per call, so several are ORed.
                        rule = "${routeRule route} && (${
                          lib.concatMapStringsSep " || " (range: "ClientIP(`${range}`)") route.authentikBypassFrom
                        })";
                        service = name;
                        entryPoints = ["websecure"];
                        tls = true;
                        middlewares =
                          (lib.optionals (route.stripPrefix && route.path != null) ["${name}-stripprefix"])
                          ++ route.extraMiddlewares;
                      }
                      # Traefik ranks equal-priority routers by rule length, and
                      # this rule is strictly longer than the one it shadows, so
                      # it already wins by default. An explicit priority on the
                      # route would break that, hence the +1.
                      // (lib.optionalAttrs (route.priority != null) {priority = route.priority + 1;});
                  }
                  else {}
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

    security.acme.certs."${domainName}-rsa4096" = {
      domain = domainName;
      extraDomainNames = [
        "*.${domainName}"
      ];
      extraLegoFlags = ["--key-type=rsa4096"];
      group = "traefik";
    };

    security.acme.certs."${domainName}-ec256" = {
      domain = domainName;
      extraDomainNames = [
        "*.${domainName}"
      ];
      extraLegoFlags = ["--key-type=ec256"];
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
