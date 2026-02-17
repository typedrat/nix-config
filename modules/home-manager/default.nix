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
    ./security-key.nix
    ./skyscraper.nix
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

      xdg.configFile."nixpkgs/config.nix".text = ''
        { allowUnfree = true; }
      '';

      programs.home-manager.enable = true;
      services.ssh-agent.enable = true;

      # Nicely reload system units when changing configs
      systemd.user.startServices = "sd-switch";

      xdg.userDirs = {
        enable = true;
        setSessionVariables = true;
      };

      home.stateVersion = "26.05";
    }

    # Git configuration (only if user has configured it)
    (mkIf (gitCfg.name != null && gitCfg.email != null) {
      programs.git = {
        enable = true;
        lfs.enable = true;

        signing = mkIf (gitCfg.signing.key != null) {
          inherit (gitCfg.signing) key format;
          inherit (gitCfg.signing) signByDefault;
        };

        settings = {
          user = {
            inherit (gitCfg) name;
            inherit (gitCfg) email;
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
