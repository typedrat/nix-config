{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  terminalsCfg = guiCfg.terminals or {};
in {
  config = modules.mkIf (guiCfg.enable && terminalsCfg.ghostty.enable) {
    programs.ghostty = {
      enable = true;
      settings = {
        font-family = [
          "TX-02"
          "Miriam Mono CLM"
          "M PLUS 1 Code"
          "JuliaMono"
          "Symbols Nerd Font"
          "Apple Color Emoji"
          "Noto Sans Devanagari"
        ];
        font-size = 14;
        window-padding-x = 8;
        window-padding-y = 8;
        background-opacity = 0.625;
        keybind = "shift+enter=text:\\x1b\\r";
      };
    };

    home.packages = [
      pkgs.xdg-terminal-exec
    ];

    programs.plasma.configFile."kdeglobals".General = {
      TerminalApplication.value = "ghostty";
      TerminalService.value = "com.mitchellh.ghostty.desktop";
    };

    xdg.configFile."xdg-terminals.list".text = ''
      com.mitchellh.ghostty.desktop
    '';
  };
}
