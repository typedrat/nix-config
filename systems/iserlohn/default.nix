{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./nvidia.nix
    ./service-user.nix
    ./sr-iov.nix
    ./zfspv-pool.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_hardened;

  disko.devices.disk.main.device = "/dev/disk/by-id/ata-ADATA_SU800_2L412L2HHEK9";

  networking.hostName = "iserlohn";
  networking.hostId = "8425e349";

  rat = {
    boot.loader = "lanzaboote";

    impermanence = {
      enable = true;
      zfs.enable = true;
    };

    security = {
      fail2ban.enable = true;

      sudo.sshAgentAuth.enable = true;

      tpm2 = {
        enable = true;

        systemIdentity = {
          enable = true;
          #pcr15 = "46e1efcabe7f172870f1931d9106f02b37a5eae44f213d4d012d881985ea84c4";
        };
      };
    };

    virtualisation.libvirt.enable = true;

    serviceMonitor.enable = true;
    services = {
      domainName = "thisratis.gay";

      authentik = {
        enable = true;
        ldap.enable = true;
      };

      grafana.enable = true;
      loki.enable = true;
      jellyfin.enable = true;
      mysql.enable = true;

      traefik.enable = true;

      postgres.enable = true;

      prometheus = {
        enable = true;
        exporters.ipmi.enable = true;
      };

      attic = {
        enable = true;
        bucket = "typedrat-nix-cache";
      };

      github-runner = {
        enable = true;

        runners = {
          typedrat-nix-config-iserlohn = {
            url = "https://github.com/typedrat/nix-config";
          };
        };
      };

      autobrr.enable = true;
      configarr.enable = true;
      cross-seed.enable = true;
      lidarr.enable = true;
      prowlarr.enable = true;
      radarr.enable = true;
      radarr.anime.enable = true;
      shoko.enable = true;
      sonarr.enable = true;
      sonarr.anime.enable = true;
      torrents = {
        enable = true;
        downloadDir = "/mnt/media/torrents";
      };

      matrix-synapse.enable = true;
      element.enable = true;
      heisenbridge = {
        enable = true;
        owner = "@typedrat:thisratis.gay";
      };

      sillytavern = {
        enable = true;

        thumbnails = {
          enabled = true;
          format = "png";
          quality = 100;
          dimensions = {
            bg = {
              width = 240;
              height = 135;
            };
            avatar = {
              width = 864;
              height = 1280;
            };
          };
        };

        systemExtensions = {
          "Extension-QuickPersona" = pkgs.fetchFromGitHub {
            owner = "SillyTavern";
            repo = "Extension-QuickPersona";
            rev = "14a56d168954ad4a941eb1116cfaa654c8ca8f47";
            sha256 = "sha256-AOJ5UIdJn/8SntlrjPkwWsyxa5gW4xjD8/Xswr+Dmn4=";
          };

          "Extension-TopInfoBar" = pkgs.fetchFromGitHub {
            owner = "SillyTavern";
            repo = "Extension-TopInfoBar";
            rev = "930be54913d90abd90ebd698ddd81affa924e2e1";
            sha256 = "sha256-WWAijTFpfzR5/z4MlNKIpRmQhlbjhxmTJ3s4dAal7qE=";
          };

          "SillyTavern-Dialogue-Colorizer-Plus" = pkgs.fetchFromGitHub {
            owner = "zerofata";
            repo = "SillyTavern-Dialogue-Colorizer-Plus";
            rev = "85c81b5d407d0a1595c8a260d700c4811194ebe7";
            hash = "sha256-PDacujugRYwWiFbul9bnHbe9OAuSMmkj4Z1yqWpys0s=";
          };

          "SillyTavern-LALib" = pkgs.fetchFromGitHub {
            owner = "LenAnderson";
            repo = "SillyTavern-LALib";
            rev = "6715da13bd27d53bab2eaf5a2eb2509825723718";
            hash = "sha256-4mGruD1kJa2asKYOG76ZJtAaHJQ1+pjlts/eEtcEsCQ=";
          };

          "SillyTavern-MessageSummarize" = pkgs.fetchFromGitHub {
            owner = "qvink";
            repo = "SillyTavern-MessageSummarize";
            rev = "b42da1d2e5fd0b4f6a0c6ce941b4f3c5d60ec89b";
            hash = "sha256-jc6+cm79Fr68Pj5DJSha42Oe228qJm9d18RN1180wHc=";
          };

          "SillyTavern-MoonlitEchoesTheme" = pkgs.fetchFromGitHub {
            owner = "RivelleDays";
            repo = "SillyTavern-MoonlitEchoesTheme";
            rev = "16ee42f082eb34485f3ed74c44ea4f638b88254f";
            hash = "sha256-rq0zN6StAN/2JNe9ESOYv6SfiSAygEoj+nl/j+PhnD8=";
          };

          "SillyTavern-MoreFlexibleContinues" = pkgs.fetchFromGitHub {
            owner = "LenAnderson";
            repo = "SillyTavern-MoreFlexibleContinues";
            rev = "569ec3662470600b76e3c3d6a2e1713fdbf7adbf";
            hash = "sha256-N8x9OP6zXIJuF5tkd4fN90Qqe9hBKspARg2UTTXJAMw=";
          };

          "rewrite-extension" = pkgs.fetchFromGitHub {
            owner = "splitclover";
            repo = "rewrite-extension";
            rev = "57fe65ee37a8b76729627de51001ddcb1af22b6d";
            hash = "sha256-TgkOCEhbQ3czu7S2QHdXcLODzoP8nHfQWs/fSekh6wc=";
          };
        };
      };

      home-assistant = {
        enable = true;
        mqtt.enable = true;

        customComponents = with pkgs.home-assistant-custom-components; [
          elegoo_printer
          localtuya
          waste_collection_schedule
        ];

        extraComponents = [
          # Components required to complete the onboarding
          "analytics"
          "google_translate"
          "met"
          "radio_browser"
          "shopping_list"

          # Recommended for fast zlib compression
          # https://www.home-assistant.io/integrations/isal
          "isal"

          # Apple TV
          "apple_tv"

          # Denon AVR
          "denonavr"

          # Electricity Maps
          "co2signal"

          # Enphase
          "enphase_envoy"

          # ESPHome
          "esphome"

          # Jellyfin
          "jellyfin"

          # NWS
          "nws"

          # SMUD
          "opower"

          # Vizio TV
          "vizio"
        ];

        config = {
          default_config = {};

          waste_collection_schedule = {
            sources = [
              {
                name = "ics";
                args = {
                  url = "!secret waste_collection_schedule_url";
                };
              }
            ];
          };
        };
      };
    };

    zfs = {
      enable = true;
      rootPool = "rpool";
      rootDataset = "local/root";
    };

    # User configuration (system-specific overrides)
    users.awilliams = {
      enable = true;
      extraGroups = lib.mkAfter ["libvirtd"];
      gui.enable = false;
    };

    users.sioned = {
      enable = true;
      gui.enable = false;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
