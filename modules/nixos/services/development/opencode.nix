{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.opencode;

  # Check if any enabled user has opencode (cli.ai) enabled
  anyUserHasOpencode = lib.any (
    userCfg: userCfg.enable && (userCfg.cli.enable or false) && (userCfg.cli.ai.enable or false)
  ) (lib.attrValues config.rat.users);
in {
  options.rat.opencode = {
    enable = options.mkOption {
      type = types.bool;
      default = anyUserHasOpencode;
      defaultText = lib.literalExpression "true if any enabled user has cli.ai enabled";
      description = "Whether to enable OpenCode system-level configuration.";
    };

    openFirewall = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open port 4096 in the firewall for OpenCode.";
    };

    port = options.mkOption {
      type = types.port;
      default = 4096;
      description = "The port to open for OpenCode.";
    };
  };

  config = modules.mkIf (cfg.enable && cfg.openFirewall) {
    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
