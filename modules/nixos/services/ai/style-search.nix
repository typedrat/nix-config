{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.style-search;
  impermanenceCfg = config.rat.impermanence;
in {
  imports = [
    inputs.style-search.nixosModules.default
  ];

  options.rat.services.style-search = {
    enable = options.mkEnableOption "Style Search";

    subdomain = options.mkOption {
      type = types.str;
      default = "style-search";
      description = "The subdomain for Style Search.";
    };

    authentik = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to require Authentik authentication.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.style-search = {
        enable = true;
        host = "127.0.0.1";
        inherit (config.links.style-search) port;
      };

      links.style-search = {
        protocol = "http";
      };

      rat.services.traefik.routes.style-search = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.style-search.url;
        inherit (cfg) authentik;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      users.users.style-search = {
        isSystemUser = true;
        group = "style-search";
        home = "/var/lib/style-search";
      };

      users.groups.style-search = {};

      systemd.services.style-search.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "style-search";
        Group = "style-search";
      };

      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/style-search";
            user = "style-search";
            group = "style-search";
          }
        ];
      };
    })
  ];
}
