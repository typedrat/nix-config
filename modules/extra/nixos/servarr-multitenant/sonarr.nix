{
  config,
  pkgs,
  lib,
  utils,
  ...
}: let
  servarr = import ./settings-options.nix {inherit lib pkgs;};

  instanceOpts = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "Sonarr instance ${name}";

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/sonarr-${name}/.config/NzbDrone";
        description = "The directory where Sonarr instance ${name} stores its data files.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Open ports in the firewall for the Sonarr web interface of instance ${name}
        '';
      };

      environmentFiles = servarr.mkServarrEnvironmentFiles "sonarr-${name}";

      settings = servarr.mkServarrSettingsOptions "sonarr-${name}" (8989 + instanceNum name);

      user = lib.mkOption {
        type = lib.types.str;
        default = "sonarr-${name}";
        description = "User account under which Sonarr instance ${name} runs.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "sonarr-${name}";
        description = "Group under which Sonarr instance ${name} runs.";
      };

      package = lib.mkPackageOption pkgs "sonarr" {};
    };
  };

  instanceNum = name: let
    suffixNum = lib.strings.toInt (builtins.elemAt (builtins.match ".*([0-9]+)$" name) 0);
  in
    if builtins.match ".*[0-9]+$" name != null
    then suffixNum
    else 0;

  cfg = config.services.sonarr;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
in {
  options = {
    services.sonarr = {
      instances = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule instanceOpts);
        default = {};
        description = "Defined Sonarr instances.";
        example = lib.literalExpression ''
          {
            main = {
              enable = true;
              openFirewall = true;
              settings.server.port = 8989;
            };
            anime = {
              enable = true;
              openFirewall = true;
              user = "sonarr-anime";
              settings.server.port = 8990;
            };
          }
        '';
      };

      # For backward compatibility
      enable = lib.mkEnableOption "Sonarr (deprecated, use instances.<name>.enable instead)";
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/sonarr/.config/NzbDrone";
        description = "The directory where Sonarr stores its data files (deprecated).";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for the Sonarr web interface (deprecated).";
      };
      environmentFiles = servarr.mkServarrEnvironmentFiles "sonarr";
      settings = servarr.mkServarrSettingsOptions "sonarr" 8989;
      user = lib.mkOption {
        type = lib.types.str;
        default = "sonarr";
        description = "User account under which Sonarr runs (deprecated).";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "sonarr";
        description = "Group under which Sonarr runs (deprecated).";
      };
      package = lib.mkPackageOption pkgs "sonarr" {};
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.sonarr.instances.default = {
        enable = true;
        inherit (cfg) dataDir openFirewall environmentFiles settings user group package;
      };

      warnings = [
        "services.sonarr.enable is deprecated, use services.sonarr.instances.<name>.enable instead."
      ];
    })

    {
      systemd.tmpfiles.rules = lib.concatLists (lib.mapAttrsToList (_name: instance: [
          "d '${instance.dataDir}' 0700 ${instance.user} ${instance.group} - -"
        ])
        enabledInstances);

      systemd.services = lib.mapAttrs' (name: instance:
        lib.nameValuePair "sonarr-${name}" {
          description = "Sonarr (${name})";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];
          environment = servarr.mkServarrSettingsEnvVars "SONARR" instance.settings;
          serviceConfig = {
            Type = "simple";
            User = instance.user;
            Group = instance.group;
            EnvironmentFile = instance.environmentFiles;
            ExecStart = utils.escapeSystemdExecArgs [
              (lib.getExe instance.package)
              "-nobrowser"
              "-data=${instance.dataDir}"
            ];
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
          _name: instance:
            lib.nameValuePair instance.user (
              lib.mkIf (lib.hasPrefix "sonarr-" instance.user) {
                inherit (instance) group;
                home = instance.dataDir;
                isSystemUser = true;
              }
            )
        )
        enabledInstances;

      users.groups =
        lib.mapAttrs' (
          _name: instance:
            lib.nameValuePair instance.group (
              lib.mkIf (lib.hasPrefix "sonarr-" instance.group) {}
            )
        )
        enabledInstances;
    }
  ];
}
