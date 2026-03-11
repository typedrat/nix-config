{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.tv-power.enable or false)) {
    sops.secrets = {
      vizioAuth = {};
      vizioIp = {};
    };

    home.packages = [
      (pkgs.writeShellApplication {
        name = "tv-power";
        runtimeInputs = [pkgs.python3Packages.pyvizio];
        text = ''
          if [ "$#" -ne 1 ] || { [ "$1" != "on" ] && [ "$1" != "off" ]; }; then
            echo "Usage: tv-power [on|off]" >&2
            exit 1
          fi

          export VIZIO_IP VIZIO_AUTH
          VIZIO_IP=$(cat ${config.sops.secrets.vizioIp.path})
          VIZIO_AUTH=$(cat ${config.sops.secrets.vizioAuth.path})
          pyvizio power "$1"
        '';
      })
    ];
  };
}
