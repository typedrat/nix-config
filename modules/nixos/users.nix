{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.users;

  # Filter to only enabled users
  enabledUsers = lib.filterAttrs (_: userCfg: userCfg.enable) cfg;
in {
  config = {
    users.users = modules.mkMerge (
      lib.mapAttrsToList (
        username: userCfg: {
          ${username} =
            {
              inherit (userCfg) uid isNormalUser home extraGroups shell;
              openssh.authorizedKeys.keys = userCfg.sshKeys;
            }
            // lib.optionalAttrs (config.sops.secrets ? "users/${username}/hashedPassword") {
              # Use SOPS secret for hashed password if it exists
              hashedPasswordFile = config.sops.secrets."users/${username}/hashedPassword".path;
            };
        }
      )
      enabledUsers
    );

    # Ensure ~/mnt exists with correct ownership for each user
    systemd.tmpfiles.settings =
      lib.mapAttrs' (username: userCfg: {
        name = "10-home-mnt-${username}";
        value."${userCfg.home}/mnt".d = {
          user = username;
          group = "users";
          mode = "0755";
        };
      })
      enabledUsers;
  };
}
