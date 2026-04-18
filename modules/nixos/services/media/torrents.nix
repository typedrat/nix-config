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
      type = types.attrsOf (
        types.submodule {
          options = {
            name = options.mkOption {
              type = types.str;
              description = "Display name for the category in qBittorrent.";
            };
            savePath = options.mkOption {
              type = types.str;
              description = "Save path relative to downloadDir.";
            };
          };
        }
      );
      default = {};
      description = "qBittorrent download categories. Keys are category identifiers, savePath is relative to downloadDir.";
    };
  };

  config = let
    categoriesFile = pkgs.writeText "categories.json" (
      builtins.toJSON (
        lib.mapAttrs (_: cat: {
          inherit (cat) name;
          savePath = "${toString cfg.downloadDir}/${cat.savePath}";
        })
        cfg.categories
      )
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
