{
  config,
  self',
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.services.configarr;

  mkConfigarrSecrets = path: secrets:
    builtins.listToAttrs (builtins.map (secret: {
        name = "configarr/${secret}";
        value = {
          sopsFile = path;
          key = secret;
          owner = "configarr";
          group = "configarr";
          mode = "0700";
        };
      })
      secrets);

  configarrYmlTemplate = ''
    trashGuideUrl: https://github.com/TRaSH-Guides/Guides
    recyclarrConfigUrl: https://github.com/recyclarr/config-templates

    sonarr:
      western:
        base_url: ${config.links.sonarr.url}
        api_key: ${config.sops.placeholder."configarr/sonarr/apiKey"}

        quality_definition:
          type: series

        custom_formats:
          - trash_ids:
              - 2b239ed870daba8126a53bd5dc8dc1c8 # DV HDR10+
              - 7878c33f1963fefb3d6c8657d46c2f0a # DV HDR10
              - 6d0d8de7b57e35518ac0308b0ddf404e # DV
              - 1f733af03141f068a540eec352589a89 # DV HLG
              - 27954b0a80aab882522a88a4d9eae1cd # DV SDR
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1500
          - trash_ids:
              - a3d82cbef5039f8d295478d28a887159 # HDR10+
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 600
          - trash_ids:
              - 3497799d29a085e2ac2df9d468413c94 # HDR10
              - 3e2c4e748b64a1a1118e0ea3f4cf6875 # HDR
              - bb019e1cd00f304f80971c965de064dc # HDR (undefined)
              - 2a7e3be05d3861d6df7171ec74cad727 # PQ
              - 17e889ce13117940092308f48b48b45b # HLG
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 500
          - trash_ids:
              - 9b27ab6498ec0f31a3353992e19434ca # DV (WEBDL)
            assign_scores_to:
              - name: TRaSH+ 4K
                score: -10000
          - trash_ids:
              - 85c61753df5da1fb2aab6f2a47426b09 # BR-DISK
              - 9c11cd3f07101cdba90a2d81cf0e56b4 # LQ
              - e2315f990da2e2cbfc9fa5b7a6fcfe48 # LQ (Release Title)
              - fbcb31d8dabd2a319072b84fc0b7249c # Extras
              - 15a05bc7c1a36e2b57fd628f8977e2fc # AV1
            assign_scores_to:
              - name: TRaSH+ 4K
                score: -10000
          - trash_ids:
              - ec8fa7296b64e8cd390a1600981f3923 # Repack/Proper
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 5
          - trash_ids:
              - eb3d5cc0a2be0db205fb823640db6a3c # Repack v2
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 6
          - trash_ids:
              - 44e7c4de10ae50265753082e5dc76047 # Repack v3
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 7
          - trash_ids:
              - f67c9ca88f463a48346062e8ad07713f # ATVP
              - 89358767a60cc28783cdc3d0be9388a4 # DSNP
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 100
          - trash_ids:
              - 81d1fbf600e2540cee87f3a23f9d3c1c # MAX
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 90
          - trash_ids:
              - a880d6abc21e7c16884f3ae393f84179 # HMAX
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 80
          - trash_ids:
              - d660701077794679fd59e8bdf4ce3a29 # AMZN
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 70
          - trash_ids:
              - d34870697c9db575f17700212167be23 # NF
              - 1656adc6d7bb2c8cca6acfb6592db421 # PCOK
              - c67a75ae4a1715f2bb4d492755ba4195 # PMTP
              - 1efe8da11bfd74fbbcd4d8117ddb9213 # STAN
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 60
          - trash_ids:
              - 77a7b25585c18af08f60b1547bb9b4fb # CC
              - 36b72f59f4ea20aad9316f475f2d9fbb # DCU
              - 7a235133c87f7da4c8cccceca7e3c7a6 # HBO
              - f6cce30f1733d5c8194222a7507909bb # HULU
              - 0ac24a2a68a9700bcb7eeca8e5cd644c # iT
              - ae58039e1319178e6be73caab5c42166 # SHO
              - 9623c5c9cac8e939c1b9aedd32f640bf # SYFY
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 50
          - trash_ids:
              - 43b3cf48cb385cd3eac608ee6bca7f09 # UHD Streaming Boost
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 20
          - trash_ids:
              - d2d299244a92b8a52d4921ce3897a256 # UHD Streaming Cut
            assign_scores_to:
              - name: TRaSH+ 4K
                score: -20
          - trash_ids:
              - 9965a052eb87b0d10313b1cea89eb451 # Remux Tier 01
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1900
          - trash_ids:
              - 8a1d0c3d7497e741736761a1da866a2e # Remux Tier 02
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1850
          - trash_ids:
              - d6819cba26b1a6508138d25fb5e32293 # HD Bluray Tier 01
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1800
          - trash_ids:
              - c2216b7b8aa545dc1ce8388c618f8d57 # HD Bluray Tier 02
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1750
          - trash_ids:
              - e6258996055b9fbab7e9cb2f75819294 # WEB Tier 01
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1700
          - trash_ids:
              - 58790d4e2fdcd9733aa7ae68ba2bb503 # WEB Tier 02
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1650
          - trash_ids:
              - d84935abd3f8556dcd51d4f27e22d0a6 # WEB Tier 03
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1600
          - trash_ids:
              - d0c516558625b04b363fa6c5c2c7cfd4 # WEB Scene
            assign_scores_to:
              - name: TRaSH+ 4K
                score: 1600
          - trash_ids:
              - 32b367365729d530ca1c124a0b180c64 # Bad Dual Groups
              - e1a997ddb54e3ecbfe06341ad323c458 # Ofuscated
              - 06d66ab109d4d2eddb2794d21526d140 # Retags
              - 83304f261cf516bb208c18c54c0adf97 # SDR (no WEBDL)
              - 9b64dff695c2115facf1b6ea59c9bd07 # x265 (no HDR/DV)
            assign_scores_to:
              - name: TRaSH+ 4K
                score: -10000

        quality_profiles:
          - name: TRaSH+ 4K
            upgrade:
              allowed: true
              until_quality: WEB 2160p
              until_score: 10000
            min_format_score: 0
            quality_sort: top
            qualities:
              - name: Bluray-2160p Remux
              - name: Bluray-2160p
              - name: WEB 2160p
                qualities:
                  - WEBDL-2160p
                  - WEBRip-2160p
              - name: Bluray-1080p Remux
              - name: Bluray-1080p
              - name: WEB 1080p
                qualities:
                  - WEBDL-1080p
                  - WEBRip-1080p
              - name: HDTV-1080p
              - name: Bluray-720p
              - name: WEB 720p
                qualities:
                  - WEBDL-720p
                  - WEBRip-720p
              - name: HDTV-720p
      anime:
        base_url: ${config.links.sonarr-anime.url}
        api_key: ${config.sops.placeholder."configarr/sonarr-anime/apiKey"}

        include:
          - template: sonarr-quality-definition-series
          - template: sonarr-v4-quality-profile-anime
          - template: sonarr-v4-custom-formats-anime

        custom_formats:
          - trash_ids:
              - 026d5aadd1a6b4e550b134cb6c72b3ca # Uncensored
            assign_scores_to:
              - name: Remux-1080p - Anime
                score: 101

          - trash_ids:
              - b2550eb333d27b75833e25b8c2557b38 # 10bit
            assign_scores_to:
              - name: Remux-1080p - Anime
                score: 0

          - trash_ids:
              - 418f50b10f1907201b6cfdf881f467b7 # Anime Dual Audio
            assign_scores_to:
              - name: Remux-1080p - Anime
                score: 0

    radarr:
      western:
        base_url: ${config.links.radarr.url}
        api_key: ${config.sops.placeholder."configarr/radarr/apiKey"}

        include:
          - template: radarr-quality-definition-movie
          - template: radarr-quality-profile-remux-web-2160p
          - template: radarr-custom-formats-remux-web-2160p

        custom_formats:
          - trash_ids:
              - 496f355514737f7d83bf7aa4d24f8169 # TrueHD Atmos
              - 2f22d89048b01681dde8afe203bf2e95 # DTS X
              - 417804f7f2c4308c1f4c5d380d4c4475 # ATMOS (undefined)
              - 1af239278386be2919e1bcee0bde047e # DD+ ATMOS
              - 3cafb66171b47f226146a0770576870f # TrueHD
              - dcf3ec6938fa32445f590a4da84256cd # DTS-HD MA
              - a570d4a0e56a2874b64e5bfa55202a1b # FLAC
              - e7c2fcae07cbada050a0af3357491d7b # PCM
              - 8e109e50e0a0b83a5098b056e13bf6db # DTS-HD HRA
              - 185f1dd7264c4562b9022d963ac37424 # DD+
              - f9f847ac70a0af62ea4a08280b859636 # DTS-ES
              - 1c1a4c5e823891c75bc50380a6866f73 # DTS
              - 240770601cc226190c367ef59aba7463 # AAC
              - c2998bd0d90ed5621d8df281e839436e # DD
            assign_scores_to:
              - name: Remux + WEB 2160p
          - trash_ids:
              - 0f12c086e289cf966fa5948eac571f44 # Hybrid
              - 570bc9ebecd92723d2d21500f4be314c # Remaster
              - eca37840c13c6ef2dd0262b141a5482f # 4K Remaster
              - e0c07d59beb37348e975a930d5e50319 # Criterion Collection
              - 9d27d9d2181838f76dee150882bdc58c # Masters of Cinema
              - db9b4c4b53d312a3ca5f1378f6440fc9 # Vinegar Syndrome
              - 957d0f44b592285f26449575e8b1167e # Special Edition
              - eecf3a857724171f968a66cb5719e152 # IMAX
              - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
            assign_scores_to:
              - name: Remux + WEB 2160p
          - trash_ids:
              - b6832f586342ef70d9c128d40c07b872 # Bad Dual Groups
              - cc444569854e9de0b084ab2b8b1532b2 # Black and White Editions
              - 90cedc1fea7ea5d11298bebd3d1d3223 # EVO (no WEBDL)
              - 7357cf5161efbf8c4d5d0c30b4815ee2 # Obfuscated
              - 5c44f52a8714fdd79bb4d98e2673be1f # Retags
            assign_scores_to:
              - name: Remux + WEB 2160p
          - trash_ids:
              - dc98083864ea246d05a42df0d05f81cc # x265 (HD)
            assign_scores_to:
              - name: Remux + WEB 2160p
                score: 0
          - trash_ids:
              - 839bea857ed2c0a8e084f3cbdbd65ecb # x265 (no HDR/DV)
            assign_scores_to:
              - name: Remux + WEB 2160p

          - trash_ids:
              - 923b6abef9b17f937fab56cfcf89e1f1 # DV (WEBDL)
            assign_scores_to:
              - name: Remux + WEB 2160p

          - trash_ids:
              - 25c12f78430a3a23413652cbd1d48d77 # SDR (no WEBDL)
            assign_scores_to:
              - name: Remux + WEB 2160p
      anime:
        base_url: ${config.links.radarr-anime.url}
        api_key: ${config.sops.placeholder."configarr/radarr-anime/apiKey"}

        include:
          - template: radarr-quality-definition-movie
          - template: radarr-quality-profile-anime
          - template: radarr-custom-formats-anime

        custom_formats:
          - trash_ids:
              - 064af5f084a0a24458cc8ecd3220f93f # Uncensored
            assign_scores_to:
              - name: Remux-1080p - Anime
                score: 101

          - trash_ids:
              - a5d148168c4506b55cf53984107c396e # 10bit
            assign_scores_to:
              - name: Remux-1080p - Anime
                score: 0

          - trash_ids:
              - 4a3b087eea2ce012fcc1ce319259a3be # Anime Dual Audio
            assign_scores_to:
              - name: Remux-1080p - Anime
                score: 0
  '';
in {
  options.rat.services.configarr = {
    enable = options.mkEnableOption "configarr";
  };

  config = modules.mkIf cfg.enable {
    sops.secrets = mkConfigarrSecrets ../../../../secrets/arrs.yaml [
      "radarr/apiKey"
      "radarr-anime/apiKey"
      "sonarr/apiKey"
      "sonarr-anime/apiKey"
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/configarr/repos 0750 configarr configarr -"
    ];

    sops.templates."configarr.yml" = {
      content = configarrYmlTemplate;
      owner = "configarr";
      group = "configarr";
      mode = "0400";
    };

    users.users.configarr = {
      isSystemUser = true;
      group = "configarr";
      home = "/var/lib/configarr";
      createHome = true;
    };

    users.groups.configarr = {};

    systemd.services.configarr = {
      description = "Configarr service";
      path = [
        pkgs.git
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "configarr";
        Group = "configarr";

        ExecStart = "${self'.packages.configarr}/bin/configarr";
        WorkingDirectory = "/var/lib/configarr";
      };

      environment = {
        CONFIG_LOCATION = "${config.sops.templates."configarr.yml".path}";
      };
    };

    systemd.timers.configarr = {
      description = "Run configarr daily";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "configarr.service";
      };
    };
  };
}
