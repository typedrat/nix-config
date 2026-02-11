{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.rat.gui;
  impermanenceCfg = config.rat.impermanence;
in {
  config = mkMerge [
    (mkIf (cfg.enable && cfg.greeter.variant == "sddm") {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
        settings.General.GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
        settings.Wayland.CompositorCommand = "${lib.getExe config.programs.hyprland.package}";
      };
    })
    (mkIf (cfg.enable && cfg.greeter.variant == "sddm" && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = ["/var/lib/sddm"];
      };
    })
  ];
}
