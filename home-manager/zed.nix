{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}: {
  programs.zed-editor = {
    enable = true;

    extraPackages = with pkgs; [
      nixd
      alejandra
      package-version-server
      vscode-langservers-extracted
      inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.rust-analyzer
    ];

    extensions = [
      "catppuccin"
      "catppuccin-icons"
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

      lsp = {
        package-version-server = {
          binary = {
            path = "package-version-server";
          };
        };
      };

      base_keymap = "VSCode";
      load_direnv = "shell_hook";
      format_on_save = "on";

      theme = lib.mkForce {
        mode = "system";
        light = "Catppuccin Latte (lavender)";
        dark = "Catppuccin Frappé (lavender)";
      };

      icon_theme = lib.mkForce {
        mode = "system";
        light = "Catppuccin Latte";
        dark = "Catppuccin Frappé";
      };

      ui_font_family = builtins.head osConfig.fonts.fontconfig.defaultFonts.sansSerif;
      ui_font_fallbacks = builtins.tail osConfig.fonts.fontconfig.defaultFonts.sansSerif;
      ui_font_size = 13 * (4.0 / 3.0);

      # This has to be set manually, because Zed doesn't support custom font fallbacks on Linux.
      #
      # See: https://github.com/zed-industries/zed/issues/17254
      buffer_font_family = "TX02 Nerd Font Mono";
      buffer-font-size = 14 * (4.0 / 3.0);
    };
  };
}
