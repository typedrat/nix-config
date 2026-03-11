{
  config,
  pkgs,
  lib,
  ...
}: let
  iniFormat = pkgs.formats.ini {};
  cfg = config.rat.kdeglobals;
in {
  options.rat.kdeglobals = lib.mkOption {
    inherit (iniFormat) type;
    default = {};
    description = "Attrset of INI sections for ~/.config/kdeglobals, merged across modules.";
  };

  config = lib.mkIf (cfg != {}) {
    xdg.configFile."kdeglobals".source = iniFormat.generate "kdeglobals" cfg;
  };
}
