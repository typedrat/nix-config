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
  hyprlandCfg = guiCfg.hyprland or {};
  browsersCfg = guiCfg.browsers or {};

  bitwardenResizeScript = pkgs.writeScript "hyprland-bitwarden-resize" ''
    #!/bin/sh

    handle() {
      case $1 in
        windowtitle*)
          # Extract the window ID from the line
          window_id=''${1#*>>}

          # Fetch the list of windows and parse it using jq to find the window by its decimal ID
          window_info=$(hyprctl clients -j | ${pkgs.jq}/bin/jq --arg id "0x$window_id" '.[] | select(.address == ($id))')

          # Extract the title from the window info
          window_title=$(echo "$window_info" | ${pkgs.jq}/bin/jq '.title')

          # Check if the title matches the characteristics of the Bitwarden popup window
          if [[ "$window_title" == *"(Bitwarden Password Manager) - Bitwarden"* ]]; then

            hyprctl --batch "dispatch togglefloating address:0x$window_id ; dispatch resizewindowpixel exact 500 800,address:0x$window_id"
          fi
          ;;
      esac
    }

    # Listen to the Hyprland socket for events and process each line with the handle function
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:/run/user/1000/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
  '';
in {
  config = modules.mkIf (guiCfg.enable && hyprlandCfg.enable && (browsersCfg.firefox.enable || browsersCfg.zen.enable)) {
    wayland.windowManager.hyprland = {
      settings = {
        exec-once = ["$HOME/.local/share/scripts/hyprland-bitwarden-resize.sh"];
      };

      extraConfig = ''
        windowrule {
          name = firefox-suppress-maximize
          match:class = ^(firefox)$
          suppress_event = maximize
        }
      '';
    };

    xdg.dataFile."scripts/hyprland-bitwarden-resize.sh".source = bitwardenResizeScript;
  };
}
