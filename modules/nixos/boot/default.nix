{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.options) mkOption;
in {
  imports = [
    ./lanzaboote.nix
  ];

  options.rat.boot.loader = mkOption {
    default = "systemd-boot";
    type = types.enum ["systemd-boot" "lanzaboote"];
  };

  config = {
    boot.loader.systemd-boot = {
      enable = config.rat.boot.loader == "systemd-boot";
      configurationLimit = 10;
    };

    boot.loader.timeout = 1;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
