{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options) mkEnableOption;
in {
  imports = [
    ./lanzaboote.nix
  ];

  options.rat.boot.systemd-boot.enable =
    mkEnableOption "`systemd-boot`"
    // {
      default = true;
    };

  config = mkMerge [
    {
      boot.loader.systemd-boot = {
        enable = config.rat.boot.systemd-boot.enable;
        configurationLimit = 10;
      };

      boot.loader.timeout = 1;
      boot.loader.efi.canTouchEfiVariables = true;
    }

    (mkIf config.rat.boot.systemd-boot.enable {
      assertions = [
        {
          assertion = !config.boot.loader.lanzaboote.enable;
          message = "Lanzaboote requires that `systemd-boot` not be enabled.";
        }
      ];
    })
  ];
}
