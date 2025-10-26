{
  osConfig,
  config,
  pkgs,
  lib,
  ...
}: let
  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);
in
  lib.optionalAttrs osConfig.rat.games.steam.enable {
    home.packages = [pkgs.adwsteamgtk];

    home.activation = let
      applySteamTheme = pkgs.writeShellScript "applySteamTheme" ''
        ${lib.getExe pkgs.adwsteamgtk} -i
      '';
    in {
      updateSteamTheme = config.lib.dag.entryAfter ["writeBoundary" "dconfSettings"] ''
        run ${applySteamTheme}
      '';
    };

    dconf.settings."io/github/Foldex/AdwSteamGtk" = {
      color-theme-options = "Catppuccin-${capitalizeFirst config.catppuccin.flavor}";
    };
  }
