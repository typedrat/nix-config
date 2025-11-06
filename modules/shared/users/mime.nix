{lib, ...}: let
  inherit (lib) options types;

  mimeOptions = types.submodule {
    options = {
      enable = options.mkEnableOption "MIME type associations management";

      defaultApplications = options.mkOption {
        type = types.attrsOf (types.either types.str (types.listOf types.str));
        default = {};
        example = {
          "text/html" = "firefox.desktop";
          "image/png" = ["image-viewer.desktop" "gimp.desktop"];
        };
        description = ''
          Default applications for MIME types. Can be a single desktop file
          or a list of desktop files (in order of preference).
        '';
      };

      associations = {
        added = options.mkOption {
          type = types.attrsOf (types.either types.str (types.listOf types.str));
          default = {};
          example = {
            "text/plain" = ["nvim.desktop" "code.desktop"];
          };
          description = ''
            Additional associations to add for MIME types without replacing
            existing system defaults.
          '';
        };

        removed = options.mkOption {
          type = types.attrsOf (types.either types.str (types.listOf types.str));
          default = {};
          example = {
            "text/html" = "chromium.desktop";
          };
          description = "Associations to remove for specific MIME types.";
        };
      };
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.mime = options.mkOption {
        type = mimeOptions;
        default = {};
        description = "MIME type association options";
      };
    });
  };
}
