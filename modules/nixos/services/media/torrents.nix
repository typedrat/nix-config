{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.torrents;
  impermanenceCfg = config.rat.impermanence;
in {
  imports = [
    "${inputs.nixpkgs-qbittorrent}/nixos/modules/services/torrent/qbittorrent.nix"
  ];

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
  };

  config = modules.mkMerge [
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

          AutoRun = {
            enabled = true;
            program = "${lib.getExe pkgs.curl} -XPOST ${config.links.cross-seed.url}/api/webhook?apikey=${config.sops.secrets."cross-seed/apiKey".path} -d \"infoHash=%I\" -d \"includeSingleEpisodes=true\"";
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

      links = {
        qbittorrent = {
          protocol = "tcp";
          port = 42069;
        };
        qbittorrent-webui = {
          protocol = "http";
        };
      };

      system.activationScripts.symlinkQbitCategories = let
        mkCategory = name: savePath: {
          name = name;
          savePath = "/mnt/media/torrents/${savePath}";
        };

        qbitCategories = pkgs.writeText "categories.json" (builtins.toJSON {
          lidarr = mkCategory "Lidarr" "music";
          lidarr-imported = mkCategory "Lidarr (Imported)" "music";

          sonarr = mkCategory "Sonarr" "tv-shows";
          sonarr-imported = mkCategory "Sonarr (Imported)" "tv-shows";
          sonarr-anime = mkCategory "Sonarr (Anime)" "anime";
          sonarr-anime-imported = mkCategory "Sonarr (Anime - Imported)" "anime";

          radarr = mkCategory "Radarr" "movies";
          radarr-imported = mkCategory "Radarr (Imported)" "movies";
          radarr-anime = mkCategory "Radarr (Anime)" "anime-movies";
          radarr-anime-imported = mkCategory "Radarr (Anime - Imported)" "anime-movies";
        });
      in {
        deps = [];
        text = ''
          source_file="${qbitCategories}"
          target_file="${config.services.qbittorrent.profileDir}/qBittorrent/config/categories.json"
          target_dir="$(${pkgs.coreutils}/bin/dirname "$target_file")"

          echo "Ensuring directory $target_dir exists..."
          ${pkgs.coreutils}/bin/mkdir -p "$target_dir"

          echo "Creating symlink $target_file -> $source_file"
          ${pkgs.coreutils}/bin/ln -sf "$source_file" "$target_file"

          qbitUser="${config.services.qbittorrent.user}"
          qbitGroup="${config.services.qbittorrent.group}"
          ${pkgs.coreutils}/bin/chown "''${qbitUser}:''${qbitGroup}" "$target_dir"
        '';
      };

      rat.services.traefik.routes.qbittorrent-webui = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.qbittorrent-webui.url;

        authentik = true;
        theme-park.app = "vuetorrent";
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
