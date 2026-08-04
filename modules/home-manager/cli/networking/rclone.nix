{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs' filterAttrs;
  inherit (lib.lists) concatMap filter foldl' optional unique;
  inherit (lib.strings) hasPrefix splitString;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  rcloneCfg = userCfg.rclone or {};
  rcloneRemotes = rcloneCfg.remotes or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Resolve secret names to actual sops secret paths
  resolveSecrets = secrets:
    lib.attrsets.mapAttrs (
      _name: secretName:
        config.sops.secrets.${secretName}.path
    )
    secrets;

  # Resolve file paths in config (e.g., key_file, service_account_file)
  resolveConfigPaths = cfg:
    lib.attrsets.mapAttrs (
      name: value:
        if name == "key_file" && !lib.strings.hasPrefix "/" value
        then "${config.home.homeDirectory}/.ssh/${value}"
        else if name == "service_account_file" && !lib.strings.hasPrefix "/" value && !lib.strings.hasPrefix "config." value
        then config.sops.secrets.${value}.path
        else value
    )
    cfg;

  # Transform user-configured remotes to rclone format
  makeRcloneRemote = _name: remoteCfg: {
    config = (resolveConfigPaths remoteCfg.config) // {inherit (remoteCfg) type;};
    secrets = resolveSecrets remoteCfg.secrets;
  };

  # Filter remotes that should be mounted
  mountedRemotes = filterAttrs (_name: remote: remote.mount.enable) rcloneRemotes;

  isSecretRef = value: !hasPrefix "/" value && !hasPrefix "config." value;

  # Secret names the remotes refer to: every `secrets` value, plus any
  # service_account_file that isn't already a path.
  referencedSecrets = unique (concatMap (remote:
    lib.attrValues remote.secrets
    ++ optional (isSecretRef (remote.config.service_account_file or "/"))
    remote.config.service_account_file) (lib.attrValues rcloneRemotes));

  # A "<file>/<key>" name belongs to this user when secrets/<username>/<file>.yaml
  # exists; everything else is looked up in the shared sops file.
  userSecretParts = name: let
    parts = splitString "/" name;
  in
    if
      builtins.length parts
      == 2
      && builtins.pathExists (config.rat.userSecretsDir + "/${builtins.head parts}.yaml")
    then parts
    else null;

  isUserSecret = name: userSecretParts name != null;
in {
  config = mkIf (rcloneRemotes != {}) {
    rat.userSecrets =
      foldl' lib.recursiveUpdate {}
      (map (name: let
        parts = userSecretParts name;
      in {
        ${builtins.elemAt parts 0}.${builtins.elemAt parts 1} = {};
      }) (filter isUserSecret referencedSecrets));

    sops.secrets = lib.genAttrs (filter (name: !isUserSecret name) referencedSecrets) (_: {});

    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/rclone"];
    };

    programs.rclone = {
      enable = true;
      remotes =
        mapAttrs' (name: remoteCfg: {
          inherit name;
          value = makeRcloneRemote name remoteCfg;
        })
        rcloneRemotes;
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
