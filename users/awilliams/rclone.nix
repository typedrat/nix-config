{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib.attrsets) recursiveUpdate;
in {
  programs.rclone = {
    enable = true;

    remotes = rec {
      b2 = {
        config = {
          type = "b2";
        };
        secrets = {
          account = config.sops.secrets."b2/keyId".path;
          key = config.sops.secrets."b2/applicationKey".path;
        };
      };

      workdrive = {
        config = {
          type = "drive";
          service_account_file = config.sops.secrets.work-gdrive-sa-key.path;
          impersonate = config.accounts.email.accounts.Work.address;
          scope = "drive";
        };
      };

      workdrive-shared = recursiveUpdate workdrive {
        config.team_drive = "0AEjPQYC7XEWcUk9PVA";
      };
    };
  };

  sops.secrets = {
    "b2/keyId" = {};
    "b2/applicationKey" = {};
    work-gdrive-sa-key = {
      format = "json";
      sopsFile = ../../secrets/synapdeck-gdrive.json;
      key = "";
    };
  };

  systemd.user.services =
    lib.mapAttrs' (name: _remote: {
      name = "rclone-${name}-mount";
      value = {
        Unit = {
          Description = "Service that connects to ${name} remote";
          After = ["network-online.target" "sops-nix.service"];
        };
        Install.WantedBy = ["default.target"];

        Service = let
          mountDir = "${config.home.homeDirectory}/mnt/${name}";
        in {
          Type = "simple";
          ExecStartPre = "/run/current-system/sw/bin/mkdir -p ${mountDir}";
          ExecStart = "${pkgs.rclone}/bin/rclone mount --vfs-cache-mode full ${name}: ${mountDir}";
          ExecStop = "/run/current-system/sw/bin/fusermount -u ${mountDir}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = ["PATH=/run/wrappers/bin/:$PATH"];
        };
      };
    })
    config.programs.rclone.remotes;
}
