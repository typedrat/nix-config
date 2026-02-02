{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
  ];

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            root = {
              end = "-8G";
              content = {
                type = "zfs";
                pool = "zpool";
              };
            };
            swap = {
              size = "100%";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
          };
        };
      };
    };
    zpool = {
      zpool = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "file:///tmp/disk.key";
          acltype = "posixacl";
          canmount = "off";
          dnodesize = "auto";
          normalization = "formD";
          relatime = "on";
          xattr = "sa";
          mountpoint = "none";
        };
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zpool/local/root@blank$' || zfs snapshot zpool/local/root@blank";

        datasets = {
          local = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          safe = {
            type = "zfs_fs";
            options.mountpoint = "none";
            options."com.sun:auto-snapshot" = "true";
          };
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };
          "safe/persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
          };
          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
          };
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;
}
