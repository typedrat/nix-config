{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./home-assistant.nix
    ./service-user.nix
    ./sillytavern.nix
    ./sr-iov.nix
    ./zfspv-pool.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_hardened;

  disko.devices.disk.main.device = "/dev/disk/by-id/ata-ADATA_SU800_2L412L2HHEK9";

  networking.hostName = "iserlohn";
  networking.hostId = "8425e349";

  rat = {
    # Xeon Gold 6132
    hardware.cpu = {
      cores = 14;
      threads = 28;
    };

    boot.loader = "lanzaboote";

    hardware.nvidia = {
      enable = true;
      open = false;
      powerManagement.enable = false;
      cuda.enable = true;
    };

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
    deployment = {
      enable = true;
      flakeRef = "typedrat/nix-config/0.1";
      operation = "switch";
      webhook.enable = true;
      polling.enable = true;
      rollback.enable = true;
    };

    services = {
      domainName = "thisratis.gay";

      authentik = {
        enable = true;
        ldap.enable = true;
      };

      grafana.enable = true;
      librespeed.enable = true;
      loki.enable = true;
      jellyfin.enable = true;
      mysql.enable = true;

      traefik = {
        enable = true;

        routes.deploy-webhook = {
          enable = true;
          subdomain = "iserlohn-webhook";
          serviceUrl = "http://127.0.0.1:9876";
          authentik = false;
        };
      };

      postgres.enable = true;

      prometheus = {
        enable = true;
        exporters.ipmi.enable = true;
      };

      attic.enable = false;

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
      dispatcharr.enable = true;
      lidarr.enable = true;
      prowlarr.enable = true;
      radarr.enable = true;
      radarr.anime.enable = true;

      romm = {
        enable = true;
        storageDir = "/mnt/media/games/library";

        metadataProviders = {
          hasheous.enable = true;
          igdb.enable = true;
          screenscraper.enable = true;
          steamgriddb.enable = true;
          retroachievements.enable = true;

          flashpoint.enable = true;
          hltb.enable = true;
        };
      };

      shoko.enable = true;
      sonarr.enable = true;
      style-search.enable = true;
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

    users.boldingd = {
      enable = true;
      gui.enable = false;
    };

    users.sioned = {
      enable = true;
      gui.enable = false;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}
