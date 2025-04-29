{
  config,
  pkgs,
  lib,
  ...
}: let
  servarr = import ./settings-options.nix {inherit lib pkgs;};

  instanceOpts = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "Whisparr instance ${name}";

      package = lib.mkPackageOption pkgs "whisparr" {};

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/whisparr-${name}/.config/Whisparr";
        description = "The directory where Whisparr instance ${name} stores its data files.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for the Whisparr web interface of instance ${name}.";
      };

      settings = servarr.mkServarrSettingsOptions "whisparr-${name}" (6969 + instanceNum name);

      environmentFiles = servarr.mkServarrEnvironmentFiles "whisparr-${name}";

      user = lib.mkOption {
        type = lib.types.str;
        default = "whisparr-${name}";
        description = "User account under which Whisparr instance ${name} runs.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "whisparr-${name}";
        description = "Group under which Whisparr instance ${name} runs.";
      };
    };
  };

  instanceNum = name: let
    suffixNum = lib.strings.toInt (builtins.elemAt (builtins.match ".*([0-9]+)$" name) 0);
  in
    if builtins.match ".*[0-9]+$" name != null
    then suffixNum
    else 0;

  cfg = config.services.whisparr;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
in {
  options = {
    services.whisparr = {
      instances = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule instanceOpts);
        default = {};
        description = "Defined Whisparr instances.";
        example = lib.literalExpression ''
          {
            main = {
              enable = true;
              openFirewall = true;
              settings.server.port = 6969;
            };
            vintage = {
              enable = true;
              openFirewall = true;
              user = "whisparr-vintage";
              settings.server.port = 6970;
            };
          }
        '';
      };

      enable = lib.mkEnableOption "Whisparr (deprecated, use instances.<name>.enable instead)";
      package = lib.mkPackageOption pkgs "whisparr" {};
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/whisparr/.config/Whisparr";
        description = "The directory where Whisparr stores its data files (deprecated).";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for the Whisparr web interface (deprecated).";
      };
      settings = servarr.mkServarrSettingsOptions "whisparr" 6969;
      environmentFiles = servarr.mkServarrEnvironmentFiles "whisparr";
      user = lib.mkOption {
        type = lib.types.str;
        default = "whisparr";
        description = "User account under which Whisparr runs (deprecated).";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "whisparr";
        description = "Group under which Whisparr runs (deprecated).";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.whisparr.instances.default = {
        enable = true;
        inherit (cfg) package dataDir openFirewall settings environmentFiles user group;
      };

      warnings = [
        "services.whisparr.enable is deprecated, use services.whisparr.instances.<name>.enable instead."
      ];
    })

    {
      systemd.tmpfiles.rules = lib.concatLists (lib.mapAttrsToList (name: instance: [
          "d '${instance.dataDir}' 0700 ${instance.user} ${instance.group} - -"
        ])
        enabledInstances);

      systemd.services = lib.mapAttrs' (name: instance:
        lib.nameValuePair "whisparr-${name}" {
          description = "Whisparr (${name})";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];
          environment = servarr.mkServarrSettingsEnvVars "WHISPARR" instance.settings;
          serviceConfig = {
            Type = "simple";
            User = instance.user;
            Group = instance.group;
            EnvironmentFile = instance.environmentFiles;
            ExecStart = "${lib.getExe instance.package} -nobrowser -data='${instance.dataDir}'";
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
              lib.mkIf (instance.user == "whisparr-${name}") {
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
              lib.mkIf (instance.group == "whisparr-${name}") {}
            )
        )
        enabledInstances;
    }
  ];
}
