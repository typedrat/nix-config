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
      version = "0.21.0";

      pkl-vscode = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "pkl-vscode";
          inherit version;
          publisher = "apple";
        };
        vsix = builtins.fetchurl {
          url = "https://github.com/apple/pkl-vscode/releases/download/${version}/pkl-vscode-${version}.vsix";
          sha256 = "sha256:0jgbsxllqd1vhqzd83vv7bjg2hb951hqg6wflxxxalxvj4zlni79";
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

          "cline.chromeExecutablePath" = lib.getExe config.programs.brave.package;
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
