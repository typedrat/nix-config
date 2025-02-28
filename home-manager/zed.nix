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
      "catppuccin"
      "codebook"
      "dockerfile"
      "nix"
      "toml"
    ];

    userSettings = {
      languages = {
        Nix = {
          language_servers = ["nixd" "!nil"];

          formatter = {
            external = {
              command = "alejandra";
              arguments = ["--quiet" "--"];
            };
          };
        };
      };

      base_keymap = "VSCode";
      load_direnv = "shell_hook";
      format_on_save = "on";

      theme = lib.mkForce "Catppuccin Frappé";
    };
  };
}
