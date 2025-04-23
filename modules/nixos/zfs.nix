{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.zfs.enable = mkEnableOption "ZFS";

  config = mkIf config.rat.zfs.enable {
    boot.extraModulePackages = [
      config.boot.kernelPackages.${pkgs.zfs.kernelModuleAttribute}
    ];

    boot.supportedFilesystems = ["zfs"];
  };
}
