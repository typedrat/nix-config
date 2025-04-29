{
  config,
  pkgs,
  lib,
  ...
}: let
  servarr = import ./settings-options.nix {inherit lib pkgs;};
  instanceOpts = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "Radarr instance ${name}";

      package = lib.mkPackageOption pkgs "radarr" {};

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/radarr-${name}/.config/Radarr";
        description = "The directory where Radarr instance ${name} stores its data files.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for the Radarr web interface of instance ${name}.";
      };

      settings = servarr.mkServarrSettingsOptions "radarr-${name}" (7878 + instanceNum name);

      environmentFiles = servarr.mkServarrEnvironmentFiles "radarr-${name}";

      user = lib.mkOption {
        type = lib.types.str;
        default = "radarr-${name}";
        description = "User account under which Radarr instance ${name} runs.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "radarr-${name}";
        description = "Group under which Radarr instance ${name} runs.";
      };
    };
  };
  instanceNum = name: let
    suffixNum = lib.strings.toInt (builtins.elemAt (builtins.match ".*([0-9]+)$" name) 0);
  in
    if builtins.match ".*[0-9]+$" name != null
    then suffixNum
    else 0;
  cfg = config.services.radarr;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
in {
  options = {
    services.radarr = {
      instances = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule instanceOpts);
        default = {};
        description = "Defined Radarr instances.";
        example = lib.literalExpression ''
          {
            main = {
              enable = true;
              openFirewall = true;
              settings.server.port = 7878;
            };
            indie = {
              enable = true;
              openFirewall = true;
              user = "radarr-indie";
              settings.server.port = 7879;
            };
          }
        '';
      };
      enable = lib.mkEnableOption "Radarr (deprecated, use instances.<name>.enable instead)";
      package = lib.mkPackageOption pkgs "radarr" {};
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/radarr/.config/Radarr";
        description = "The directory where Radarr stores its data files (deprecated).";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for the Radarr web interface (deprecated).";
      };
      settings = servarr.mkServarrSettingsOptions "radarr" 7878;
      environmentFiles = servarr.mkServarrEnvironmentFiles "radarr";
      user = lib.mkOption {
        type = lib.types.str;
        default = "radarr";
        description = "User account under which Radarr runs (deprecated).";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "radarr";
        description = "Group under which Radarr runs (deprecated).";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.radarr.instances.default = {
        enable = true;
        inherit (cfg) package dataDir openFirewall settings environmentFiles user group;
      };

      warnings = [
        "services.radarr.enable is deprecated, use services.radarr.instances.<name>.enable instead."
      ];
    })
    {
      systemd.tmpfiles.settings =
        lib.mapAttrs' (
          name: instance:
            lib.nameValuePair "10-radarr-${name}" {
              ${instance.dataDir}.d = {
                user = instance.user;
                group = instance.group;
                mode = "0700";
              };
            }
        )
        enabledInstances;

      systemd.services = lib.mapAttrs' (name: instance:
        lib.nameValuePair "radarr-${name}" {
          description = "Radarr (${name})";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];
          environment = servarr.mkServarrSettingsEnvVars "RADARR" instance.settings;
          serviceConfig = {
            Type = "simple";
            User = instance.user;
            Group = instance.group;
            EnvironmentFile = instance.environmentFiles;
            ExecStart = "${instance.package}/bin/Radarr -nobrowser -data='${instance.dataDir}'";
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
              lib.mkIf (instance.user == "radarr-${name}") {
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
              lib.mkIf (instance.group == "radarr-${name}") {}
            )
        )
        enabledInstances;
    }
  ];
}
