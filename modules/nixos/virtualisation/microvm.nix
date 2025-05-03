{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.virtualisation.microvm;
  impermanenceCfg = config.rat.impermanence;
in {
  imports = [
    inputs.microvm.nixosModules.host
  ];

  options.rat.virtualisation.microvm = {
    enable = options.mkEnableOption "MicroVMs";
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      microvm.host = {
        enable = true;
        useNotifySockets = true;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/microvms";
            user = "microvm";
            group = "kvm";
            mode = "0755";
          }
        ];
      };
    })
  ];
}
