{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  toSBSecret = acc: name: {
    path,
    mode ? "0440",
  }: (acc
    // {
      "${name}" = {
        inherit mode;

        sopsFile = ../../../secrets/secureboot.yaml;
        owner = "root";
        path = "/var/lib/sbctl/${path}";
      };
    });
in {
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  options.rat.boot.lanzaboote.enable = mkEnableOption "lanzaboote";

  config = mkIf config.rat.boot.lanzaboote.enable {
    assertions = [
      {
        assertion = !config.rat.boot.systemd-boot.enable;
        message = "Lanzaboote requires that `systemd-boot` not be enabled.";
      }
    ];

    environment.systemPackages = [
      pkgs.sbctl
    ];

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    sops.secrets = lib.attrsets.foldlAttrs toSBSecret {} {
      "guid" = {
        path = "GUID";
        mode = "0644";
      };
      "db/key" = {path = "db/db.key";};
      "db/pem" = {path = "db/db.pem";};
      "KEK/key" = {path = "KEK/KEK.key";};
      "KEK/pem" = {path = "KEK/KEK.pem";};
      "PK/key" = {path = "PK/PK.key";};
      "PK/pem" = {path = "PK/PK.pem";};
    };

    system.activationScripts.lanzabooteCreateEmptyFilesJson.text = ''
      touch /var/lib/sbctl/files.json
    '';
  };
}
