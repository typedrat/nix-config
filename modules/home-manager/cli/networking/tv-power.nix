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
        runtimeInputs = [pkgs.vizaio];
        text = ''
          if [ "$#" -ne 1 ] || { [ "$1" != "on" ] && [ "$1" != "off" ]; }; then
            echo "Usage: tv-power [on|off]" >&2
            exit 1
          fi

          host=$(cat ${config.sops.secrets."vizio/ip".path})
          # vizaio never assumes a port, so a bare IP would be dialled on 443
          # and time out. SmartCast TVs from 2016 on listen on 7345.
          case "$host" in
            *:*) ;;
            *) host="$host:7345" ;;
          esac

          # The auth token goes through a config file rather than --auth so it
          # never appears in this process's argv.
          tmp=$(mktemp -d)
          trap 'rm -rf -- "$tmp"' EXIT
          export VIZAIO_CONFIG="$tmp/config.toml"
          cat >"$VIZAIO_CONFIG" <<EOF
          default_device = "tv"

          [devices.tv]
          host = "$host"
          device_type = "tv"
          auth_token = "$(cat ${config.sops.secrets."vizio/auth".path})"
          EOF

          vizaio power "$1"
        '';
      })
    ];
  };
}
