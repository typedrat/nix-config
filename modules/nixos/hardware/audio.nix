{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.audio.enable =
    mkEnableOption "audio"
    // {
      default = config.rat.gui.enable;
    };

  config = mkIf config.rat.audio.enable {
    # MAONO PD200X USB microphone (352f:0104) - capture doesn't work without this
    # The device has an INV_BOOLEAN mute control that Linux handles incorrectly
    environment.etc."wireplumber/main.lua.d/51-maono-pd200x.lua".text = ''
      rule = {
        matches = {
          {
            { "device.vendor.id", "equals", "13615" },
            { "device.product.id", "equals", "260" },
          },
        },
        apply_properties = {
          ["api.alsa.use-acp"] = false,
        },
      }

      table.insert(alsa_monitor.rules, rule)
    '';

    security.rtkit.enable = true;
    security.pam.loginLimits = [
      {
        domain = "@audio";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
      {
        domain = "@audio";
        item = "rtprio";
        type = "-";
        value = "99";
      }
      {
        domain = "@audio";
        item = "nice";
        type = "-";
        value = "-19";
      }
    ];
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      extraConfig.pipewire = {
        "10-please-stop-stuttering" = {
          "context.properties" = {
            "default.min-quantum" = 512;
          };
        };
      };
    };
  };
}
