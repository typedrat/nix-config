{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  envCfg = userCfg.environment or {};
in {
  imports = [
    ./cli
    ./core
    ./gui
    ./hardware
    ./theming
    ./kdeglobals.nix
    ./rclone.nix
  ];

  config = {
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

    home.stateVersion = "26.05";
  };
}
