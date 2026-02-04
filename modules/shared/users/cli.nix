{lib, ...}: let
  inherit (lib) options types;

  cliOptions = types.submodule {
    options = {
      enable = options.mkEnableOption "CLI tools and configuration";

      shell = {
        enable = options.mkEnableOption "shell configuration" // {default = true;};
      };

      tools = {
        enable = options.mkEnableOption "CLI development tools" // {default = true;};
      };

      development = {
        enable = options.mkEnableOption "development CLI tools" // {default = true;};
      };

      comfy-cli = {
        enable = options.mkEnableOption "comfy-cli for managing ComfyUI";
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.cli = options.mkOption {
        type = cliOptions;
        default = {};
        description = "CLI configuration options";
      };
    });
  };
}
