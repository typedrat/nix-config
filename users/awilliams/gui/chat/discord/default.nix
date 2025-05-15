{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  krisp-patcher = pkgs.writers.writePython3Bin "krisp-patcher" {
    libraries = with pkgs.python3Packages; [capstone pyelftools];
    flakeIgnore = [
      "E501" # line too long (82 > 79 characters)
      "F403" # ‘from module import *’ used; unable to detect undefined names
      "F405" # name may be undefined, or defined from star imports: module
    ];
  } (builtins.readFile ./krisp-patcher.py);
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.packages = [
      (
        pkgs.discord.override
        {
          withOpenASAR = true;
          withVencord = true;
          # I can't wait for NixOS/nixpkgs#407053 to hit unstable
          vencord = pkgs.vencord.overrideAttrs rec {
            version = "1.12.1";
            src = pkgs.fetchFromGitHub {
              owner = "Vendicated";
              repo = "Vencord";
              rev = "v${version}";
              hash = "sha256-Vs6S8N3q5JzXfeogfD0JrVIhMnYIio7+Dfy12gUJrlU=";
            };
          };
        }
      )
      krisp-patcher
    ];

    # Discord theming:
    xdg.configFile."Vesktop/settings/quickCss.css".source = ./quickCss.css;
  };
}
