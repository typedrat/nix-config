{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) lists modules options strings;
  cfg = config.rat.services.cross-seed;
  impermanenceCfg = config.rat.impermanence;

  mkCrossSeedSecrets = path: secrets:
    builtins.listToAttrs (builtins.map (secret: {
        name = "cross-seed/${secret}";
        value = {
          sopsFile = path;
          key = secret;
          owner = "rtorrent";
          group = "media";
          mode = "0700";
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
          message = "cross-seed requires rtorrent to be enabled";
        }
      ];

      services.cross-seed = {
        enable = true;
        user = "rtorrent";
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

      systemd.services.cross-seed.serviceConfig.ExecStart = lib.mkForce "${pkgs.cross-seed}/bin/cross-seed daemon --verbose";

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
        (mkCrossSeedSecrets ../../../../secrets/rtorrent.yaml [
          "rtorrent/username"
          "rtorrent/password"
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

          rtorrentRpcUrl = strings.concatStrings [
            "http://"
            "${config.sops.placeholder."cross-seed/rtorrent/username"}:"
            "${config.sops.placeholder."cross-seed/rtorrent/password"}@"
            "${config.links.rtorrent.tuple}/RPC2"
          ];
        };

        owner = config.services.rtorrent.user;
        group = config.services.rtorrent.group;
        restartUnits = ["cross-seed.service"];
      };

      links.cross-seed = {
        protocol = "http";
        port = 2468;
      };

      sops.templates."rtorrent-cross-seed.sh" = {
        content = ''
          #!${pkgs.bash}/bin/sh
          curl -XPOST ${config.links.cross-seed.url}/api/webhook?apikey=${config.sops.placeholder."cross-seed/apiKey"} \
            -d "infoHash=$2" -d "includeSingleEpisodes=true"
        '';
        owner = "rtorrent";
        group = "media";
        mode = "0700";
      };

      services.rtorrent.configText = ''
        method.insert=d.data_path,simple,"if=(d.is_multi_file),(cat,(d.directory),/),(cat,(d.directory),/,(d.name))"
        method.set_key=event.download.finished,cross_seed,"execute={'${config.sops.templates."rtorrent-cross-seed.sh".path}',$d.name=,$d.hash=,$d.data_path=}"
      '';
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
