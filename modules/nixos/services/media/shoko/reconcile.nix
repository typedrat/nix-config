{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.shoko;

  stateDir = "/var/lib/shoko-reconcile";
  api = "${config.links.shoko.url}/api";
  passwordFile = config.sops.secrets."shoko/admin/password".path;

  # Secrets reach curl only through files: the request body is written by jq
  # straight from the sops file, and nothing secret is ever an argument.
  script = pkgs.writeShellApplication {
    name = "shoko-reconcile";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.coreutils];
    text = ''
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      # Init/Status answers without authentication once the API is up.
      deadline=$((SECONDS + 600))
      while :; do
        state=$(curl -sf ${lib.escapeShellArg "${api}/v3/Init/Status"} | jq -r '.State' || true)
        case "$state" in
          Started) break ;;
          Failed)
            echo "Shoko failed to start" >&2
            exit 1
            ;;
        esac
        if ((SECONDS >= deadline)); then
          echo "timed out waiting for Shoko to start (state: ''${state:-unreachable})" >&2
          exit 1
        fi
        sleep 5
      done

      # Signs in as the admin user under the given device name. Shoko keeps
      # one token per user and device, so the same device always gets the
      # same token back.
      sign_in() {
        jq -n --arg user ${lib.escapeShellArg cfg.adminUser} --rawfile pass ${lib.escapeShellArg passwordFile} --arg device "$1" \
          '{User: $user, Password: ($pass | rtrimstr("\n")), Device: $device}' >"$tmp/request"
        code=$(curl -s -o "$tmp/response" -w '%{http_code}' \
          -H 'Content-Type: application/json' --data-binary @"$tmp/request" \
          ${lib.escapeShellArg "${api}/v3/Auth/SignIn"})
        case "$code" in
          200) jq -r '.Token' "$tmp/response" ;;
          401)
            echo "Shoko rejected the password for ${cfg.adminUser}: secrets/shoko.yaml and Shoko disagree" >&2
            return 1
            ;;
          *)
            echo "signing in to Shoko failed with HTTP $code" >&2
            return 1
            ;;
        esac
      }

      ${lib.concatStrings (lib.mapAttrsToList (name: key: ''
          sign_in ${lib.escapeShellArg key.device} >"$tmp/${name}.key"
          install -m 0640 -g ${lib.escapeShellArg key.group} "$tmp/${name}.key" ${lib.escapeShellArg "${stateDir}/${name}.key"}
        '')
        cfg.apiKeys)}
      echo "Shoko reconciled"
    '';
  };
in {
  options.rat.services.shoko.apiKeys = options.mkOption {
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        device = options.mkOption {
          type = types.str;
          default = name;
          description = "Device name the key is issued under; Shoko lists keys by it.";
        };
        group = options.mkOption {
          type = types.str;
          description = "Group allowed to read the key file.";
        };
      };
    }));
    default = {};
    description = ''
      API keys issued to the admin user and written to
      ${stateDir}/<name>.key, for services that talk to Shoko. Each key is
      created on first use and stays the same from then on.
    '';
  };

  config = modules.mkIf cfg.enable {
    sops.secrets."shoko/admin/password" = {
      sopsFile = ../../../../../secrets/shoko.yaml;
      key = "users/${cfg.adminUser}/password";
    };

    systemd.services.shoko-reconcile = {
      description = "Bring Shoko's configuration in line with Nix";
      after = ["shoko.service"];
      requires = ["shoko.service"];
      wantedBy = ["multi-user.target"];
      # Re-run whenever Shoko restarts, since that is when its state is reread.
      partOf = ["shoko.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe script;
        StateDirectory = "shoko-reconcile";
        # Readers of the key files need to get into the directory, not list it.
        StateDirectoryMode = "0711";
        UMask = "0077";
        PrivateTmp = true;
      };
    };
  };
}
