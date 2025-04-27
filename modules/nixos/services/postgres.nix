{
  config,
  lib,
  ...
}: let
  inherit (lib) options modules;
  cfg = config.rat.services.postgres;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.postgres = {
    enable = options.mkEnableOption "PostgreSQL";
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.postgresql = {
        enable = config.rat.services.postgres.enable;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/postgresql";
          user = "postgres";
          group = "postgres";
        }
        {
          directory = config.services.postgresql.dataDir;
          user = "postgres";
          group = "postgres";
        }
      ];
    })
  ];
}
