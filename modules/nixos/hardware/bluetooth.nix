{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.rat.bluetooth;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.bluetooth.enable =
    mkEnableOption "bluetooth"
    // {
      default = config.rat.gui.enable;
    };

  config = mkMerge [
    (mkIf cfg.enable {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General = {
            Enable = "Source,Sink,Media,Socket";
            Experimental = true;
          };
        };
      };

      services.blueman.enable = mkIf config.rat.gui.enable true;

      services.pipewire.wireplumber.configPackages = mkIf config.rat.audio.enable [
        (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-bluez.conf" ''
          monitor.bluez.properties = {
          bluez5.roles = [ a2dp_sink a2dp_source bap_sink bap_source hsp_hs hsp_ag hfp_hf hfp_ag ]
          bluez5.codecs = [ sbc sbc_xq aac ]
          bluez5.enable-sbc-xq = true
          bluez5.hfphsp-backend = "native"
          }
        '')
      ];
    })
    (mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = ["/var/lib/bluetooth"];
      };
    })
  ];
}
