{
  pkgs,
  lib,
  osConfig,
  config,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.devtools.enable) {
    programs.vscode = let
      pkl-vscode = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "pkl-vscode";
          version = "0.18.2";
          publisher = "apple";
        };
        vsix = builtins.fetchurl {
          url = "https://github.com/apple/pkl-vscode/releases/download/0.18.2/pkl-vscode-0.18.2.vsix";
          sha256 = "sha256:0lvsf1y9ib05n6idbl0171ncdjb0r01kibp6128k2j8ncxyvpvy3";
          name = "pkl-vscode-0.18.2.zip";
        };
      };
    in {
      enable = true;

      profiles.default = {
        extensions = with pkgs.vscode-marketplace; [
          bradlc.vscode-tailwindcss
          dbaeumer.vscode-eslint
          dejmedus.tailwind-sorter
          editorconfig.editorconfig
          esbenp.prettier-vscode
          firefox-devtools.vscode-firefox-debug
          hverlin.mise-vscode
          jnoortheen.nix-ide
          leanprover.lean4
          mkhl.direnv
          mtxr.sqltools
          mtxr.sqltools-driver-pg
          pkl-vscode
          redhat.vscode-xml
          rooveterinaryinc.roo-cline
          tamasfe.even-better-toml
        ];

        userSettings = {
          "editor.fontFamily" = lib.strings.concatMapStringsSep ", " (x: ''"${x}"'') osConfig.fonts.fontconfig.defaultFonts.monospace;
          "explorer.confirmDragAndDrop" = false;
          "remote.autoForwardPortsSource" = "process";
          "window.menuBarVisibility" = "toggle";
          "window.titleBarStyle" = "native";
          "workbench.colorTheme" = lib.mkForce "Catppuccin Frappé";
          "workbench.iconTheme" = "catppuccin-frappe";

          "cline.chromeExecutablePath" = lib.getExe config.programs.chromium.package;
          "dev.containers.dockerSocketPath" = "/run/user/${builtins.toString osConfig.users.users.${config.home.username}.uid}/docker.sock";
          "mise.checkForNewMiseVersion" = false;
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
  };
}
