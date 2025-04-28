{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.loki;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.loki = {
    enable = options.mkEnableOption "Loki";
    subdomain = options.mkOption {
      type = types.str;
      default = "loki";
      description = "The subdomain for Loki.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.loki = {
        enable = true;
        configuration = {
          server.http_listen_port = config.links.loki.port;
          auth_enabled = false;

          ingester = {
            lifecycler = {
              address = "127.0.0.1";
              ring = {
                kvstore = {
                  store = "inmemory";
                };
                replication_factor = 1;
              };
            };
            chunk_idle_period = "1h";
            max_chunk_age = "1h";
            chunk_target_size = 999999;
            chunk_retain_period = "30s";
          };

          schema_config = {
            configs = [
              {
                from = "2025-01-01";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
          };

          storage_config = {
            tsdb_shipper = {
              active_index_directory = "/var/lib/loki/tsdb-index";
              cache_location = "/var/lib/loki/tsdb-cache";
              cache_ttl = "24h";
            };

            filesystem = {
              directory = "/var/lib/loki/chunks";
            };
          };

          query_scheduler = {
            max_outstanding_requests_per_tenant = 32768;
          };

          querier = {
            max_concurrent = 16;
          };

          limits_config = {
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
          };

          table_manager = {
            retention_deletes_enabled = false;
            retention_period = "0s";
          };

          compactor = {
            working_directory = "/var/lib/loki";
            compactor_ring = {
              kvstore = {
                store = "inmemory";
              };
            };
          };
        };
      };

      links = {
        loki = {
          protocol = "http";
        };
      };

      rat.services.traefik.routes.loki = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.loki.url;
        authentik = true;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.loki.dataDir;
            user = "loki";
            group = "loki";
          }
        ];
      };
    })
  ];
}
