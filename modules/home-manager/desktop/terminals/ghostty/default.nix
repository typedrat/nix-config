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

  # Ghostty marks every newline in PS1 with `%{...%}`, including newlines
  # that powerlevel10k places inside `${...}` expansions. The `}` in the
  # mark closes the expansion early and its tail is printed as literal
  # `:-` and `}}` around the prompt. This copy leaves multiline prompts
  # unmarked; the first line still gets its marks.
  zshIntegration = pkgs.runCommand "ghostty-zsh-integration" {} ''
    cp ${config.programs.ghostty.package}/share/ghostty/shell-integration/zsh/ghostty-integration $out
    substituteInPlace $out --replace-fail '(( ! ps1_changed ))' 'false'
  '';
in {
  config = modules.mkIf (guiCfg.enable && terminalsCfg.ghostty.enable) {
    programs.ghostty = {
      enable = true;
      enableZshIntegration = false;
      settings = {
        shell-integration = "none";
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

    programs.zsh.initContent = ''
      if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
        source ${zshIntegration}
      fi
    '';

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
