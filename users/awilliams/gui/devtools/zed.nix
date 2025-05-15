{
  config,
  osConfig,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.devtools.enable) {
    programs.zed-editor = {
      enable = true;
      package = inputs'.zed-editor.packages.zed-editor;

      extraPackages = with pkgs; [
        nixd
        alejandra
        package-version-server
        vscode-langservers-extracted
        inputs'.fenix.packages.rust-analyzer
        lua-language-server
      ];

      extensions = [
        "catppuccin"
        "catppuccin-icons"
        "codebook"
        "dockerfile"
        "git-firefly"
        "html"
        "just"
        "nix"
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

        agent = {
          default_model = {
            provider = "openai";
            model = "anthropic/claude-3.7-sonnet";
          };
          editor_model = {
            provider = "openai";
            model = "anthropic/claude-3.7-sonnet";
          };
        };

        language_models = {
          openai = {
            version = "1";
            api_url = "https://openrouter.ai/api/v1";
            available_models = [
              {
                name = "anthropic/claude-3.7-sonnet";
                display_name = "Anthropic: Claude 3.7 Sonnet";
                max_tokens = 200000;
                max_output_tokens = 64000;
              }
              {
                name = "anthropic/claude-3.7-sonnet:thinking";
                display_name = "Anthropic: Claude 3.7 Sonnet (thinking)";
                max_tokens = 200000;
                max_output_tokens = 64000;
              }
              {
                name = "deepseek/deepseek-r1";
                display_name = "DeepSeek: DeepSeek R1";
                max_tokens = 163840;
                max_output_tokens = 163840;
              }
              {
                name = "deepseek/deepseek-chat-v3-0324";
                display_name = "DeepSeek: DeepSeek V3";
                max_tokens = 163840;
                max_output_tokens = 163840;
              }
              {
                name = "google/gemini-2.5-pro-preview";
                display_name = "Google: Gemini 2.5 Pro Preview";
                max_tokens = 1048576;
                max_output_tokens = 65535;
              }
              {
                name = "google/gemini-2.5-flash-preview";
                display_name = "Google: Gemini 2.5 Flash Preview";
                max_tokens = 1048576;
                max_output_tokens = 65535;
              }
              {
                name = "google/gemini-2.5-flash-preview:thinking";
                display_name = "Google: Gemini 2.5 Flash Preview (thinking)";
                max_tokens = 1048576;
                max_output_tokens = 65535;
              }
              {
                name = "openai/gpt-4.1";
                display_name = "OpenAI: GPT-4.1";
                max_tokens = 1047576;
                max_output_tokens = 32768;
              }
              {
                name = "openai/o4-mini-high";
                display_name = "OpenAI: o4 Mini High";
                max_tokens = 200000;
                max_output_tokens = 100000;
              }
            ];
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

    systemd.user.sessionVariables = {
      EDITOR = "${lib.getExe config.programs.zed-editor.package} -w";
    };
  };
}
