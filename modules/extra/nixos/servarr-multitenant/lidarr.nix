{
  config,
  pkgs,
  lib,
  ...
}: let
  servarr = import ./settings-options.nix {inherit lib pkgs;};

  instanceOpts = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "Lidarr instance ${name}";

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/lidarr-${name}/.config/Lidarr";
        description = "The directory where Lidarr instance ${name} stores its data files.";
      };

      package = lib.mkPackageOption pkgs "lidarr" {};

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Open ports in the firewall for Lidarr instance ${name}
        '';
      };

      settings = servarr.mkServarrSettingsOptions "lidarr-${name}" (8686 + instanceNum name);

      environmentFiles = servarr.mkServarrEnvironmentFiles "lidarr-${name}";

      user = lib.mkOption {
        type = lib.types.str;
        default = "lidarr-${name}";
        description = ''
          User account under which Lidarr instance ${name} runs.
        '';
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "lidarr-${name}";
        description = ''
          Group under which Lidarr instance ${name} runs.
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

  cfg = config.services.lidarr;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
in {
  options = {
    services.lidarr = {
      instances = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule instanceOpts);
        default = {};
        description = "Defined Lidarr instances.";
        example = lib.literalExpression ''
          {
            main = {
              enable = true;
              openFirewall = true;
              settings.server.port = 8686;
            };
            secondary = {
              enable = true;
              openFirewall = true;
              user = "lidarr-secondary";
              settings.server.port = 8687;
            };
          }
        '';
      };

      enable = lib.mkEnableOption "Lidarr (deprecated, use instances.<name>.enable instead)";
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/lidarr/.config/Lidarr";
        description = "The directory where Lidarr stores its data files (deprecated).";
      };
      package = lib.mkPackageOption pkgs "lidarr" {};
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for Lidarr (deprecated).";
      };
      settings = servarr.mkServarrSettingsOptions "lidarr" 8686;
      environmentFiles = servarr.mkServarrEnvironmentFiles "lidarr";
      user = lib.mkOption {
        type = lib.types.str;
        default = "lidarr";
        description = "User account under which Lidarr runs (deprecated).";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "lidarr";
        description = "Group under which Lidarr runs (deprecated).";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.lidarr.instances.default = {
        enable = true;
        inherit (cfg) dataDir package openFirewall settings environmentFiles user group;
      };

      warnings = [
        "services.lidarr.enable is deprecated, use services.lidarr.instances.<name>.enable instead."
      ];
    })

    {
      systemd.tmpfiles.settings =
        lib.mapAttrs' (
          name: instance:
            lib.nameValuePair "10-lidarr-${name}" {
              ${instance.dataDir}.d = {
                inherit (instance) user;
                inherit (instance) group;
                mode = "0700";
              };
            }
        )
        enabledInstances;

      systemd.services = lib.mapAttrs' (name: instance:
        lib.nameValuePair "lidarr-${name}" {
          description = "Lidarr (${name})";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];
          environment = servarr.mkServarrSettingsEnvVars "LIDARR" instance.settings;
          serviceConfig = {
            Type = "simple";
            User = instance.user;
            Group = instance.group;
            EnvironmentFile = instance.environmentFiles;
            ExecStart = "${instance.package}/bin/Lidarr -nobrowser -data='${instance.dataDir}'";
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
              lib.mkIf (instance.user == "lidarr-${name}") {
                inherit (instance) group;
                home = "/var/lib/lidarr-${name}";
                isSystemUser = true;
              }
            )
        )
        enabledInstances;

      users.groups =
        lib.mapAttrs' (
          name: instance:
            lib.nameValuePair instance.group (
              lib.mkIf (instance.group == "lidarr-${name}") {}
            )
        )
        enabledInstances;
    }
  ];
}
