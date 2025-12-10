{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.romm;
  impermanenceCfg = config.rat.impermanence;
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
      default = cfg.dataDir;
      defaultText = lib.literalExpression "config.rat.services.romm.dataDir";
      description = ''
        The storage directory for ROM library and igir-related directories.
        This can be set to a separate location (e.g., on a ZFS array) from the main data directory.
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

      users.users.romm = {
        isSystemUser = true;
        group = "romm";
        description = "RomM service user";

        extraGroups = ["media" "podman"];
        home = cfg.dataDir;
        linger = false;
      };

      users.groups.romm = {};

      virtualisation.oci-containers.backend = "docker";
      virtualisation.oci-containers.containers.romm = {
        image = "rommapp/romm:latest";
        volumes = [
          "${cfg.dataDir}/resources:/romm/resources"
          "${cfg.storageDir}:/romm/library"
          "${cfg.dataDir}/assets:/romm/assets"
          "${cfg.dataDir}/config:/romm/config"
        ];
        environmentFiles = [
          config.sops.templates."romm.env".path
        ];
        extraOptions = ["--network=host"];
      };

      systemd.services.docker-romm = {
        after = ["postgresql.service" "redis-romm.service"];
        requires = ["postgresql.service" "redis-romm.service"];
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0775 romm romm -"
        "d ${cfg.dataDir}/resources 0775 romm romm -"
        "d ${cfg.storageDir}/library 0775 romm media -"
        "d ${cfg.dataDir}/assets 0775 romm romm -"
        "d ${cfg.dataDir}/config 0775 romm romm -"
      ];

      links.romm = {
        protocol = "http";
      };

      links.romm-redis = {
        protocol = "redis";
      };

      services.redis.servers.romm = {
        enable = true;
        port = lib.mkForce config.links.romm-redis.port;
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
        restartUnits = ["postgresql.service" "docker-romm.service"];
        owner = "postgres";
      };

      sops.secrets."romm/auth/secret_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "auth/secret_key";
        restartUnits = ["docker-romm.service"];
      };

      sops.secrets."romm/oidc/client_id" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "oidc/client_id";
        restartUnits = ["docker-romm.service"];
      };

      sops.secrets."romm/oidc/client_secret" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "oidc/client_secret";
        restartUnits = ["docker-romm.service"];
      };

      sops.templates."romm.env" = {
        content = ''
          # Database Configuration
          DB_HOST=localhost
          DB_PORT=${toString config.links.postgres.port}
          DB_NAME=romm
          DB_USER=romm
          DB_PASSWD=${config.sops.placeholder."romm/db/password"}
          ROMM_DB_DRIVER=postgresql

          # Redis Configuration
          REDIS_HOST=localhost
          REDIS_PORT=${toString config.links.romm-redis.port}

          # RomM Configuration
          ROMM_PORT=${toString config.links.romm.port}

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

          # Application Configuration
          ROMM_BASE_PATH=/romm
          TZ=UTC
          LOGLEVEL=INFO
        '';

        restartUnits = ["docker-romm.service"];
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
        restartUnits = ["docker-romm.service"];
      };
      sops.secrets."romm/igdb/client_secret" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "igdb/client_secret";
        restartUnits = ["docker-romm.service"];
      };
    })

    # Metadata provider secrets - ScreenScraper
    (modules.mkIf (cfg.enable && cfg.metadataProviders.screenscraper.enable) {
      sops.secrets."romm/screenscraper/username" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "screenscraper/username";
        restartUnits = ["docker-romm.service"];
      };
      sops.secrets."romm/screenscraper/password" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "screenscraper/password";
        restartUnits = ["docker-romm.service"];
      };
    })

    # Metadata provider secrets - MobyGames
    (modules.mkIf (cfg.enable && cfg.metadataProviders.mobygames.enable) {
      sops.secrets."romm/mobygames/api_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "mobygames/api_key";
        restartUnits = ["docker-romm.service"];
      };
    })

    # Metadata provider secrets - SteamGridDB
    (modules.mkIf (cfg.enable && cfg.metadataProviders.steamgriddb.enable) {
      sops.secrets."romm/steamgriddb/api_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "steamgriddb/api_key";
        restartUnits = ["docker-romm.service"];
      };
    })

    # Metadata provider secrets - RetroAchievements
    (modules.mkIf (cfg.enable && cfg.metadataProviders.retroachievements.enable) {
      sops.secrets."romm/retroachievements/api_key" = {
        sopsFile = ../../../../secrets/romm.yaml;
        key = "retroachievements/api_key";
        restartUnits = ["docker-romm.service"];
      };
    })

    # Impermanence support
    # Note: storageDir is assumed to be on a persistent mount if set separately from dataDir
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = cfg.dataDir;
          user = "romm";
          group = "romm";
          mode = "0775";
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
          "d ${cfg.igir.datsDir} 0775 romm media -"
          "d ${cfg.igir.inputDir} 0775 romm media -"
        ]
        ++ lib.optional (cfg.igir.patchesDir != null) "d ${cfg.igir.patchesDir} 0775 romm media -";
    }))
  ];
}
