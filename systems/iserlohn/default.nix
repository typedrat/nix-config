{pkgs, ...}: {
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./nvidia.nix
    ./service-user.nix
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

      autobrr.enable = true;
      configarr.enable = true;
      cross-seed.enable = true;
      prowlarr.enable = true;
      radarr.enable = true;
      radarr.anime.enable = true;
      shoko.enable = true;
      sonarr.enable = true;
      sonarr.anime.enable = true;
      torrents = {
        enable = true;
        downloadDir = "/mnt/media/torrents";
        optimizedSettings = true;
      };
    };

    zfs = {
      enable = true;
      rootPool = "rpool";
      rootDataset = "local/root";
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
