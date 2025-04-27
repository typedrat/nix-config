{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.services.prometheus.exporters;
in {
  options.rat.services.prometheus.exporters.ipmi = {
    enable = options.mkEnableOption "IPMI exporter";
  };

  config = modules.mkIf (cfg.enable && cfg.ipmi.enable) {
    services.prometheus.exporters.ipmi = {
      enable = true;
      user = "root";
      group = "ipmi"; # Changed from root to ipmi
      extraFlags = ["--native-ipmi"];
      inherit (config.links.prometheus-ipmi) port;
    };

    # Create ipmi group and configure necessary permissions
    users.groups.ipmi = {};

    # Give the ipmi group access to the necessary devices
    services.udev.extraRules = ''
      KERNEL=="ipmi*", GROUP="ipmi", MODE="0660"
    '';

    # Ensure the ipmi kernel module is loaded
    boot.kernelModules = ["ipmi_devintf"];

    links.prometheus-ipmi = {
      protocol = "http";
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "ipmi";
        static_configs = [
          {
            targets = [config.links.prometheus-ipmi.tuple];
          }
        ];
      }
    ];
  };
}
