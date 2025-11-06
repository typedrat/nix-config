{osConfig, ...}: {
  imports = [
    ./cli
    ./gui
    ./theming
    ./accounts.nix
    ./mime.nix
    ./packages.nix
    ./rclone.nix
    ./sops.nix
  ];

  config = {
    # Trim old Nix generations to free up space.
    nix.gc = {
      automatic = true;
      persistent = true;
      dates = "daily";
      options = "--delete-older-than 30d";
    };

    systemd.user.sessionVariables = {
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      TZ = osConfig.time.timeZone;
      VIZIO_IP = "viziocastdisplay.lan";
      VIZIO_AUTH = "Zmge7tbkiz";
    };

    programs.home-manager.enable = true;
    programs.git = {
      enable = true;
      lfs.enable = true;

      settings = {
        user = {
          name = "Alexis Williams";
          email = "alexis@typedr.at";
        };

        init = {
          defaultBranch = "master";
        };

        push = {
          autoSetupRemote = true;
        };
      };
    };
    services.ssh-agent.enable = true;

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";

    home.stateVersion = "25.05";
  };
}
