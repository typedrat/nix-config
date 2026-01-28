{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.boot;
in {
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  config = modules.mkIf (cfg.loader == "lanzaboote") {
    boot.lanzaboote = {
      enable = true;
      inherit (cfg.secureBoot) pkiBundle;

      autoEnrollKeys = {
        enable = cfg.secureBoot.autoEnrollKeys;
      };
    };
  };
}
