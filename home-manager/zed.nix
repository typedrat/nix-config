{
  inputs,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    nixd
    alejandra
    inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.rust-analyzer
  ];

  programs.zed-editor = {
    enable = true;

    extensions = [
      "codebook"
      "dockerfile"
      "nix"
      "toml"
    ];

    userSettings = {
      languages = {
        Nix = {
          language_servers = ["nixd" "!nil"];
        };
      };

      lsp = {
        nixd = {
          initialization_options = {
            formatting = {
              command = ["alejandra" "--quiet" "--"];
            };
          };
        };
      };

      base_keymap = "VSCode";
      load_direnv = "shell_hook";
      format_on_save = "on";

      ui_font_size = lib.mkForce 16;
    };
  };
}
