{
  pkgs,
  config,
  ...
}: {
  programs.rofi = {
    enable = true;
    plugins = with pkgs; [
      rofi-games
    ];

    extraConfig = {
      run-command = "uwsm app -- {cmd}";
      display-drun = "";
      display-run = "";
      display-ssh = "";
      display-window = "";
    };

    theme = let
      inherit (config.lib.formats.rasi) mkLiteral;
    in {
      window = {
        background-color = mkLiteral "@base";
        text-color = mkLiteral "@text";
        border-color = mkLiteral "@${config.catppuccin.accent}";

        border = mkLiteral "1px";
        border-radius = 10;
        padding = mkLiteral "30px";
      };

      mainbox = {
        children = [
          "inputbar"
          "message"
          "mode-switcher-box"
          "listview"
        ];

        background-color = mkLiteral "@base";
        text-color = mkLiteral "@text";

        spacing = mkLiteral "50px";
      };

      message = {
        background-color = mkLiteral "transparent";
      };

      textbox = {
        background-color = mkLiteral "@base";
        text-color = mkLiteral "@text";
      };

      inputbar = {
        children = ["entry"];

        background-color = mkLiteral "@base";
      };

      entry = {
        # background-color = mkLiteral "@surface0";
        # text-color = mkLiteral "@text";

        border = mkLiteral "1px";
        border-color = mkLiteral "@${config.catppuccin.accent}";
        border-radius = 10;
        padding = mkLiteral "10px";
      };

      mode-switcher-box = {
        children = [
          "dummy"
          "mode-switcher"
          "dummy"
        ];

        background-color = mkLiteral "transparent";
        expand = false;
        orientation = mkLiteral "horizontal";
      };

      dummy = {
        background-color = mkLiteral "transparent";
        expand = true;
      };

      mode-switcher = {
        background-color = mkLiteral "transparent";

        expand = false;
        spacing = mkLiteral "50px";
      };

      button = {
        background-color = mkLiteral "@surface0";
        border-color = mkLiteral "@${config.catppuccin.accent}";
        cursor = mkLiteral "pointer";
        font = "mono 36";
        text-color = mkLiteral "@text";

        border = mkLiteral "1px";
        border-radius = 10;
        expand = false;
        padding = mkLiteral "10px 20px";
        squared = true;
      };

      "button.selected" = {
        background-color = mkLiteral "@${config.catppuccin.accent}";
        text-color = mkLiteral "@surface0";
      };

      listview = {
        border = mkLiteral "1px";
        border-color = mkLiteral "@${config.catppuccin.accent}";
        border-radius = 10;
      };
    };
  };

  home.packages = with pkgs; [
    rofimoji
    wtype
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      "$main_mod,space,exec,rofi -show drun"
      "$main_mod&SHIFT,period,exec,rofimoji --skin-tone light --max-recent 0"
    ];
  };
}
