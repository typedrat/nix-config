{
  config,
  osConfig,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.development.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/zed" ".local/share/zed"];
    };
    programs.zed-editor = {
      enable = true;

      extraPackages = with pkgs; [
        nixd
        alejandra
        package-version-server
        vscode-langservers-extracted
        inputs'.fenix.packages.rust-analyzer
        lua-language-server
      ];

      extensions = [
        "astro"
        "authzed"
        "catppuccin"
        "catppuccin-icons"
        "codebook"
        "discord-presence"
        "dockerfile"
        "emmet"
        "env"
        "git-firefly"
        "haskell"
        "helm"
        "html"
        "ini"
        "just"
        "latex"
        "lua"
        "make"
        "mcp-server-context7"
        "neocmake"
        "nix"
        "pkl"
        "python-requirements"
        "scss"
        "sql"
        "tera"
        "terraform"
        "toml"
        "xml"
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
        ui_font_size = 16;

        buffer_font_family = builtins.head osConfig.fonts.fontconfig.defaultFonts.monospace;
        buffer_font_fallbacks = builtins.tail osConfig.fonts.fontconfig.defaultFonts.monospace;
        buffer_font_size = 14;
      };
    };

    systemd.user.sessionVariables = {
      EDITOR = "${lib.getExe config.programs.zed-editor.package} -w";
    };
  };
}
