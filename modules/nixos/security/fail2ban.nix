{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.security.fail2ban;
in {
  options.rat.security.fail2ban = {
    enable = options.mkEnableOption {
      default = false;
      description = "fail2ban";
    };
  };

  config = modules.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        overalljails = true;
        rndtime = "8m";
      };
      jails = {
        sshd.settings = {
          backend = "systemd";
          mode = "aggressive";
        };
      };
    };
  };
}
