{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  gitCfg = userCfg.git or {};
  envCfg = userCfg.environment or {};
in {
  imports = [
    ./cli
    ./gui
    ./theming
    ./accounts.nix
    ./mime.nix
    ./packages.nix
    ./rclone.nix
    ./sops.nix
    ./user-sops-secrets.nix
  ];

  config = mkMerge [
    {
      # Trim old Nix generations to free up space.
      nix.gc = {
        automatic = true;
        persistent = true;
        dates = "daily";
        options = "--delete-older-than 30d";
      };

      systemd.user.sessionVariables = mkMerge [
        {
          SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
          TZ = osConfig.time.timeZone;
        }
        # User-specific environment variables
        (mkIf (envCfg.variables or {} != {}) envCfg.variables)
      ];

      programs.home-manager.enable = true;
      services.ssh-agent.enable = true;

      # Nicely reload system units when changing configs
      systemd.user.startServices = "sd-switch";

      home.stateVersion = "25.05";
    }

    # Git configuration (only if user has configured it)
    (mkIf (gitCfg.name != null && gitCfg.email != null) {
      programs.git = {
        enable = true;
        lfs.enable = true;

        signing = mkIf (gitCfg.signing.key != null) {
          key = gitCfg.signing.key;
          signByDefault = gitCfg.signing.signByDefault;
        };

        settings = {
          user = {
            name = gitCfg.name;
            email = gitCfg.email;
          };

          init = {
            defaultBranch = "master";
          };

          push = {
            autoSetupRemote = true;
          };
        };
      };
    })
  ];
}
