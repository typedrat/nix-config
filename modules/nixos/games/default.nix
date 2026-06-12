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
    ./sunshine.nix
  ];

  options.rat = {
    gaming.enable = mkEnableOption "gaming";
  };

  config = mkMerge [
    {
      users.groups.games = {
        gid = 420;
        name = "games";
      };
    }

    (mkIf config.rat.gaming.enable {
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

      # Nintendo Switch Pro Controller support via the in-kernel hid-nintendo
      # driver, which exposes both the buttons/axes and a full 6-axis IMU
      # (accel/gyro) device on its own. Used for the GuliKit ES Pro in NS mode
      # (wired, or wireless via the GuliKit Goku 2 dongle), which enumerates as
      # a 057e:2009 Pro Controller with a full 6-axis IMU device.
      #
      # joycond + joycond-cemuhook are intentionally NOT enabled. For a single
      # Pro Controller they are counter-productive:
      #   - joycond EVIOCGRAB's the device and re-presents it under a different
      #     name, which changes SDL's CRC-derived joystick GUID and breaks any
      #     emulator profile bound to the raw device.
      #   - joycond's udev rules lock the controller's /dev/hidrawN node to
      #     root-only (0600, uaccess stripped) to keep Steam out, which also
      #     blocks SDL's HIDAPI Nintendo backend from opening the device.
      # Without joycond, SDL owns the raw hidraw node and decodes gyro/accel
      # itself (SDL-native motion), which Eden/yuzu read directly — no cemuhook
      # UDP bridge required. joycond is only worth enabling to combine two
      # single Joy-Cons into one virtual pad, which is not our use case.
      # services.joycond.enable = true;
      # programs.joycond-cemuhook.enable = true;
    })
  ];
}
