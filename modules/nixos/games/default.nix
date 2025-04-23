{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
in {
  imports = [
    ./aagl.nix
    ./steam.nix
  ];

  options.rat = {
    games.enable = mkEnableOption "games";
  };

  config = mkMerge [
    {
      users.groups.games = {
        gid = 420;
        name = "games";
      };
    }

    (mkIf config.rat.games.enable {
      assertions = [
        {
          assertion = config.rat.gui.enable;
          message = "Games can't be installed on a system without graphics.";
        }
      ];

      hardware.xpadneo.enable = true;
    })
  ];
}
