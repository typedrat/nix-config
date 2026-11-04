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

  # CEC acts within a second where SmartCast takes around thirty, and it can
  # also switch the TV's input, so hosts with CEC never touch the network.
  hasCec = osConfig.rat.hardware.cec.enable or false;
  hasSecrets = builtins.pathExists (config.rat.userSecretsDir + "/vizio.yaml");
  useVizio = !hasCec && hasSecrets;

  checkUsage = ''
    if [ "$#" -ne 1 ] || { [ "$1" != "on" ] && [ "$1" != "off" ]; }; then
      echo "Usage: tv-power [on|off]" >&2
      exit 1
    fi
  '';

  cecPower = pkgs.writeShellApplication {
    name = "tv-power";
    runtimeInputs = [pkgs.v4l-utils pkgs.gawk pkgs.gnugrep];
    text = ''
      ${checkUsage}

      # cec-ctl exits 0 even when a message goes unacknowledged. --verbose
      # makes it print every transmit status, so success means a "Tx, OK".
      send() {
        local out
        if ! out=$(cec-ctl --verbose "$@") || ! grep -q 'Tx, OK' <<<"$out"; then
          echo "tv-power: CEC transmit failed: cec-ctl $*" >&2
          return 1
        fi
      }

      case "$1" in
        on)
          # One Touch Play: wake the TV, then announce this machine as the
          # active source so the TV and any receiver in between switch to it.
          addr=$(cec-ctl | awk -F': ' '/Physical Address/ { print $2; exit }')
          if [ -z "$addr" ] || [ "$addr" = "f.f.f.f" ]; then
            echo "tv-power: no CEC physical address; is the TV connected?" >&2
            exit 1
          fi
          send --to 0 --image-view-on
          send --active-source "phys-addr=$addr"
          ;;
        off)
          send --to 0 --standby
          ;;
      esac
    '';
  };

  vizioPower = pkgs.writeShellApplication {
    name = "tv-power";
    # nixpkgs keeps the CLI's dependencies behind the `cli` extra, so the
    # bare package's `vizaio` entry point refuses to start.
    runtimeInputs = [
      (pkgs.python3.withPackages (ps: [ps.vizaio] ++ ps.vizaio.optional-dependencies.cli))
    ];
    text = ''
      ${checkUsage}

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
  };
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.networking.enable && (hasCec || hasSecrets)) {
    rat.userSecrets.vizio = modules.mkIf useVizio {
      auth = {};
      ip = {};
    };

    home.packages = [
      (
        if hasCec
        then cecPower
        else vizioPower
      )
    ];
  };
}
