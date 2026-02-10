{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.rat.hardware.securityKey;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.hardware.securityKey.enable = mkEnableOption "hardware security key support";

  config = mkMerge [
    (mkIf cfg.enable {
      # Smart card daemon for security key communication
      services.pcscd.enable = true;

      # udev rules for YubiKey
      services.udev.packages = [pkgs.yubikey-personalization];

      # Security key packages
      environment.systemPackages = with pkgs; [
        pcsc-tools
        ccid
        opensc
        yubikey-manager
        yubikey-personalization
        yubico-piv-tool
      ];
    })
    (mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = ["/var/lib/pcscd"];
      };
    })
  ];
}
