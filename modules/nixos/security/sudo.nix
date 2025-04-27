{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkEnableOption;
  cfg = config.rat.security.sudo;
in {
  options.rat.security.sudo = {
    extendedTimeout.enable = mkEnableOption "extended sudo credential timeout";
    sshAgentAuth.enable = mkEnableOption "SSH agent authentication for sudo";
  };

  config = mkMerge [
    (mkIf cfg.extendedTimeout.enable {
      security.sudo.extraConfig = ''
        Defaults        timestamp_timeout=30
      '';
    })
    (mkIf cfg.sshAgentAuth.enable {
      security.pam = {
        sshAgentAuth.enable = true;
        services.sudo.sshAgentAuth = true;
      };
    })
  ];
}
