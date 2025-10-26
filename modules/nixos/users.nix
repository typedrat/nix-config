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
          ${username} = {
            inherit (userCfg) uid isNormalUser home extraGroups shell;
            openssh.authorizedKeys.keys = userCfg.sshKeys;
            # Use SOPS secret for hashed password
            hashedPasswordFile = config.sops.secrets."users/${username}/hashedPassword".path;
          };
        }
      )
      enabledUsers
    );
  };
}
