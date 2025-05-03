{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.rat.ssh;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.ssh = {
    enable = mkEnableOption "ssh" // {default = true;};
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.openssh = {
        enable = true;
        openFirewall = true;
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
    })
    (mkIf impermanenceCfg.enable {
      services.openssh = {
        hostKeys = [
          {
            type = "ed25519";
            path = "${impermanenceCfg.persistDir}/etc/ssh/ssh_host_ed25519_key";
          }
          {
            type = "rsa";
            bits = 4096;
            path = "${impermanenceCfg.persistDir}/etc/ssh/ssh_host_rsa_key";
          }
        ];
      };
    })
  ];
}
