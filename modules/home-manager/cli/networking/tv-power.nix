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

  hasSecrets = builtins.pathExists (config.rat.userSecretsDir + "/vizio.yaml");
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.networking.enable && hasSecrets) {
    rat.userSecrets.vizio = {
      auth = {};
      ip = {};
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
          VIZIO_IP=$(cat ${config.sops.secrets."vizio/ip".path})
          VIZIO_AUTH=$(cat ${config.sops.secrets."vizio/auth".path})
          pyvizio power "$1"
        '';
      })
    ];
  };
}
