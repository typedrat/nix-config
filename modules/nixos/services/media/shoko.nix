{
  config,
  inputs',
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.shoko;
  impermanenceCfg = config.rat.impermanence;

  persistentGroup = "shoko-persist";
in {
  options.rat.services.shoko = {
    enable = options.mkEnableOption "Shoko";
    subdomain = options.mkOption {
      type = types.str;
      default = "shoko";
      description = "The subdomain for Shoko";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      rat.services.mysql.enable = true;

      services.shoko = {
        enable = true;
        package = inputs'.nanopkgs.packages.shoko;
        webui = inputs'.nanopkgs.packages.shoko-webui;
      };

      systemd.services.shoko = {
        after = ["mysql.service"];
        preStart = modules.mkForce ''
          mkdir -p /var/lib/shoko/themes
          ln -sf ${inputs.catppuccin-shoko-webui}/themes/*/* /var/lib/shoko/themes/
        '';
        serviceConfig.ExtraGroups = ["media" persistentGroup];
      };

      services.mysql = {
        ensureDatabases = [
          "shoko"
          "shoko-quartz"
        ];

        ensureUsers = [
          {
            name = "shoko";
            ensurePermissions = {
              "shoko.*" = "ALL PRIVILEGES";
            };
          }
        ];
      };

      links.shoko = {
        protocol = "http";
        port = 8111;
      };

      rat.services.traefik.routes.shoko = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.shoko.url;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      users = {
        users.shoko = {
          isSystemUser = true;
          home = "/var/lib/shoko";
          createHome = true;
          group = "shoko";
        };

        groups.shoko = {};
      };

      systemd.services.shoko = {
        serviceConfig = {
          DynamicUser = modules.mkForce false;
          User = "shoko";
          Group = "shoko";
          SupplementaryGroups = ["media"];
        };
      };

      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/shoko";
          user = "shoko";
          group = "shoko";
        }
      ];
    })
  ];
}
