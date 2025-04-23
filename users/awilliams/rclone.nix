{
  pkgs,
  config,
  ...
}: {
  programs.rclone = {
    enable = true;

    remotes = {
      b2 = {
        config = {
          type = "b2";
        };
        secrets = {
          account = config.sops.secrets."b2/keyId".path;
          key = config.sops.secrets."b2/applicationKey".path;
        };
      };
    };
  };

  sops.secrets = {
    "b2/keyId" = {};
    "b2/applicationKey" = {};
  };

  systemd.user.services.rclone-b2-mount = {
    Unit = {
      Description = "Service that connects to Backblaze B2";
      After = ["network-online.target" "sops-nix.service"];
    };
    Install.WantedBy = ["default.target"];

    Service = let
      b2Dir = "${config.home.homeDirectory}/mnt/b2";
    in {
      Type = "simple";
      ExecStartPre = "/run/current-system/sw/bin/mkdir -p ${b2Dir}";
      ExecStart = "${pkgs.rclone}/bin/rclone mount --vfs-cache-mode full b2: ${b2Dir}";
      ExecStop = "/run/current-system/sw/bin/fusermount -u ${b2Dir}";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = ["PATH=/run/wrappers/bin/:$PATH"];
    };
  };
}
