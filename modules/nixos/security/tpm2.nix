{
  config,
  self,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkOption mkEnableOption;
  cfg = config.rat.security.tpm2;
in {
  imports = [
    self.nixosModules.ensure-pcr
  ];

  options.rat.security.tpm2 = {
    enable = mkEnableOption "TPM2 support";

    systemIdentity = {
      enable = mkEnableOption "system identity verification";
      pcr15 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "PCR15 value for system identity verification";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      security.tpm2 = {
        enable = true;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
      };

      environment.systemPackages = [
        pkgs.tpm2-tools
      ];
    })
    (mkIf cfg.systemIdentity.enable {
      systemIdentity = {
        enable = true;
        pcr15 = cfg.systemIdentity.pcr15;
      };
    })
  ];
}
