{lib, ...}: let
  inherit (lib) options types;

  environmentOptions = types.submodule {
    options = {
      variables = options.mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional environment variables for this user";
        example = {
          EDITOR = "vim";
          CUSTOM_VAR = "value";
        };
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.environment = options.mkOption {
        type = environmentOptions;
        default = {};
        description = "Environment configuration for this user";
      };
    });
  };
}
