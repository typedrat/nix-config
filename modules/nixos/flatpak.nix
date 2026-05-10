{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.rat.flatpak;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.flatpak.enable = mkEnableOption "Flatpak";

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = config.rat.gui.enable;
          message = "Flatpak requires a graphical system (rat.gui.enable).";
        }
      ];

      services.flatpak.enable = true;
    }

    # System-level state must survive ZFS-rollback impermanence so installed
    # runtimes/apps and the configured remotes persist across reboots.
    (mkIf impermanenceCfg.enable {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          "/var/lib/flatpak"
        ];
      };
    })
  ]);
}
