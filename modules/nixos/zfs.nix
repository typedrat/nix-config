{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf;
  cfg = config.rat.zfs;
in {
  options.rat.zfs = {
    enable = mkEnableOption "ZFS";

    package = mkPackageOption pkgs "zfs" {};

    rootPool = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The root pool for ZFS.";
    };

    rootDataset = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The root dataset for ZFS.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rootPool != null;
        message = "ZFS root pool is not set";
      }
      {
        assertion = cfg.rootDataset != null;
        message = "ZFS root dataset is not set";
      }
    ];

    boot.extraModulePackages = [
      config.boot.kernelPackages.${cfg.package.kernelModuleAttribute}
    ];

    boot.supportedFilesystems = ["zfs"];

    environment.systemPackages = [
      cfg.package
    ];

    services.zfs = {
      trim.enable = true;
      autoScrub.enable = true;
    };
  };
}
