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
        }
      )
      krisp-patcher
    ];

    # Discord theming:
    xdg.configFile."Vesktop/settings/quickCss.css".source = ./quickCss.css;
  };
}
