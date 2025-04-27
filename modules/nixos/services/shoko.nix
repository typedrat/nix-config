{
  config,
  self',
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.shoko;
  impermanenceCfg = config.rat.impermanence;

  persistentGroup = "shoko-persist";
in {
  imports = [
    "${inputs.nixpkgs-shoko}/nixos/modules/services/misc/shoko.nix"
  ];

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
        package = self'.packages.shoko-dev;
        webui = self'.packages.shoko-webui-dev;
      };

      systemd.services.shoko = {
        preStart = modules.mkForce "";
        serviceConfig.ExtraGroups = ["media" persistentGroup];
      };

      services.mysql = {
        ensureDatabases = ["shoko"];

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

      rat.services.nginx.virtualHosts.${cfg.subdomain} = {
        locations."/" = {
          proxyPass = config.links.shoko.url;
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      users.groups.shoko-persist = {};

      systemd.services.shoko = {
        serviceConfig = {
          # Add the dynamic user to our static supplementary group and the `media` group
          SupplementaryGroups = ["shoko-persist" "media"];

          # Bind mount the persistent directory
          BindPaths = [
            "/persist/var/lib/shoko:/var/lib/private/shoko"
          ];
        };
      };
    })
  ];
}
