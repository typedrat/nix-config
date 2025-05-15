{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.synapse-admin;
  synapseCfg = config.rat.services.matrix-synapse;
in {
  options.rat.services.synapse-admin = {
    enable = options.mkOption {
      type = types.bool;
      default = config.rat.services.matrix-synapse.enable;
      description = "Whether to enable Synapse Admin at the /admin subpath of the Matrix server";
    };

    package = options.mkPackageOption pkgs "synapse-admin-etkecc" {};
  };

  config = modules.mkIf (cfg.enable && synapseCfg.enable) {
    links = {
      synapse-admin = {
        protocol = "http";
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.synapse-admin = {
        listen = [
          {
            addr = config.links.synapse-admin.ipv4;
            inherit (config.links.synapse-admin) port;
          }
        ];

        root = cfg.package;

        locations = {
          "= /".extraConfig = ''
            return 307 /index.html;
          '';

          "~ ^/.*\\.(?:css|js|jpg|jpeg|gif|png|svg|ico|woff|woff2|ttf|eot|webp)$".extraConfig = ''
            expires 30d;
            add_header Cache-Control "public";
          '';

          "/".extraConfig = ''
            try_files $uri $uri/ /index.html;
          '';
        };
      };
    };

    rat.services.traefik.routes.synapse-admin = {
      enable = true;
      inherit (synapseCfg) subdomain;
      path = "/admin";
      serviceUrl = config.links.synapse-admin.url;
      priority = 300;
      stripPrefix = true;
    };
  };
}
