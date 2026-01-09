{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) options modules types;
  cfg = config.rat.boot;
  impermanenceCfg = config.rat.impermanence;
in {
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  options.rat.boot.secureBoot = {
    pkiBundle = options.mkOption {
      type = types.path;
      default = "/var/lib/sbctl";
      description = "Path to the Secure Boot PKI bundle";
    };

    autoEnrollKeys = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to automatically enroll Secure Boot keys on first boot";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf (cfg.loader == "lanzaboote") {
      environment.systemPackages = [
        pkgs.sbctl
      ];

      boot.lanzaboote = {
        enable = true;
        inherit (cfg.secureBoot) pkiBundle;

        autoEnrollKeys = {
          enable = cfg.secureBoot.autoEnrollKeys;
        };
      };
    })
    (modules.mkIf (cfg.loader == "lanzaboote" && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          cfg.secureBoot.pkiBundle
        ];
      };
    })
  ];
}
