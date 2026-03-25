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
        core.enable = options.mkEnableOption "core shell tools (bat, fzf, etc.)" // {default = true;};
        git.enable = options.mkEnableOption "git tools (lazygit, difftastic)" // {default = true;};
        monitoring.enable = options.mkEnableOption "system monitoring tools" // {default = true;};
        nix.enable = options.mkEnableOption "Nix ecosystem tools" // {default = true;};
        media.enable = options.mkEnableOption "media processing tools" // {default = true;};
        archiving.enable = options.mkEnableOption "archive/compression tools" // {default = true;};
        secrets.enable = options.mkEnableOption "crypto and secrets tools" // {default = true;};
      };

      development = {
        enable = options.mkEnableOption "development CLI tools" // {default = true;};
      };

      ai = {
        enable = options.mkEnableOption "AI tools and configuration" // {default = true;};

        peon-ping = {
          enable = options.mkEnableOption "peon-ping AI agent notifications";

          packs = options.mkOption {
            type = types.listOf (types.either types.str (types.submodule {
              options = {
                name = options.mkOption {
                  type = types.str;
                  description = "Name of the sound pack (used as directory name)";
                };
                src = options.mkOption {
                  type = types.either types.package types.path;
                  description = "Source for the pack (fetchFromGitHub, fetchzip, path, etc.)";
                };
              };
            }));
            default = [];
            description = "Sound packs to install (built-in names as strings, or {name, src} for third-party)";
          };
        };
      };

      networking = {
        enable = options.mkEnableOption "networking tools" // {default = true;};
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
