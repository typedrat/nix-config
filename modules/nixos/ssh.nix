{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.ssh.enable =
    mkEnableOption "ssh"
    // {
      default = true;
    };

  config = mkIf config.rat.ssh.enable {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };

      extraConfig = ''
        AllowAgentForwarding = yes
      '';
    };

    programs.ssh = {
      startAgent = true;
    };
  };
}
