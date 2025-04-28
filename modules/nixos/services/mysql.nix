{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) options modules;
  cfg = config.rat.services.mysql;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.mysql = {
    enable = options.mkEnableOption "MySQL-compatible database (actually running MariaDB)";
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.mysql = {
        enable = true;
        package = pkgs.mariadb;
        settings = {
          mysqld = {
            character_set_server = "utf8mb4";
            collation_server = "utf8mb4_unicode_ci";
            bind-address = config.links.mysql.ipv4;
            inherit (config.links.mysql) port;
          };
        };
      };

      links.mysql = {
        protocol = "mysql";
        ipv4 = "127.0.0.1";
        port = 3306;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = config.services.mysql.dataDir;
          user = "mysql";
          group = "mysql";
        }
      ];
    })
  ];
}
