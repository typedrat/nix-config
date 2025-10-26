{lib, ...}: let
  inherit (lib) options types;

  themingOptions = types.submodule {
    options = {
      enable = options.mkEnableOption "theming configuration";

      steam = {
        enable = options.mkEnableOption "Steam theming" // {default = true;};
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.theming = options.mkOption {
        type = themingOptions;
        default = {};
        description = "Theming configuration options";
      };
    });
  };
}
