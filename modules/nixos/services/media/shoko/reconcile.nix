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
  releaseProvidersFile = pkgs.writeText "shoko-release-providers.json" (builtins.toJSON cfg.releaseProviders);

  # Secrets reach curl only through files: the request body is written by jq
  # straight from the sops file, and nothing secret is ever an argument.
  script = pkgs.writeShellApplication {
    name = "shoko-reconcile";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.coreutils];
    text = ''
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      # Init/Status answers without authentication once the API is up. Shoko
      # can spend a long time migrating its database on the first start of a
      # new version, so there is no deadline; a failed start ends the wait.
      while :; do
        state=$(curl -sf ${lib.escapeShellArg "${api}/v3/Init/Status"} | jq -r '.State' || true)
        case "$state" in
          Started) break ;;
          Failed)
            echo "Shoko failed to start" >&2
            exit 1
            ;;
        esac
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
      ${lib.optionalString (cfg.releaseProviders != {}) ''
        token=$(sign_in shoko-reconcile)
        printf 'apikey: %s\n' "$token" >"$tmp/auth"
        curl -sf -H @"$tmp/auth" ${lib.escapeShellArg "${api}/v3/ReleaseInfo/Provider"} >"$tmp/providers"
        # Providers are configured by name; their IDs are opaque.
        jq --slurpfile want ${releaseProvidersFile} '
          . as $have | $want[0] | to_entries | map(
            .key as $name
            | ($have | map(select(.Name == $name)) | first
                // error("Shoko has no release provider named \($name)")) as $p
            | {ID: $p.ID, IsEnabled: .value.enable}
              + (if .value.priority == null then {} else {Priority: .value.priority} end))
        ' "$tmp/providers" >"$tmp/request"
        code=$(curl -s -o "$tmp/response" -w '%{http_code}' -H @"$tmp/auth" \
          -H 'Content-Type: application/json' --data-binary @"$tmp/request" \
          ${lib.escapeShellArg "${api}/v3/ReleaseInfo/Provider"})
        if [[ $code != 2* ]]; then
          echo "updating Shoko's release providers failed with HTTP $code: $(head -c 500 "$tmp/response")" >&2
          exit 1
        fi
      ''}
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

  options.rat.services.shoko.releaseProviders = options.mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        enable = options.mkOption {
          type = types.bool;
          description = "Whether Shoko asks this provider for release information.";
        };
        priority = options.mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Order among enabled providers, lowest first; null leaves Shoko's order alone.";
        };
      };
    });
    default = {};
    example = {"Offline Importer".enable = true;};
    description = ''
      Release providers to switch on or off, by the name Shoko lists them
      under. Providers not named here keep whatever state Shoko has.
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
        # Not oneshot: waiting out a database migration would hold up the
        # switch that started it. Consumers wait for the key files instead.
        Type = "exec";
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
