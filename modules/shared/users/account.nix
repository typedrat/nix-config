{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) options types;

  userOptions = types.submodule {
    options = {
      enable = options.mkEnableOption "this user account on this system";

      uid = options.mkOption {
        type = types.int;
        description = "The user ID for this user";
      };

      isNormalUser = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether this is a normal user account";
      };

      home = options.mkOption {
        type = types.str;
        description = "Home directory path";
      };

      extraGroups = options.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional groups for the user";
      };

      shell = options.mkOption {
        type = types.package;
        default = pkgs.zsh;
        description = "Default shell package for the user";
      };

      sshKeys = options.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "SSH authorized keys for the user";
      };

      hashedPasswordFile = options.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing hashed password";
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf userOptions;
    default = {};
    description = "User account configurations";
  };
}
