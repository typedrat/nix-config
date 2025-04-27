{
  config,
  lib,
  ...
}: let
  inherit (lib) lists modules;
  impermanenceCfg = config.rat.impermanence;
in {
  config = {
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "alexis+acme@typedr.at";
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        environmentFile = config.sops.secrets."acme-env".path;
      };
    };

    sops.secrets."acme-env" = {
      format = "dotenv";
      sopsFile = ../../../secrets/acme.env;
    };

    environment.persistence.${impermanenceCfg.persistDir} =
      modules.mkIf
      (impermanenceCfg.enable && (lists.length (builtins.attrNames config.security.acme.certs) > 0)) {
        directories = [
          {
            directory = "/var/lib/acme";
            user = "acme";
            group = "acme";
            mode = "0755";
          }
        ];
      };
  };
}
