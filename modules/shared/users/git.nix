{lib, ...}: let
  inherit (lib) options types;

  gitOptions = types.submodule {
    options = {
      name = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Git user name";
        example = "John Doe";
      };

      email = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Git email address";
        example = "john.doe@example.com";
      };

      signing = {
        key = options.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Key for signing commits (GPG key ID or SSH key path)";
          example = "~/.ssh/id_ed25519_sk";
        };

        format = options.mkOption {
          type = types.enum ["gpg" "ssh"];
          default = "gpg";
          description = "Format for signing commits";
        };

        signByDefault = options.mkOption {
          type = types.bool;
          default = false;
          description = "Whether to sign commits by default";
        };
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.git = options.mkOption {
        type = gitOptions;
        default = {};
        description = "Git configuration for this user";
      };
    });
  };
}
