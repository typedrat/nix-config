{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.nix-cache;

  storeUri = "s3://${cfg.bucket}?endpoint=${cfg.endpoint}&region=${cfg.region}&profile=${cfg.profile}";
  stateDir = "/var/lib/nix-cache";
  gcRootDir = "/nix/var/nix/gcroots/nix-cache-push";

  b2 = lib.getExe' pkgs.backblaze-b2 "backblaze-b2";

  # Each queue file is named <host>.<id> and lists store paths. Its closure is
  # copied whole: nix copy skips anything already in the bucket, and the root
  # marker recorded afterwards is what keeps the closure alive through GC.
  push = pkgs.writeShellApplication {
    name = "nix-cache-push";
    runtimeInputs = [config.nix.package pkgs.coreutils pkgs.gnugrep];
    text = ''
      shopt -s nullglob
      store='${storeUri}&compression=zstd&parallel-compression=true&secret-key=${config.sops.secrets."nix-cache/signingKey".path}'
      status=0
      mkdir -p ${gcRootDir}

      # Files can land while a pass runs; keep going until a pass finds nothing.
      while files=(${stateDir}/queue/*); ((''${#files[@]})); do
        progressed=0
        for f in "''${files[@]}"; do
          name=$(basename "$f")
          host=''${name%%.*}
          paths=()
          while read -r p; do
            [[ $p =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]] && nix-store --check-validity "$p" 2>/dev/null && paths+=("$p")
          done <"$f"

          if ((''${#paths[@]} == 0)); then
            echo "$name: no valid store paths, dropping" >&2
            rm -f "$f"
            progressed=1
            continue
          fi

          # Hold the paths against the host's own GC for the length of the copy.
          for i in "''${!paths[@]}"; do ln -sfn "''${paths[$i]}" "${gcRootDir}/$name-$i"; done
          marker=$(mktemp)
          printf '%s\n' "''${paths[@]}" >"$marker"
          if nix copy --to "$store" "''${paths[@]}" &&
            ${b2} file upload --quiet ${cfg.bucket} "$marker" "roots/$host/$(date +%s)" >/dev/null; then
            rm -f "$f"
            progressed=1
          else
            echo "$name: push failed, leaving it queued" >&2
            status=1
          fi
          rm -f "$marker" "${gcRootDir}/$name"-*
        done
        ((progressed)) || break
      done
      exit "$status"
    '';
  };

  gc = pkgs.writers.writePython3 "nix-cache-gc" {
    libraries = [pkgs.python3Packages.b2sdk];
    flakeIgnore = ["E501"];
  } (builtins.readFile ./gc.py);
in {
  options.rat.nix-cache = {
    enable =
      options.mkEnableOption "the private Nix binary cache as a substituter"
      // {
        default = true;
      };

    bucket = options.mkOption {
      type = types.str;
      default = "typedrat-nix-cache";
      description = "B2 bucket holding the cache.";
    };

    endpoint = options.mkOption {
      type = types.str;
      default = "s3.us-west-002.backblazeb2.com";
      description = "S3-compatible endpoint of the bucket.";
    };

    region = options.mkOption {
      type = types.str;
      default = "us-west-002";
      description = "Region of the bucket.";
    };

    profile = options.mkOption {
      type = types.str;
      default = "nix-cache";
      description = ''
        AWS profile named in the store URI. Environment credentials take
        precedence over it, so the daemon is unaffected; it is what lets
        user-side store access authenticate.
      '';
    };

    publicKey = options.mkOption {
      type = types.str;
      default = "cache.thisratis.gay-1:NimhoXtWFstpoy5x5u02qcqU4fM+pwFc/8/qfOEAmOk=";
      description = "Key the cache's paths are signed with.";
    };

    push = {
      enable = options.mkEnableOption "uploading queued system closures to the cache and collecting its garbage";

      queueGroup = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Group allowed to queue store paths for upload by writing a file named
          <host>.<id> to ${stateDir}/incoming and moving it into
          ${stateDir}/queue.
        '';
      };

      retentionDays = options.mkOption {
        type = types.ints.positive;
        default = 14;
        description = "How long a pushed system keeps its closure alive. The newest system of each host is always kept.";
      };

      graceDays = options.mkOption {
        type = types.ints.positive;
        default = 2;
        description = "Minimum age before GC deletes anything, so uploads in flight are never collected.";
      };
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      sops.secrets = {
        "nix-cache/reader/keyId".sopsFile = ../../../secrets/default.yaml;
        "nix-cache/reader/applicationKey".sopsFile = ../../../secrets/default.yaml;
      };

      sops.templates."nix-cache-reader.env".content = ''
        AWS_ACCESS_KEY_ID=${config.sops.placeholder."nix-cache/reader/keyId"}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."nix-cache/reader/applicationKey"}
      '';

      nix.settings = {
        extra-substituters = [storeUri];
        extra-trusted-public-keys = [cfg.publicKey];
      };

      # The daemon does the substituting. `-` keeps it starting on a first boot
      # where sops has not rendered the file yet; the cache is just skipped.
      systemd.services.nix-daemon.serviceConfig.EnvironmentFile = ["-${config.sops.templates."nix-cache-reader.env".path}"];
    })

    (modules.mkIf cfg.push.enable {
      sops.secrets = {
        "nix-cache/writer/keyId".sopsFile = ../../../secrets/default.yaml;
        "nix-cache/writer/applicationKey".sopsFile = ../../../secrets/default.yaml;
        "nix-cache/signingKey" = {
          sopsFile = ../../../secrets/hydra.yaml;
          key = "cacheKey/private";
        };
      };

      # B2 application keys work on both its native and S3 APIs, so one key
      # serves nix copy, the b2 CLI and b2sdk.
      sops.templates."nix-cache-writer.env".content = ''
        AWS_ACCESS_KEY_ID=${config.sops.placeholder."nix-cache/writer/keyId"}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."nix-cache/writer/applicationKey"}
        B2_APPLICATION_KEY_ID=${config.sops.placeholder."nix-cache/writer/keyId"}
        B2_APPLICATION_KEY=${config.sops.placeholder."nix-cache/writer/applicationKey"}
      '';

      systemd.tmpfiles.rules = let
        group =
          if cfg.push.queueGroup == null
          then "root"
          else cfg.push.queueGroup;
      in [
        "d ${stateDir} 0755 root root -"
        "d ${stateDir}/incoming 0770 root ${group} -"
        "d ${stateDir}/queue 0770 root ${group} -"
      ];

      systemd.services.nix-cache-push = {
        description = "Upload queued system closures to the Nix binary cache";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          # Not oneshot: a push can take hours, and a switch waits for every
          # oneshot it starts to finish.
          Type = "exec";
          ExecStart = lib.getExe push;
          EnvironmentFile = config.sops.templates."nix-cache-writer.env".path;
        };
      };

      # PathChanged also fires on renames into the directory, which is how
      # files are meant to arrive. The timer retries whatever a failed run left.
      systemd.paths.nix-cache-push = {
        wantedBy = ["paths.target"];
        pathConfig.PathChanged = "${stateDir}/queue";
      };
      systemd.timers.nix-cache-push = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
        };
      };

      systemd.services.nix-cache-gc = {
        description = "Collect garbage in the Nix binary cache";
        after = ["network-online.target" "nix-cache-push.service"];
        wants = ["network-online.target"];
        path = [config.nix.package];
        environment = {
          RETENTION_DAYS = toString cfg.push.retentionDays;
          GRACE_DAYS = toString cfg.push.graceDays;
        };
        serviceConfig = {
          Type = "exec";
          ExecStart = "${gc} ${cfg.bucket} ${lib.escapeShellArg storeUri}";
          EnvironmentFile = config.sops.templates."nix-cache-writer.env".path;
        };
      };
      systemd.timers.nix-cache-gc = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };
    })
  ];
}
