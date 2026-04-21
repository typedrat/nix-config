{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.torrents;
  crossSeedCfg = config.rat.services.cross-seed;
  impermanenceCfg = config.rat.impermanence;

  shareLimitActionType = types.enum [
    "Default"
    "Stop"
    "Remove"
    "RemoveWithContent"
    "EnableSuperSeeding"
  ];
  shareLimitsModeType = types.enum [
    "Default"
    "MatchAny"
    "MatchAll"
  ];

  categoryModule = types.submodule {
    options = {
      savePath = options.mkOption {
        type = types.str;
        description = "Save path relative to downloadDir.";
      };
      downloadPath = options.mkOption {
        type = types.nullOr (types.either types.bool types.str);
        default = null;
        description = ''
          Download path for the category.
          - `null`: inherit from global setting
          - `false`: download path disabled
          - `"string"`: download path enabled with that path
        '';
      };
      ratioLimit = options.mkOption {
        type = types.nullOr types.number;
        default = null;
        description = "Ratio limit. -2 = global default, -1 = no limit, positive = ratio limit. null = omit (use default).";
      };
      seedingTimeLimit = options.mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Seeding time limit in minutes. -2 = global default, -1 = no limit. null = omit.";
      };
      inactiveSeedingTimeLimit = options.mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Inactive seeding time limit in minutes. -2 = global default, -1 = no limit. null = omit.";
      };
      shareLimitAction = options.mkOption {
        type = types.nullOr shareLimitActionType;
        default = null;
        description = "Action when share limit is reached. null = omit (use default).";
      };
      shareLimitsMode = options.mkOption {
        type = types.nullOr shareLimitsModeType;
        default = null;
        description = "How share limits are evaluated. null = omit (use default).";
      };
    };
  };

  # Build one category's JSON value, filtering out null optional fields.
  mkCategoryJSON = cat: let
    base = {
      save_path = "${toString cfg.downloadDir}/${cat.savePath}";
    };
    optionals = lib.filterAttrs (_: v: v != null) {
      download_path = cat.downloadPath;
      ratio_limit = cat.ratioLimit;
      seeding_time_limit = cat.seedingTimeLimit;
      inactive_seeding_time_limit = cat.inactiveSeedingTimeLimit;
      share_limit_action = cat.shareLimitAction;
      share_limits_mode = cat.shareLimitsMode;
    };
  in
    base // optionals;
in {
  options.rat.services.torrents = {
    enable = options.mkEnableOption "Torrent services";
    downloadDir = options.mkOption {
      type = types.path;
      description = "Directory for downloaded files";
    };
    subdomain = options.mkOption {
      type = types.str;
      default = "qbittorrent";
      description = "The subdomain for the Web UI interface.";
    };
    categories = options.mkOption {
      type = types.attrsOf categoryModule;
      default = {};
      description = "qBittorrent download categories. Keys are used as the category name in qBittorrent. savePath is relative to downloadDir.";
    };
  };

  config = let
    categoriesFile = pkgs.writeText "categories.json" (
      builtins.toJSON (lib.mapAttrs (_: mkCategoryJSON) cfg.categories)
    );
  in
    modules.mkMerge [
      (modules.mkIf cfg.enable {
        services.qbittorrent = {
          enable = true;
          group = "media";

          torrentingPort = config.links.qbittorrent.port;
          webuiPort = config.links.qbittorrent-webui.port;
          openFirewall = true;

          serverConfig = {
            Application = {
              MemoryWorkingSetLimit = 4096;
            };

            BitTorrent.Session = {
              AddTorrentStopped = false;
              AsyncIOThreadsCount = 112;
              CheckingMemUsageSize = 1024;
              ConnectionSpeed = 200;
              DefaultSavePath = "/mnt/media/torrents";
              DisableAutoTMMByDefault = false;
              DisableAutoTMMTriggers.CategorySavePathChanged = false;
              DiskQueueSize = 4194304;
              FilePoolSize = 5000;
              HashingThreadsCount = 14;
              MaxConnections = -1;
              MaxConnectionsPerTorrent = -1;
              MaxUploads = -1;
              MaxUploadsPerTorrent = -1;
              Port = 42069;
              QueueingSystemEnabled = false;
              RequestQueueSize = 2000;
              ResumeDataStorageType = "SQLite";
              SendBufferLowWatermark = 1024;
              SendBufferWatermark = 4096;
              SendBufferWatermarkFactor = 100;
              SuggestMode = true;
            };

            LegalNotice.Accepted = true;

            Preferences = {
              General.Locale = "en";
              WebUI = {
                Enabled = true;
                LocalHostAuth = false;
                AlternativeUIEnabled = true;
                RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
                ReverseProxySupportEnabled = false;
              };
            };
          };
        };

        systemd.services.qbittorrent.restartTriggers = [categoriesFile];

        systemd.tmpfiles.settings.qbittorrent-categories = modules.mkIf (cfg.categories != {}) {
          "${config.services.qbittorrent.profileDir}/qBittorrent/config/categories.json"."C+" = {
            mode = "600";
            inherit (config.services.qbittorrent) user;
            inherit (config.services.qbittorrent) group;
            argument = toString categoriesFile;
          };
        };

        links = {
          qbittorrent = {
            protocol = "tcp";
            port = 42069;
          };
          qbittorrent-webui = {
            protocol = "http";
          };
        };

        rat.services.traefik.routes.qbittorrent-webui = {
          enable = true;
          inherit (cfg) subdomain;
          serviceUrl = config.links.qbittorrent-webui.url;

          authentik = true;
          theme-park.app = "vuetorrent";
        };
      })
      (modules.mkIf (cfg.enable && crossSeedCfg.enable) {
        services.qbittorrent.serverConfig.AutoRun = {
          enabled = true;
          program = "${config.sops.templates."trigger-cross-seed.sh".path} %I";
        };

        sops.templates."trigger-cross-seed.sh" = {
          content = ''
            #!${pkgs.bash}/bin/sh
            ${lib.getExe pkgs.curl} -XPOST "${config.links.cross-seed.url}/api/webhook?apikey=${
              config.sops.placeholder."cross-seed/apiKey"
            }" -d "infoHash=$1" -d "includeSingleEpisodes=true"
          '';
          owner = config.services.qbittorrent.user;
          inherit (config.services.qbittorrent) group;
          mode = "0700";
        };
      })
      (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
        environment.persistence.${impermanenceCfg.persistDir} = {
          directories = [
            {
              directory = config.services.qbittorrent.profileDir;
              inherit (config.services.qbittorrent) user group;
            }
          ];
        };
      })
    ];
}
