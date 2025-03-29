{
  pkgs,
  lib,
  osConfig,
  ...
}: {
  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        bradlc.vscode-tailwindcss
        catppuccin.catppuccin-vsc-icons
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
        editorconfig.editorconfig
        firefox-devtools.vscode-firefox-debug
        jnoortheen.nix-ide
        mkhl.direnv
        vercel.turbo-vsc
      ];

      userSettings = {
        "editor.fontFamily" = lib.strings.concatMapStringsSep ", " (x: ''"${x}"'') osConfig.fonts.fontconfig.defaultFonts.monospace;
        "explorer.confirmDragAndDrop" = false;
        "window.menuBarVisibility" = "toggle";
        "window.titleBarStyle" = "native";
        "workbench.colorTheme" = lib.mkForce "Catppuccin Frappé";
        "workbench.iconTheme" = "catppuccin-frappe";

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.serverSettings" = {
          "nixd" = {
            "formatting" = {
              "command" = ["alejandra"];
            };
          };
        };
      };
    };
  };

  home.packages = with pkgs; [
    alejandra
    nixd
  ];
}
