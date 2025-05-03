{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) lists modules options;
  cfg = config.rat.services.cross-seed;
  impermanenceCfg = config.rat.impermanence;

  mkCrossSeedSecrets = path: secrets:
    builtins.listToAttrs (builtins.map (secret: {
        name = "cross-seed/${secret}";
        value = {
          sopsFile = path;
          key = secret;
          owner = config.services.cross-seed.user;
          group = config.services.cross-seed.group;
          mode = "0740";
        };
      })
      secrets);
in {
  options.rat.services.cross-seed = {
    enable = options.mkEnableOption "`cross-seed`";
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.rat.services.torrents.enable;
          message = "cross-seed requires torrents to be enabled";
        }
      ];

      services.cross-seed = {
        enable = true;
        group = "media";

        useGenConfigDefaults = true;
        settings = {
          host = config.links.cross-seed.hostname;
          port = config.links.cross-seed.port;

          dataDirs = [
            "/mnt/media/torrents"
          ];

          linkType = "reflink";
          flatLinking = true;
          linkDirs = [
            "/mnt/media/cross-seed"
          ];

          matchMode = "partial";
          seasonFromEpisodes = 2.0 / 3.0;
          ignoreNonRelevantFilesToResume = true;
          maxDataDepth = 3;
          includeNonVideos = true;
          excludeOlder = "450 days";
          excludeRecentSearch = "90 days";
          snatchTimeout = "1m";
          searchTimeout = "5m"; # AnimeBytes is so slow on Prowlarr
        };

        settingsFile = config.sops.templates."cross-seed.json".path;
      };

      systemd.services.cross-seed.serviceConfig = {
        ExecStart = lib.mkForce "${pkgs.cross-seed}/bin/cross-seed daemon --verbose";
      };

      sops.secrets = modules.mkMerge [
        (mkCrossSeedSecrets ../../../../secrets/cross-seed.yaml [
          "apiKey"
        ])
        (mkCrossSeedSecrets ../../../../secrets/arrs.yaml [
          "prowlarr/apiKey"
          "sonarr/apiKey"
          "sonarr-anime/apiKey"
          "radarr/apiKey"
          "radarr-anime/apiKey"
        ])
      ];

      sops.templates."cross-seed.json" = {
        content = builtins.toJSON {
          apiKey = config.sops.placeholder."cross-seed/apiKey";

          torznab =
            builtins.map (id: "${config.links.prowlarr.url}/${builtins.toString id}/api?apikey=${config.sops.placeholder."cross-seed/prowlarr/apiKey"}")
            (lists.range 1 11);

          sonarr = [
            "${config.links.sonarr.url}/?apikey=${config.sops.placeholder."cross-seed/sonarr/apiKey"}"
            "${config.links.sonarr-anime.url}/?apikey=${config.sops.placeholder."cross-seed/sonarr-anime/apiKey"}"
          ];

          radarr = [
            "${config.links.radarr.url}/?apikey=${config.sops.placeholder."cross-seed/radarr/apiKey"}"
            "${config.links.radarr-anime.url}/?apikey=${config.sops.placeholder."cross-seed/radarr-anime/apiKey"}"
          ];

          qbittorrentUrl = config.links.qbittorrent-webui.url;
        };

        owner = config.services.cross-seed.user;
        group = config.services.cross-seed.group;
        restartUnits = ["cross-seed.service"];
      };

      links.cross-seed = {
        protocol = "http";
        port = 2468;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.cross-seed.configDir;
            inherit (config.services.cross-seed) user group;
          }
        ];
      };
    })
  ];
}
