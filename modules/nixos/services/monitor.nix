{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.serviceMonitor;
in {
  options.rat.serviceMonitor = {
    enable = options.mkEnableOption "system monitor on `tty1`.";
  };

  config = modules.mkIf cfg.enable {
    environment.systemPackages = [pkgs.bottom];

    systemd.services."getty@tty1" = {
      overrideStrategy = "asDropin";
      serviceConfig.ExecStart = [
        ""
        "${pkgs.bottom}/bin/btm --config_location ${config.catppuccin.sources.bottom}/${config.catppuccin.flavor}.toml"
      ];
    };
  };
}
