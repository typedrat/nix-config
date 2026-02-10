{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) options types;

  agentOptions = types.submodule {
    options = {
      enable =
        options.mkEnableOption "GPG agent"
        // {
          default = true;
        };

      pinentryPackage = options.mkOption {
        type = types.package;
        default = pkgs.pinentry-qt;
        description = "Pinentry package to use";
      };

      defaultCacheTtl = options.mkOption {
        type = types.int;
        default = 600;
        description = "Default cache TTL in seconds";
      };

      maxCacheTtl = options.mkOption {
        type = types.int;
        default = 7200;
        description = "Max cache TTL in seconds";
      };

      enableSshSupport = options.mkOption {
        type = types.bool;
        default = false;
        description = "Enable SSH agent emulation";
      };
    };
  };

  gpgOptions = types.submodule {
    options = {
      enable =
        options.mkEnableOption "GPG with security key"
        // {
          default = true;
        };

      scdaemonSettings = options.mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Extra settings for scdaemon.conf";
      };
    };
  };

  securityKeyOptions = types.submodule {
    options = {
      enable = options.mkEnableOption "security key support";

      gpg = options.mkOption {
        type = gpgOptions;
        default = {};
        description = "GPG configuration for security key";
      };

      agent = options.mkOption {
        type = agentOptions;
        default = {};
        description = "GPG agent configuration";
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.securityKey = options.mkOption {
        type = securityKeyOptions;
        default = {};
        description = "Security key configuration for this user";
      };
    });
  };
}
