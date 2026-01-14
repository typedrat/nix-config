{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.rat.impermanence;
  zfsCfg = config.rat.zfs;
in {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  options.rat.impermanence = {
    enable = mkEnableOption "impermanence";

    persistDir = mkOption {
      type = types.str;
      default = "/persist";
      description = "The path of the persist directory.";
    };

    zfs.enable = mkEnableOption "impermanence by ZFS snapshot";
    zfs.snapshotName = mkOption {
      type = types.str;
      default = "blank";
      description = "The name of the ZFS snapshot to restore.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      environment.persistence.${cfg.persistDir} = {
        enable = true;
        hideMounts = true;

        files = [
          "/etc/machine-id"
          "/var/lib/systemd/random-seed"
        ];

        directories = [
          "/var/log"
          "/var/lib/nixos"
          "/var/lib/systemd/coredump"
          "/var/lib/systemd/timers"
          "/var/lib/systemd/timesync"
          "/var/lib/systemd/rfkill"
          "/var/lib/dhcpcd"
          "/var/lib/lastlog"
        ];
      };

      # Disable sudo lecture
      security.sudo.extraConfig = "Defaults lecture=never";
    })

    (mkIf (cfg.enable && cfg.zfs.enable) {
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.services.rollback = {
        description = "Rollback root filesystem to a pristine state";
        wantedBy = ["initrd.target"];
        after = ["zfs-import-${zfsCfg.rootPool}.service"];
        before = ["sysroot.mount"];
        path = [zfsCfg.package];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          zfs rollback -r ${zfsCfg.rootPool}/${zfsCfg.rootDataset}@${cfg.zfs.snapshotName} && echo " >> >> Rollback Complete << <<"
        '';
      };
    })
  ];
}
