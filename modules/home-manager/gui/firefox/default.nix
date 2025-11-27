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
in {
  config = modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false) && ((browsersCfg.firefox.enable or false) || (browsersCfg.zen.enable or false))) {
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

    xdg.dataFile."scripts/hyprland-bitwarden-resize.sh".source =
      pkgs.callPackage ./bitwarden-resize-script.nix {};
  };
}
