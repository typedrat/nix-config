{
  pkgs,
  lib,
  osConfig,
  ...
}: {
  home.packages = with pkgs; [
    alejandra
    nixd
  ];

  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        bradlc.vscode-tailwindcss
        catppuccin.catppuccin-vsc-icons
        dbaeumer.vscode-eslint
        dejmedus.tailwind-sorter
        esbenp.prettier-vscode
        editorconfig.editorconfig
        firefox-devtools.vscode-firefox-debug
        jnoortheen.nix-ide
        mkhl.direnv
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

  programs.chromium = {
    enable = true;
    extensions = [
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
      "mbniclmhobmnbdlbpiphghaielnnpgdp" # Lightshot
      "gcbommkclmclpchllfjekcdonpmejbdp" # HTTPS Everywhere
      "lnjaiaapbakfhlbjenjkhffcdpoompki" # Catppuccin for Web File Explorer Icons
      "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
    ];
  };
}
