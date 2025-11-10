{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs' filterAttrs;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  rcloneCfg = userCfg.rclone or {};
  rcloneRemotes = rcloneCfg.remotes or {};

  # Resolve secret names to actual sops secret paths
  resolveSecrets = secrets:
    lib.attrsets.mapAttrs (name: secretName:
      config.sops.secrets.${secretName}.path
    ) secrets;

  # Resolve file paths in config (e.g., key_file, service_account_file)
  resolveConfigPaths = cfg:
    lib.attrsets.mapAttrs (name: value:
      if name == "key_file" && !lib.strings.hasPrefix "/" value
      then "${config.home.homeDirectory}/.ssh/${value}"
      else if name == "service_account_file" && !lib.strings.hasPrefix "/" value && !lib.strings.hasPrefix "config." value
      then config.sops.secrets.${value}.path
      else value
    ) cfg;

  # Transform user-configured remotes to rclone format
  makeRcloneRemote = name: remoteCfg: {
    config = (resolveConfigPaths remoteCfg.config) // {type = remoteCfg.type;};
    secrets = resolveSecrets remoteCfg.secrets;
  };

  # Filter remotes that should be mounted
  mountedRemotes = filterAttrs (name: remote: remote.mount.enable) rcloneRemotes;
in {
  config = mkIf (rcloneRemotes != {}) {
    programs.rclone = {
      enable = true;
      remotes = mapAttrs' (name: remoteCfg: {
        name = name;
        value = makeRcloneRemote name remoteCfg;
      }) rcloneRemotes;
    };

    systemd.user.services =
      mapAttrs' (name: remoteCfg: {
        name = "rclone-${name}-mount";
        value = {
          Unit = {
            Description = "Service that connects to ${name} remote";
            After = ["network-online.target" "sops-nix.service"];
          };
          Install.WantedBy = ["default.target"];

          Service = let
            mountDir = "${config.home.homeDirectory}/${remoteCfg.mount.path or "mnt/${name}"}";
          in {
            Type = "simple";
            ExecStartPre = "/run/current-system/sw/bin/mkdir -p ${mountDir}";
            ExecStart = "${pkgs.rclone}/bin/rclone mount --vfs-cache-mode ${remoteCfg.mount.vfsCacheMode} ${name}: ${mountDir}";
            ExecStop = "/run/wrappers/bin/fusermount -u ${mountDir}";
            Restart = "on-failure";
            RestartSec = "10s";
            Environment = ["PATH=/run/wrappers/bin/:$PATH"];
          };
        };
      })
      mountedRemotes;
  };
}
