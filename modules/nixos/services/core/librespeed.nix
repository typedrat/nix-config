{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.librespeed;
  impermanenceCfg = config.rat.impermanence;

  inherit (config.rat.services) domainName;
in {
  options.rat.services.librespeed = {
    enable = options.mkEnableOption "LibreSpeed";
    subdomain = options.mkOption {
      type = types.str;
      default = "speed";
      description = "The subdomain for LibreSpeed.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.librespeed = {
        protocol = "http";
      };

      services.librespeed = {
        enable = true;

        frontend = {
          enable = true;
          contactEmail = "admin@${domainName}";
          pageTitle = "LibreSpeed";
          useNginx = false;
        };

        settings = {
          bind_address = "127.0.0.1";
          listen_port = config.links.librespeed.port;
          base_url = "backend";
        };
      };

      rat.services.traefik.routes.librespeed = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.librespeed.url;
        authentik = false;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/librespeed";
            user = "librespeed";
            group = "librespeed";
          }
        ];
      };
    })
  ];
}
