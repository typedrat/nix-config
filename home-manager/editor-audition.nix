{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  programs.zed-editor = {
    enable = true;

    extensions = [
      "codebook"
      "dockerfile"
      "nix"
      "tokyo-night"
      "toml"
    ];

    userSettings = {
      theme = {
        mode = "system";
        light = "Tokyo Night Light";
        dark = "Tokyo Night Storm";
      };

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

      format_on_save = "on";

      buffer_font_family = "TX-02";
      buffer_font_size = 14;

      ui_font_family = "SF Pro Display";
      ui_font_size = 16;
    };
  };

  home.packages = [pkgs.jetbrains.rust-rover];
}
