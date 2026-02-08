{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
  lockerCfg = hyprlandCfg.locker or {};
  hostHyprlandCfg = osConfig.rat.gui.hyprland or {};
  primaryMonitor = hostHyprlandCfg.primaryMonitor or null;
  # Use empty string as fallback (hyprlock treats empty as "all monitors")
  monitor =
    if primaryMonitor != null
    then primaryMonitor
    else "";
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (lockerCfg.enable or true)
      && (lockerCfg.variant or "hyprlock") == "hyprlock"
    ) {
      catppuccin.hyprlock.useDefaultConfig = false;

      programs.hyprlock = {
        enable = true;
        package = inputs.hyprlock.packages."${pkgs.stdenv.system}".hyprlock;

        settings = {
          "$font" = "TX02 Nerd Font";

          general = {
            disable_loading_bar = true;
            hide_cursor = true;
          };

          background = [
            {
              monitor = "";
              color = "$base";
            }
          ];

          label = [
            # Time
            {
              inherit monitor;
              text = "$TIME";
              color = "$text";
              font_size = 90;
              font_family = "$font";
              position = "-30, 0";
              halign = "right";
              valign = "top";
            }
            # Date
            {
              inherit monitor;
              text = "cmd[update:43200000] date +\"%A, %d %B %Y\"";
              color = "$text";
              font_size = 25;
              font_family = "$font";
              position = "-30, -150";
              halign = "right";
              valign = "top";
            }
            # Decorative
            {
              inherit monitor;
              color = "$accent";
              font_family = "DotGothic16";
              font_size = 90;
              halign = "center";
              position = "0, 5%";
              text = "旅人よ、あなたは<span foreground=\"##$redAlpha\">ネズミ</span>の世界に入った。";
              valign = "bottom";
            }
          ];

          image = [
            # User avatar
            {
              inherit monitor;
              path = "$HOME/.face";
              size = 100;
              border_color = "$accent";
              position = "0, 75";
              halign = "center";
              valign = "center";
            }
          ];

          input-field = [
            {
              inherit monitor;
              size = "300, 60";
              outline_thickness = 4;
              dots_size = 0.2;
              dots_spacing = 0.2;
              dots_center = true;
              outer_color = "$accent";
              inner_color = "$surface0";
              font_family = "$font";
              font_color = "$text";
              fade_on_empty = false;
              placeholder_text = "<span foreground=\"##$textAlpha\"><i>󰌾 Logged in as </i><span foreground=\"##$accentAlpha\">$USER</span></span>";
              hide_input = false;
              check_color = "$accent";
              fail_color = "$red";
              fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
              capslock_color = "$yellow";
              position = "0, -47";
              halign = "center";
              valign = "center";
            }
          ];
        };
      };
    };
}
