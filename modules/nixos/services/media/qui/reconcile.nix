{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.qui;
  json = pkgs.formats.json {};

  stateDir = "/var/lib/qui-reconcile";
  database = "/var/lib/qui/qui.db";
  api = "${config.links.qui.url}/api";
  prowlarrApiKeyFile = config.sops.secrets."prowlarr/apiKey".path;

  # Everything the script needs from Nix, with secrets as file paths so their
  # contents only ever reach curl through request files.
  desiredFile = json.generate "qui-desired.json" {
    inherit (cfg) instanceName instance automations;
    arrInstances =
      lib.mapAttrs (_: arr: {
        inherit (arr) type url apiKeyFile enabled;
      })
      cfg.arrInstances;
    indexers = lib.mapAttrs (_: idx: {inherit (idx) prowlarrName enabled;}) cfg.indexers;
    crossSeed = {
      inherit (cfg.crossSeed) settings indexers;
    };
    prowlarr = {
      url = config.links.prowlarr.url;
      apiKeyFile = prowlarrApiKeyFile;
    };
  };

  script = pkgs.writeShellApplication {
    name = "qui-reconcile";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.sqlite pkgs.coreutils];
    text = ''
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      desired=${desiredFile}

      # qui only accepts API keys it has stored, and with OIDC as the only
      # login there is no session to create one through. The key is generated
      # here once and its hash written straight into qui's table, which is
      # all qui checks a key against.
      until [ -s ${database} ] && curl -s -o /dev/null ${lib.escapeShellArg "${config.links.qui.url}/health"}; do
        sleep 2
      done
      if [ ! -s ${stateDir}/api.key ]; then
        od -An -tx1 -N32 /dev/urandom | tr -d ' \n' >${stateDir}/api.key
      fi
      hash=$(tr -d '\n' <${stateDir}/api.key | sha256sum | cut -d' ' -f1)
      sqlite3 ${database} <<EOF
      .timeout 30000
      INSERT OR IGNORE INTO string_pool (value) VALUES ('qui-reconcile');
      DELETE FROM api_keys
        WHERE name_id = (SELECT id FROM string_pool WHERE value = 'qui-reconcile')
          AND key_hash != '$hash';
      INSERT OR IGNORE INTO api_keys (key_hash, name_id)
        SELECT '$hash', id FROM string_pool WHERE value = 'qui-reconcile';
      EOF
      printf 'X-API-Key: %s\n' "$(cat ${stateDir}/api.key)" >"$tmp/auth"

      # Calls the qui API, leaving the body in $tmp/response. Fails on
      # anything but a 2xx, with the start of the response for context.
      call() {
        local method=$1 path=$2 body=''${3:-}
        local args=(-s -o "$tmp/response" -w '%{http_code}' -X "$method" -H @"$tmp/auth")
        if [ -n "$body" ]; then
          args+=(-H 'Content-Type: application/json' --data-binary @"$body")
        fi
        local code
        code=$(curl "''${args[@]}" ${lib.escapeShellArg api}"$path")
        if [[ $code != 2* ]]; then
          echo "qui: $method $path failed with HTTP $code: $(head -c 500 "$tmp/response")" >&2
          return 1
        fi
      }

      # Lists come back bare, wrapped, or as null when empty, depending on
      # the endpoint.
      list() {
        call GET "$1"
        jq 'if type == "array" then . elif type == "object" then ([.[] | arrays] | first // []) else [] end' \
          "$tmp/response" >"$tmp/list"
      }

      # Creates or updates the entry called $2 in the collection at $1, with
      # the request body in $3. Entries qui has that Nix doesn't name are left
      # alone, so anything added in the UI survives.
      upsert() {
        local path=$1 name=$2 body=$3 id
        list "$path"
        id=$(jq -r --arg name "$name" 'map(select(.name == $name)) | first | .id // empty' "$tmp/list")
        if [ -n "$id" ]; then
          call PUT "$path/$id" "$body"
        else
          call POST "$path" "$body"
        fi
        jq -r '.id // empty' "$tmp/response" >"$tmp/id"
        if [ ! -s "$tmp/id" ]; then
          echo "$id" >"$tmp/id"
        fi
      }

      # The qBittorrent instance: the one named, or the only one there is.
      call GET /instances
      jq --slurpfile d "$desired" '
        ($d[0].instanceName) as $name
        | if $name == null then (if length == 1 then .[0] else error("qui has several instances; set instanceName") end)
          else (map(select(.name == $name)) | first // error("qui has no instance named \($name)")) end
      ' "$tmp/response" >"$tmp/instance"
      instance=$(jq -r .id "$tmp/instance")
      if [ "$(jq '.instance | length' "$desired")" -gt 0 ]; then
        jq --slurpfile d "$desired" '{name, host, username} + $d[0].instance' "$tmp/instance" >"$tmp/body"
        call PUT "/instances/$instance" "$tmp/body"
      fi

      jq -r '.arrInstances | keys[]' "$desired" | while read -r name; do
        jq --arg name "$name" '.arrInstances[$name] as $a
          | {type: $a.type, name: $name, base_url: $a.url, apiKeyFile: $a.apiKeyFile, enabled: $a.enabled}' \
          "$desired" >"$tmp/arr"
        jq --rawfile key "$(jq -r .apiKeyFile "$tmp/arr")" \
          'del(.apiKeyFile) + {api_key: ($key | rtrimstr("\n"))}' "$tmp/arr" >"$tmp/body"
        upsert /arr/instances "$name" "$tmp/body"
      done

      # Indexers are named by Prowlarr's name for them; their Prowlarr IDs are
      # looked up here.
      printf 'X-Api-Key: %s\n' "$(cat "$(jq -r .prowlarr.apiKeyFile "$desired")")" >"$tmp/prowlarr-auth"
      curl -sf -H @"$tmp/prowlarr-auth" "$(jq -r .prowlarr.url "$desired")/api/v1/indexer" >"$tmp/prowlarr"
      : >"$tmp/indexer-ids"
      jq -r '.indexers | keys[]' "$desired" | while read -r name; do
        jq --arg name "$name" --slurpfile p "$tmp/prowlarr" --rawfile key "$(jq -r .prowlarr.apiKeyFile "$desired")" '
          .indexers[$name] as $i
          | ($p[0] | map(select(.name == $i.prowlarrName)) | first
              // error("Prowlarr has no indexer named \($i.prowlarrName)")) as $pi
          | {name: $name, backend: "prowlarr", base_url: .prowlarr.url,
             indexer_id: ($pi.id | tostring), api_key: ($key | rtrimstr("\n")), enabled: $i.enabled}
        ' "$desired" >"$tmp/body"
        upsert /torznab/indexers "$name" "$tmp/body"
        jq -n --arg name "$name" --arg id "$(cat "$tmp/id")" '{($name): ($id | tonumber)}' >>"$tmp/indexer-ids"
      done

      if jq -e '.crossSeed.settings != {} or .crossSeed.indexers != []' "$desired" >/dev/null; then
        jq --slurpfile d "$desired" --argjson instance "$instance" -s '
          add // {} | . as $ids
          | $d[0].crossSeed.settings
            + {targetInstanceIds: [$instance],
               targetIndexerIds: [$d[0].crossSeed.indexers[] | $ids[.] // error("cross-seed indexer \(.) is not in indexers")]}
        ' "$tmp/indexer-ids" >"$tmp/body"
        call PATCH /cross-seed/settings "$tmp/body"
      fi

      jq -r '.automations | keys[]' "$desired" | while read -r name; do
        jq --arg name "$name" '.automations[$name] + {name: $name}' "$desired" >"$tmp/body"
        upsert "/instances/$instance/automations" "$name" "$tmp/body"
      done

      echo "qui reconciled"
    '';
  };
in {
  options.rat.services.qui = {
    instanceName = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The qBittorrent instance in qui to configure; null picks the only one.";
    };

    instance = options.mkOption {
      inherit (json) type;
      default = {};
      example = {
        hasLocalFilesystemAccess = true;
        useReflinks = true;
      };
      description = "Instance settings, as qui's API names them, kept as given.";
    };

    arrInstances = options.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          type = options.mkOption {
            type = types.enum ["sonarr" "radarr"];
            description = "Which kind of instance this is.";
          };
          url = options.mkOption {
            type = types.str;
            description = "The instance's base URL.";
          };
          apiKeyFile = options.mkOption {
            type = types.path;
            description = "File holding the instance's API key.";
          };
          enabled = options.mkOption {
            type = types.bool;
            default = true;
            description = "Whether qui uses the instance.";
          };
        };
      });
      default = {};
      description = "Sonarr and Radarr instances qui looks up IDs and episode counts in, keyed by name.";
    };

    indexers = options.mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          prowlarrName = options.mkOption {
            type = types.str;
            default = name;
            description = "The indexer's name in Prowlarr.";
          };
          enabled = options.mkOption {
            type = types.bool;
            default = true;
            description = "Whether qui searches the indexer.";
          };
        };
      }));
      default = {};
      description = "Prowlarr indexers qui searches, keyed by the name qui shows.";
    };

    crossSeed = {
      settings = options.mkOption {
        inherit (json) type;
        default = {};
        description = ''
          Cross-seed settings, as qui's API names them. Only the settings
          given are changed; the rest keep whatever qui has.
        '';
      };
      indexers = options.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Names from `indexers` that cross-seed automation searches.";
      };
    };

    automations = options.mkOption {
      type = types.attrsOf json.type;
      default = {};
      description = ''
        Automation rules for the instance, keyed by rule name, each in qui's
        rule JSON without its name. Rules qui has that aren't named here are
        left alone.
      '';
    };
  };

  config = modules.mkIf cfg.enable {
    # Every enabled Sonarr and Radarr instance on the host.
    rat.services.qui.arrInstances = let
      arr = type: name: enable:
        modules.mkIf enable {
          ${name} = {
            inherit type;
            inherit (config.links.${name}) url;
            apiKeyFile = config.sops.secrets."${name}/apiKey".path;
          };
        };
      services = config.rat.services;
    in
      modules.mkMerge [
        (arr "sonarr" "sonarr" services.sonarr.enable)
        (arr "sonarr" "sonarr-anime" services.sonarr.anime.enable)
        (arr "radarr" "radarr" services.radarr.enable)
        (arr "radarr" "radarr-anime" services.radarr.anime.enable)
      ];

    systemd.services.qui-reconcile = {
      description = "Bring qui's configuration in line with Nix";
      after = ["qui.service" "prowlarr.service"];
      requires = ["qui.service"];
      wantedBy = ["multi-user.target"];
      partOf = ["qui.service"];
      serviceConfig = {
        Type = "exec";
        ExecStart = lib.getExe script;
        StateDirectory = "qui-reconcile";
        StateDirectoryMode = "0700";
        UMask = "0077";
        PrivateTmp = true;
      };
    };
  };
}
