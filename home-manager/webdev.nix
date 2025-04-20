{
  pkgs,
  lib,
  osConfig,
  config,
  ...
}: {
  home.packages = with pkgs; [
    alejandra
    nixd
    uv
    playwright-driver.browsers
    (jetbrains.datagrip.override {
      vmopts = "-Dawt.toolkit.name=WLToolkit";
    })
    (jetbrains.webstorm.override {
      vmopts = "-Dawt.toolkit.name=WLToolkit";
    })
  ];

  systemd.user.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
  };

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
        mtxr.sqltools
        mtxr.sqltools-driver-pg
        redhat.vscode-xml
        saoudrizwan.claude-dev
        tamasfe.even-better-toml
      ];

      userSettings = {
        "editor.fontFamily" = lib.strings.concatMapStringsSep ", " (x: ''"${x}"'') osConfig.fonts.fontconfig.defaultFonts.monospace;
        "explorer.confirmDragAndDrop" = false;
        "window.menuBarVisibility" = "toggle";
        "window.titleBarStyle" = "native";
        "workbench.colorTheme" = lib.mkForce "Catppuccin Frappé";
        "workbench.iconTheme" = "catppuccin-frappe";

        "cline.chromeExecutablePath" = lib.getExe config.programs.chromium.package;
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
    commandLineArgs = [
      "-no-default-browser-check"
    ];
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
      "mbniclmhobmnbdlbpiphghaielnnpgdp" # Lightshot
      "gcbommkclmclpchllfjekcdonpmejbdp" # HTTPS Everywhere
      "lnjaiaapbakfhlbjenjkhffcdpoompki" # Catppuccin for Web File Explorer Icons
      "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
    ];
  };
}
