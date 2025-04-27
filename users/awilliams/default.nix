{osConfig, ...}: {
  imports = [
    ./gui
    ./theming
    ./zsh
    ./accounts.nix
    ./cli.nix
    ./devtools.nix
    ./docker.nix
    ./packages.nix
    ./rclone.nix
    ./sops.nix
  ];

  # Trim old Nix generations to free up space.
  nix.gc = {
    automatic = true;
    persistent = true;
    frequency = "daily";
    options = "--delete-older-than 7d";
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
    userName = "Alexis Williams";
    userEmail = "alexis@typedr.at";

    extraConfig = {
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
}
