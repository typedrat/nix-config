{lib, ...}: let
  inherit (lib) options types;

  rcloneRemoteOptions = types.submodule {
    options = {
      type = options.mkOption {
        type = types.str;
        description = "Remote type (drive, sftp, b2, etc.)";
        example = "sftp";
      };

      config = options.mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Provider-specific configuration options";
        example = {
          host = "server.example.com";
          user = "username";
        };
      };

      secrets = options.mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Secret paths to inject into the remote configuration";
        example = {
          account = "/run/secrets/b2-account";
          key = "/run/secrets/b2-key";
        };
      };

      mount = {
        enable = options.mkOption {
          type = types.bool;
          default = false;
          description = "Whether to automatically mount this remote";
        };

        path = options.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Mount path relative to home directory (defaults to ~/mnt/<remote-name>)";
          example = "mnt/remote-name";
        };

        vfsCacheMode = options.mkOption {
          type = types.str;
          default = "full";
          description = "VFS cache mode for rclone mount";
        };
      };
    };
  };

  rcloneOptions = types.submodule {
    options = {
      remotes = options.mkOption {
        type = types.attrsOf rcloneRemoteOptions;
        default = {};
        description = "Rclone remote configurations";
        example = {
          my-sftp = {
            type = "sftp";
            config = {
              host = "server.example.com";
              user = "username";
            };
            mount.enable = true;
          };
        };
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.rclone = options.mkOption {
        type = rcloneOptions;
        default = {};
        description = "Rclone configuration for this user";
      };
    });
  };
}
