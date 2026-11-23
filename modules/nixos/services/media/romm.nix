{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.romm;
  impermanenceCfg = config.rat.impermanence;

  rommUnits = [
    "romm.service"
    "romm-worker.service"
    "romm-scheduler.service"
    "romm-watcher.service"
  ];

  libraryDir = "${cfg.dataDir}/library";
  separateStorage = cfg.storageDir != libraryDir;
in {
  options.rat.services.romm = {
    enable = options.mkEnableOption "RomM";
    subdomain = options.mkOption {
      type = types.str;
      default = "romm";
      description = "The subdomain for RomM.";
    };
    dataDir = options.mkOption {
      type = types.str;
      default = "/var/lib/romm";
      description = "The data directory for RomM.";
    };

    storageDir = options.mkOption {
      type = types.str;
      default = libraryDir;
      defaultText = lib.literalExpression ''"''${config.rat.services.romm.dataDir}/library"'';
      description = ''
        The RomM library root, also holding the igir-related directories.
        RomM only reads its library from `''${dataDir}/library`, so any other
        location (e.g. on a ZFS array) is bind-mounted there.
      '';
    };

    metadataProviders = {
      igdb = {
        enable = options.mkEnableOption "IGDB metadata provider";
      };
      screenscraper = {
        enable = options.mkEnableOption "ScreenScraper metadata provider";
      };
      mobygames = {
        enable = options.mkEnableOption "MobyGames metadata provider";
      };
      steamgriddb = {
        enable = options.mkEnableOption "SteamGridDB metadata provider";
      };
      retroachievements = {
        enable = options.mkEnableOption "RetroAchievements metadata provider";
      };
      launchbox = {
        enable = options.mkEnableOption "LaunchBox metadata provider";
      };
      playmatch = {
        enable = options.mkEnableOption "PlayMatch metadata provider";
      };
      hasheous = {
        enable = options.mkEnableOption "Hasheous metadata provider";
      };
      flashpoint = {
        enable = options.mkEnableOption "Flashpoint metadata provider";
      };
      hltb = {
        enable = options.mkEnableOption "How Long To Beat metadata provider";
      };
    };

    igir = {
      enable = options.mkEnableOption "Igir ROM collection manager script";

      datsDir = options.mkOption {
        type = types.str;
        default = "${cfg.storageDir}/dats";
        defaultText = lib.literalExpression ''"''${config.rat.services.romm.storageDir}/dats"'';
        description = "Directory containing DAT files from no-intro.org and redump.org";
      };

      inputDir = options.mkOption {
        type = types.str;
        default = "${cfg.storageDir}/roms-unverified";
        defaultText = lib.literalExpression ''"''${config.rat.services.romm.storageDir}/roms-unverified"'';
        description = "Input directory for unverified ROMs";
      };

      outputDir = options.mkOption {
        type = types.str;
        default = "${cfg.storageDir}/library";
        defaultText = lib.literalExpression ''"''${config.rat.services.romm.storageDir}/library"'';
        readOnly = true;
        description = "Output directory for verified ROMs (RomM library path)";
      };

      patchesDir = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional directory containing ROM patches";
      };
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        igir
        skyscraper
      ];

      users.users.romm.extraGroups = ["media"];

      services.romm = {
        enable = true;
        inherit (cfg) dataDir;
        port = config.links.romm-api.port;

        database = {
          createLocally = false;
          host = "localhost";
          port = config.links.postgres.port;
        };

        redis.port = config.links.romm-redis.port;

        nginx.virtualHost = "${cfg.subdomain}.${config.rat.services.domainName}";

        environmentFile = config.sops.templates."romm.env".path;

        extraEnvironment = {
          # nginx only sees plain HTTP from Traefik, so the module would derive
          # an http:// base URL and leave session cookies insecure.
          ROMM_BASE_URL = "https://${cfg.subdomain}.${config.rat.services.domainName}";
          ROMM_SESSION_SECURE_COOKIE = "true";
          TZ = "UTC";
          LOGLEVEL = "INFO";
        };
      };

      # The module only orders itself after PostgreSQL when it creates the
      # database itself.
      systemd.services.romm = {
        after = ["postgresql.target"];
        requires = ["postgresql.target"];
      };

      services.nginx.virtualHosts.${config.services.romm.nginx.virtualHost}.listen = [
        {
          addr = config.links.romm.ipv4;
          inherit (config.links.romm) port;
        }
      ];

      links.romm = {
        protocol = "http";
      };

      links.romm-api = {
        protocol = "http";
      };

      links.romm-redis = {
        protocol = "redis";
      };

      rat.services.postgres = {
        enable = true;

        users = {
          romm = {
            passwordFile = config.sops.secrets."romm/db/password".path;
            ownedDatabases = ["romm"];
          };
        };
      };

      sops.secrets."romm/db/password" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "db/password";
        restartUnits = ["postgresql.service"] ++ rommUnits;
        owner = "postgres";
      };

      sops.secrets."romm/auth/secret_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "auth/secret_key";
        restartUnits = rommUnits;
      };

      sops.secrets."romm/oidc/client_id" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "oidc/client_id";
        restartUnits = rommUnits;
      };

      sops.secrets."romm/oidc/client_secret" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "oidc/client_secret";
        restartUnits = rommUnits;
      };

      sops.templates."romm.env" = {
        content = ''
          DB_PASSWD=${config.sops.placeholder."romm/db/password"}

          # Authentication
          ROMM_AUTH_SECRET_KEY=${config.sops.placeholder."romm/auth/secret_key"}

          # OIDC Configuration
          OIDC_ENABLED=true
          OIDC_PROVIDER=authentik
          OIDC_CLIENT_ID=${config.sops.placeholder."romm/oidc/client_id"}
          OIDC_CLIENT_SECRET=${config.sops.placeholder."romm/oidc/client_secret"}
          OIDC_REDIRECT_URI=https://${cfg.subdomain}.${config.rat.services.domainName}/api/oauth/openid
          OIDC_SERVER_APPLICATION_URL=https://${config.rat.services.authentik.subdomain}.${config.rat.services.domainName}/application/o/romm/
          DISABLE_USERPASS_LOGIN=false

          # Metadata Providers
          ${lib.optionalString cfg.metadataProviders.igdb.enable ''
            IGDB_CLIENT_ID=${config.sops.placeholder."romm/igdb/client_id"}
            IGDB_CLIENT_SECRET=${config.sops.placeholder."romm/igdb/client_secret"}
          ''}
          ${lib.optionalString cfg.metadataProviders.screenscraper.enable ''
            SCREENSCRAPER_USER=${config.sops.placeholder."romm/screenscraper/username"}
            SCREENSCRAPER_PASSWORD=${config.sops.placeholder."romm/screenscraper/password"}
            SCREENSCRAPER_DEV_ID=${config.sops.placeholder."romm/screenscraper/dev_id"}
            SCREENSCRAPER_DEV_PASSWORD=${config.sops.placeholder."romm/screenscraper/dev_password"}
          ''}
          ${lib.optionalString cfg.metadataProviders.mobygames.enable ''
            MOBYGAMES_API_KEY=${config.sops.placeholder."romm/mobygames/api_key"}
          ''}
          ${lib.optionalString cfg.metadataProviders.steamgriddb.enable ''
            STEAMGRIDDB_API_KEY=${config.sops.placeholder."romm/steamgriddb/api_key"}
          ''}
          ${lib.optionalString cfg.metadataProviders.retroachievements.enable ''
            RETROACHIEVEMENTS_API_KEY=${config.sops.placeholder."romm/retroachievements/api_key"}
          ''}
          ${lib.optionalString cfg.metadataProviders.launchbox.enable ''
            LAUNCHBOX_API_ENABLED=true
            # LaunchBox matches against a local copy of its metadata dump,
            # which only this task downloads; without it the provider is empty.
            ENABLE_SCHEDULED_UPDATE_LAUNCHBOX_METADATA=true
          ''}
          ${lib.optionalString cfg.metadataProviders.playmatch.enable ''
            PLAYMATCH_API_ENABLED=true
          ''}
          ${lib.optionalString cfg.metadataProviders.hasheous.enable ''
            HASHEOUS_API_ENABLED=true
          ''}
          ${lib.optionalString cfg.metadataProviders.flashpoint.enable ''
            FLASHPOINT_API_ENABLED=true
          ''}
          ${lib.optionalString cfg.metadataProviders.hltb.enable ''
            HLTB_API_ENABLED=true
          ''}
        '';

        restartUnits = rommUnits;
      };

      rat.services.traefik.routes.romm = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.romm.url;
      };
    })
    # Metadata provider secrets - IGDB
    (modules.mkIf (cfg.enable && cfg.metadataProviders.igdb.enable) {
      sops.secrets."romm/igdb/client_id" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "igdb/client_id";
        restartUnits = rommUnits;
      };
      sops.secrets."romm/igdb/client_secret" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "igdb/client_secret";
        restartUnits = rommUnits;
      };
    })

    # Metadata provider secrets - ScreenScraper
    (modules.mkIf (cfg.enable && cfg.metadataProviders.screenscraper.enable) {
      sops.secrets."romm/screenscraper/username" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "screenscraper/username";
        restartUnits = rommUnits;
      };
      sops.secrets."romm/screenscraper/password" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "screenscraper/password";
        restartUnits = rommUnits;
      };
      # RomM's own developer credentials, which upstream bakes into its
      # container image at build time; ScreenScraper rejects requests without them.
      sops.secrets."romm/screenscraper/dev_id" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "screenscraper/dev_id";
        restartUnits = rommUnits;
      };
      sops.secrets."romm/screenscraper/dev_password" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "screenscraper/dev_password";
        restartUnits = rommUnits;
      };
    })

    # Metadata provider secrets - MobyGames
    (modules.mkIf (cfg.enable && cfg.metadataProviders.mobygames.enable) {
      sops.secrets."romm/mobygames/api_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "mobygames/api_key";
        restartUnits = rommUnits;
      };
    })

    # Metadata provider secrets - SteamGridDB
    (modules.mkIf (cfg.enable && cfg.metadataProviders.steamgriddb.enable) {
      sops.secrets."romm/steamgriddb/api_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "steamgriddb/api_key";
        restartUnits = rommUnits;
      };
    })

    # Metadata provider secrets - RetroAchievements
    (modules.mkIf (cfg.enable && cfg.metadataProviders.retroachievements.enable) {
      sops.secrets."romm/retroachievements/api_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "retroachievements/api_key";
        restartUnits = rommUnits;
      };
    })

    (modules.mkIf (cfg.enable && separateStorage) {
      fileSystems.${libraryDir} = {
        device = cfg.storageDir;
        fsType = "none";
        options =
          ["bind"]
          # Datasets with a non-legacy mountpoint have no mount unit to order
          # against, so a bind made before zfs-mount would cover an empty dir.
          ++ lib.optional config.boot.zfs.enabled "x-systemd.after=zfs-mount.service";
      };

      # The module would chown the mountpoint to romm:romm 0750, which lands on
      # the shared storage root once the bind is in place.
      systemd.tmpfiles.settings."10-romm".${libraryDir} = lib.mkForce {};
    })

    # The module's romm-worker only listens on high/default/low. RomM sends
    # library scans to a "scans" queue and streaming teardowns to "streaming",
    # each meant for a worker of its own, and refuses to queue a scan while no
    # worker listens on "scans".
    (modules.mkIf cfg.enable (let
      worker = config.systemd.services.romm-worker;
      mkWorker = workerClass: queue: let
        exe = pkgs.runCommand "romm-${queue}-worker" {} ''
          substitute ${config.services.romm.package}/bin/romm-worker $out \
            --replace-fail "RomMWorker high default low" "${workerClass} ${queue}"
          chmod +x $out
        '';
      in {
        description = "RomM RQ worker (${queue})";
        wantedBy = ["multi-user.target"];
        inherit (worker) after requires environment;
        serviceConfig = worker.serviceConfig // {ExecStart = "${exe}";};
      };
    in {
      systemd.services.romm-scan-worker = mkWorker "RomMWorker" "scans";
      systemd.services.romm-streaming-worker = mkWorker "PreloadingWorker" "streaming";
    }))

    # Impermanence support
    # Note: storageDir is assumed to be on a persistent mount if set separately from dataDir
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = cfg.dataDir;
          user = "romm";
          group = "romm";
          mode = "0750";
        }
      ];
    })

    # Igir ROM collection manager
    (modules.mkIf (cfg.enable && cfg.igir.enable) (let
      igirScript = pkgs.writeShellApplication {
        name = "romm-igir-sync";
        runtimeInputs = with pkgs; [igir];
        text = ''
          set -euo pipefail

          # Configuration
          DATS_DIR="${cfg.igir.datsDir}"
          INPUT_DIR="${cfg.igir.inputDir}"
          OUTPUT_DIR="${cfg.igir.outputDir}"
          ${lib.optionalString (cfg.igir.patchesDir != null) ''PATCHES_DIR="${cfg.igir.patchesDir}"''}

          # Verify directories exist
          if [ ! -d "$DATS_DIR" ]; then
            echo "Error: DATs directory does not exist: $DATS_DIR"
            echo "Please download DAT files from:"
            echo "  - No-Intro: https://datomatic.no-intro.org/index.php?page=download&op=daily"
            echo "  - Redump: http://redump.org/downloads/"
            exit 1
          fi

          if [ ! -d "$INPUT_DIR" ]; then
            echo "Error: Input directory does not exist: $INPUT_DIR"
            echo "Please create it and add your unverified ROMs."
            exit 1
          fi

          # Parse command line arguments
          MODE="''${1:-sync}"
          shift || true

          case "$MODE" in
            sync)
              echo "=== RomM Igir ROM Sync ==="
              echo "Syncing ROMs from $INPUT_DIR to $OUTPUT_DIR"
              echo ""

              # Collect additional inputs from arguments
              INPUTS=()
              for INPUT in "$@"; do
                if [ -d "$INPUT" ]; then
                  INPUTS+=(--input "$INPUT")
                else
                  echo "Warning: Skipping non-existent input directory: $INPUT"
                fi
              done

              # Cartridge-based consoles (No-Intro)
              echo ">>> Processing cartridge-based consoles (No-Intro)..."
              if compgen -G "$DATS_DIR/No-Intro*.zip" > /dev/null || compgen -G "$DATS_DIR/No-Intro*.dat" > /dev/null; then
                igir move zip extract test clean report \
                  --dat "$DATS_DIR/No-Intro*.zip" \
                  --dat "$DATS_DIR/No-Intro*.dat" \
                  --dat-name-regex-exclude "/encrypted|source code/i" \
                  --input "$INPUT_DIR/" \
                  "''${INPUTS[@]}" \
                  --input-checksum-max CRC32 \
                  --input-checksum-archives never \
                  ${lib.optionalString (cfg.igir.patchesDir != null) ''--patch "$PATCHES_DIR/" \''} \
                  --output "$OUTPUT_DIR/{romm}/" \
                  --overwrite-invalid \
                  --zip-exclude "*.{chd,iso}" \
                  --reader-threads 4 \
                  -v
                echo "✓ No-Intro processing complete"
              else
                echo "! No No-Intro DAT files found in $DATS_DIR, skipping..."
              fi
              echo ""

              # Disc-based consoles (Redump)
              echo ">>> Processing disc-based consoles (Redump)..."
              if compgen -G "$DATS_DIR/Redump/*.zip" > /dev/null || compgen -G "$DATS_DIR/Redump/*.dat" > /dev/null; then
                igir move test clean report \
                  --dat "$DATS_DIR/Redump/*.zip" \
                  --dat "$DATS_DIR/Redump/*.dat" \
                  --input "$INPUT_DIR/" \
                  "''${INPUTS[@]}" \
                  --input-checksum-max CRC32 \
                  --input-checksum-archives never \
                  ${lib.optionalString (cfg.igir.patchesDir != null) ''--patch "$PATCHES_DIR/" \''} \
                  --output "$OUTPUT_DIR/{romm}/" \
                  --overwrite-invalid \
                  --single \
                  --prefer-language EN \
                  --prefer-region USA,WORLD,EUR,JPN \
                  --prefer-revision newer \
                  -v
                echo "✓ Redump processing complete"
              else
                echo "! No Redump DAT files found in $DATS_DIR/Redump/, skipping..."
              fi
              echo ""

              # MAME
              echo ">>> Processing MAME..."
              if compgen -G "$DATS_DIR/mame*.xml" > /dev/null || compgen -G "$DATS_DIR/MAME*.zip" > /dev/null; then
                igir move zip test clean \
                  --dat "$DATS_DIR/mame*.xml" \
                  --input "$INPUT_DIR/" \
                  "''${INPUTS[@]}" \
                  --input-checksum-quick \
                  --input-checksum-archives never \
                  --output "$OUTPUT_DIR/{romm}/" \
                  --overwrite-invalid \
                  --merge-roms merged \
                  -v
                echo "✓ MAME processing complete"
              else
                echo "! No MAME DAT files found in $DATS_DIR, skipping..."
              fi
              echo ""

              echo "=== Sync complete! ==="
              ;;

            mirror)
              echo "=== Mirroring unverified ROMs ==="
              echo "Moving remaining ROMs from $INPUT_DIR to $OUTPUT_DIR"
              echo "This will preserve the directory structure."
              echo ""
              igir move \
                -i "$INPUT_DIR/" \
                -o "$OUTPUT_DIR/" \
                --dir-mirror
              echo "✓ Mirror complete"
              ;;

            fix-multidisc)
              echo "=== Reorganizing multi-disc games ==="
              echo "This will combine (Disc N) directories into single game folders."
              echo ""

              PLATFORM="''${1:-.}"
              cd "$OUTPUT_DIR/$PLATFORM" || exit 1

              shopt -s nullglob
              for dir in *Disc*/; do
                # Remove trailing slash
                dir="''${dir%/}"
                game=$(echo "$dir" | sed -r 's/ \(Disc [0-9]+\)//')
                echo "Merging: $dir -> $game"
                mkdir -p "$game"
                mv "$dir"/* "$game/"
                rmdir "$dir"
              done
              shopt -u nullglob

              echo "✓ Multi-disc reorganization complete"
              ;;

            help|--help|-h)
              cat << 'EOF'
          RomM Igir ROM Collection Manager

          Usage: romm-igir-sync [MODE] [OPTIONS...]

          Modes:
            sync [INPUT_DIRS...]     Sync ROMs using DAT files (default)
                                     Optional: Specify additional input directories
            mirror                   Mirror remaining unverified ROMs preserving structure
            fix-multidisc [PLATFORM] Reorganize multi-disc games into single folders
                                     PLATFORM: Subdirectory in output dir (default: current dir)
            help                     Show this help message

          Environment:
            DATS_DIR:    ${cfg.igir.datsDir}
            INPUT_DIR:   ${cfg.igir.inputDir}
            OUTPUT_DIR:  ${cfg.igir.outputDir}
            ${lib.optionalString (cfg.igir.patchesDir != null) "PATCHES_DIR: ${cfg.igir.patchesDir}"}

          Examples:
            # Sync ROMs from the default input directory
            romm-igir-sync

            # Sync ROMs with additional input directories
            romm-igir-sync sync /mnt/usb/roms /mnt/backup/roms

            # Mirror remaining unverified ROMs
            romm-igir-sync mirror

            # Fix multi-disc games in PlayStation directory
            romm-igir-sync fix-multidisc ps

          For more information, see: https://igir.io/
          EOF
              ;;

            *)
              echo "Error: Unknown mode '$MODE'"
              echo "Run 'romm-igir-sync help' for usage information."
              exit 1
              ;;
          esac
        '';
      };
    in {
      environment.systemPackages = [igirScript];

      systemd.tmpfiles.rules =
        [
          "d ${cfg.igir.outputDir} 0775 romm media -"
          "d ${cfg.igir.datsDir} 0775 romm media -"
          "d ${cfg.igir.inputDir} 0775 romm media -"
        ]
        ++ lib.optional (cfg.igir.patchesDir != null) "d ${cfg.igir.patchesDir} 0775 romm media -";
    }))
  ];
}
