{
  config,
  pkgs,
  lib,
  ...
}: let
  servarr = import ./settings-options.nix {inherit lib pkgs;};
  instanceOpts = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "Readarr instance ${name}";

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/readarr-${name}/";
        description = "The directory where Readarr instance ${name} stores its data files.";
      };

      package = lib.mkPackageOption pkgs "readarr" {};

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Open ports in the firewall for Readarr instance ${name}
        '';
      };

      settings = servarr.mkServarrSettingsOptions "readarr-${name}" (8787 + instanceNum name);

      environmentFiles = servarr.mkServarrEnvironmentFiles "readarr-${name}";

      user = lib.mkOption {
        type = lib.types.str;
        default = "readarr-${name}";
        description = ''
          User account under which Readarr instance ${name} runs.
        '';
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "readarr-${name}";
        description = ''
          Group under which Readarr instance ${name} runs.
        '';
      };
    };
  };
  instanceNum = name: let
    suffixNum = lib.strings.toInt (builtins.elemAt (builtins.match ".*([0-9]+)$" name) 0);
  in
    if builtins.match ".*[0-9]+$" name != null
    then suffixNum
    else 0;
  cfg = config.services.readarr;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
in {
  options = {
    services.readarr = {
      instances = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule instanceOpts);
        default = {};
        description = "Defined Readarr instances.";
        example = lib.literalExpression ''
          {
            main = {
              enable = true;
              openFirewall = true;
              settings.server.port = 8787;
            };
            comics = {
              enable = true;
              openFirewall = true;
              user = "readarr-comics";
              settings.server.port = 8788;
            };
          }
        '';
      };
      enable = lib.mkEnableOption "Readarr (deprecated, use instances.<name>.enable instead)";
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/readarr/";
        description = "The directory where Readarr stores its data files (deprecated).";
      };
      package = lib.mkPackageOption pkgs "readarr" {};
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for Readarr (deprecated).";
      };
      settings = servarr.mkServarrSettingsOptions "readarr" 8787;
      environmentFiles = servarr.mkServarrEnvironmentFiles "readarr";
      user = lib.mkOption {
        type = lib.types.str;
        default = "readarr";
        description = "User account under which Readarr runs (deprecated).";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "readarr";
        description = "Group under which Readarr runs (deprecated).";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.readarr.instances.default = {
        enable = true;
        inherit (cfg) dataDir package openFirewall settings environmentFiles user group;
      };

      warnings = [
        "services.readarr.enable is deprecated, use services.readarr.instances.<name>.enable instead."
      ];
    })
    {
      systemd.tmpfiles.settings =
        lib.mapAttrs' (
          name: instance:
            lib.nameValuePair "10-readarr-${name}" {
              ${instance.dataDir}.d = {
                user = instance.user;
                group = instance.group;
                mode = "0700";
              };
            }
        )
        enabledInstances;

      systemd.services = lib.mapAttrs' (name: instance:
        lib.nameValuePair "readarr-${name}" {
          description = "Readarr (${name})";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];
          environment = servarr.mkServarrSettingsEnvVars "READARR" instance.settings;
          serviceConfig = {
            Type = "simple";
            User = instance.user;
            Group = instance.group;
            EnvironmentFile = instance.environmentFiles;
            ExecStart = "${instance.package}/bin/Readarr -nobrowser -data='${instance.dataDir}'";
            Restart = "on-failure";
          };
        })
      enabledInstances;

      networking.firewall.allowedTCPPorts = lib.concatMap (
        instance:
          lib.optional instance.openFirewall instance.settings.server.port
      ) (lib.attrValues enabledInstances);

      users.users =
        lib.mapAttrs' (
          name: instance:
            lib.nameValuePair instance.user (
              lib.mkIf (instance.user == "readarr-${name}") {
                description = "Readarr service (${name})";
                group = instance.group;
                home = instance.dataDir;
                isSystemUser = true;
              }
            )
        )
        enabledInstances;

      users.groups =
        lib.mapAttrs' (
          name: instance:
            lib.nameValuePair instance.group (
              lib.mkIf (instance.group == "readarr-${name}") {}
            )
        )
        enabledInstances;
    }
  ];
}
