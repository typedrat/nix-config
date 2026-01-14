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

      systemd.settings.Manager = {
        DefaultLimitNOFILE = 524288;
      };
      security.pam.loginLimits = [
        {
          domain = "awilliams";
          type = "hard";
          item = "nofile";
          value = "524288";
        }
      ];

      hardware.xpadneo.enable = true;
      programs.gamemode.enable = true;
      # GuliKit ES Pro - fix rumble being constantly on
      boot.extraModprobeConfig = let
        gulikitEsProMAC = "06:71:10:21:29:B3";
      in ''
        options hid_xpadneo quirks=${gulikitEsProMAC}:7
      '';
    })
  ];
}
