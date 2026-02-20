{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) types modules;
  cfg = config.rat.services.traefik;
  inherit (config.rat.services) domainName;

  themeParkTheme = "catppuccin-${config.catppuccin.flavor}";
  themeParkPkg = pkgs.theme-park.override {
    themeParkScheme = "https";
    themeParkDomain = "${cfg.theme-park.subdomain}.${domainName}";
  };

  themeParkPlugin = pkgs.fetchFromGitHub {
    owner = "packruler";
    repo = "traefik-themepark";
    rev = "v1.2.2";
    sha256 = "sha256-pUSAKp0bwhAZhjfh4bByLg+CRyDwSoCHn19sPV/aqgE=";
  };
in {
  options.rat.services.traefik.routes = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule (_: {
      options = {
        theme-park = {
          app = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Application name that matches theme-park supported apps (null to disable)";
          };

          addons = lib.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional theme-park addons to apply (e.g. 4k-logo, darker)";
          };

          target = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Target tag for theme-park injection";
          };
        };
      };
    }));
  };

  options.rat.services.traefik.theme-park = {
    subdomain = lib.mkOption {
      type = types.str;
      default = "theme-park";
      description = "Subdomain for hosting theme-park assets";
    };
  };

  config = modules.mkIf cfg.enable {
    services.traefik.static.settings = {
      experimental.localPlugins.themepark = {
        moduleName = "github.com/packruler/traefik-themepark";
      };
    };

    links.theme-park = {
      protocol = "http";
    };

    services.lighttpd = {
      enable = true;
      document-root = "${themeParkPkg}/share/theme-park";
      inherit (config.links.theme-park) port;
      extraConfig = ''
        server.bind = "127.0.0.1"
        server.use-ipv6 = "disable"
        $HTTP["url"] =~ "^/" {
          setenv.add-response-header = (
            "Access-Control-Allow-Origin" => "*"
          )
        }
      '';
    };

    rat.services.traefik.routes.theme-park = {
      enable = true;
      inherit (cfg.theme-park) subdomain;
      serviceUrl = config.links.theme-park.url;
    };

    systemd.services.traefik.preStart = ''
      mkdir -p ${config.services.traefik.dataDir}/plugins-local/src/github.com/packruler
      ln -Tsf ${themeParkPlugin} ${config.services.traefik.dataDir}/plugins-local/src/github.com/packruler/traefik-themepark
    '';

    services.traefik.dynamic.files."config".settings.http.middlewares = lib.mapAttrs' (
      name: route:
        lib.nameValuePair "${name}-theme" {
          plugin.themepark = {
            inherit (route.theme-park) app;
            theme = themeParkTheme;
            baseUrl = "https://${cfg.theme-park.subdomain}.${domainName}";
            target = modules.mkIf (route.theme-park.target != null) route.theme-park.target;
            inherit (route.theme-park) addons;
          };
        }
    ) (lib.filterAttrs (_: route: route.enable && route.theme-park.app != null) cfg.routes);

    services.traefik.dynamic.files."config".settings.http.routers =
      lib.mapAttrs (
        name: route:
          modules.mkIf (route.enable && route.theme-park.app != null) {
            middlewares = ["${name}-theme"] ++ (route.middlewares or []);
          }
      )
      cfg.routes;
  };
}
