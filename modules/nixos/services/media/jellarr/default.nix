{
  config,
  inputs',
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.jellarr;
  impermanenceCfg = config.rat.impermanence;

  jellarrConfig =
    {
      version = 1;
      base_url = config.links.jellyfin.url;
      system = {
        enableMetrics = true;
        pluginRepositories =
          [
            {
              name = "Jellyfin Official";
              url = "https://repo.jellyfin.org/releases/plugin/manifest.json";
              enabled = true;
            }
          ]
          ++ cfg._jellarrPluginRepos;
        trickplayOptions = {
          enableHwAcceleration = true;
          enableHwEncoding = true;
        };
      };
    }
    // lib.optionalAttrs cfg.encoding.enable {
      encoding = {
        inherit (cfg.encoding) hardwareAccelerationType;
        inherit (cfg.encoding) hardwareDecodingCodecs;
        inherit (cfg.encoding) enableDecodingColorDepth10Hevc;
        inherit (cfg.encoding) enableDecodingColorDepth10HevcRext;
        inherit (cfg.encoding) enableDecodingColorDepth12HevcRext;
        inherit (cfg.encoding) enableDecodingColorDepth10Vp9;
        inherit (cfg.encoding) allowHevcEncoding;
        inherit (cfg.encoding) allowAv1Encoding;
        inherit (cfg.encoding) enableHardwareEncoding;
      };
    }
    // {
      library.virtualFolders =
        map (l: {
          inherit (l) name collectionType;
          libraryOptions.pathInfos = map (p: {path = p;}) l.paths;
        })
        cfg.libraries;
      branding =
        {inherit (cfg.branding) splashscreenEnabled;}
        // lib.optionalAttrs (cfg.branding.loginDisclaimer != null) {inherit (cfg.branding) loginDisclaimer;}
        // lib.optionalAttrs (cfg.branding.customCss != null) {inherit (cfg.branding) customCss;};
      startup = {inherit (cfg) completeStartupWizard;};
      plugins = cfg._jellarrPlugins;
    };
in {
  imports = [
    ./ldap.nix
    ./sso.nix
    ./shokofin.nix
  ];

  options.rat.services.jellarr = {
    enable = options.mkEnableOption "Jellarr";

    subdomain = options.mkOption {
      type = types.str;
      default = "jellyfin";
      description = "The subdomain for Jellarr.";
    };

    completeStartupWizard = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to mark the Jellyfin startup wizard as complete.";
    };

    encoding = {
      enable = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to configure Jellyfin encoding settings.";
      };

      hardwareAccelerationType = options.mkOption {
        type = types.enum ["none" "amf" "qsv" "nvenc" "v4l2m2m" "vaapi" "videotoolbox" "rkmpp"];
        default = "nvenc";
        description = "Hardware acceleration type for transcoding.";
      };

      hardwareDecodingCodecs = options.mkOption {
        type = types.listOf types.str;
        default = ["h264" "hevc" "mpeg2video" "vc1" "vp8" "vp9"];
        description = "List of codecs to hardware decode.";
      };

      enableDecodingColorDepth10Hevc = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit HEVC hardware decoding.";
      };

      enableDecodingColorDepth10HevcRext = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit HEVC Rext hardware decoding.";
      };

      enableDecodingColorDepth12HevcRext = options.mkOption {
        type = types.bool;
        default = false;
        description = "Enable 12-bit HEVC Rext hardware decoding.";
      };

      enableDecodingColorDepth10Vp9 = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit VP9 hardware decoding.";
      };

      allowHevcEncoding = options.mkOption {
        type = types.bool;
        default = true;
        description = "Allow HEVC hardware encoding.";
      };

      allowAv1Encoding = options.mkOption {
        type = types.bool;
        default = false;
        description = "Allow AV1 hardware encoding.";
      };

      enableHardwareEncoding = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable hardware encoding.";
      };
    };

    libraries = options.mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = options.mkOption {
            type = types.str;
            description = "Name of the library.";
          };
          collectionType = options.mkOption {
            type = types.enum ["movies" "tvshows" "music" "homevideos" "musicvideos" "boxsets" "books" "mixed"];
            description = "Type of media collection.";
          };
          paths = options.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Filesystem paths for this library.";
          };
        };
      });
      default = [];
      description = "Media library definitions.";
    };

    branding = {
      loginDisclaimer = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional login page disclaimer text.";
      };

      customCss = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional custom CSS for the Jellyfin web UI.";
      };

      splashscreenEnabled = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the Jellyfin splash screen.";
      };
    };

    _jellarrPlugins = options.mkOption {
      type = types.listOf (pkgs.formats.json {}).type;
      default = [];
      internal = true;
      description = "Internal: plugin definitions assembled by sub-modules.";
    };

    _jellarrPluginRepos = options.mkOption {
      type = types.listOf (pkgs.formats.json {}).type;
      default = [];
      internal = true;
      description = "Internal: plugin repository definitions assembled by sub-modules.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      sops.secrets."jellarr/apiKey" = {
        sopsFile = ../../../../../secrets/jellyfin.yaml;
        key = "jellarr/apiKey";
        owner = "jellarr";
        group = "jellyfin";
        mode = "0440";
      };

      sops.templates."jellarr.yml" = {
        content = builtins.toJSON jellarrConfig;
        owner = "jellarr";
        group = "jellarr";
        mode = "0400";
      };

      sops.templates."jellarr.env" = {
        content = "JELLARR_API_KEY=${config.sops.placeholder."jellarr/apiKey"}";
        owner = "jellarr";
        group = "jellarr";
        mode = "0400";
      };

      users.users.jellarr = {
        isSystemUser = true;
        group = "jellarr";
        home = "/var/lib/jellarr";
        createHome = true;
      };

      users.groups.jellarr = {};

      systemd.tmpfiles.rules = [
        "d /var/lib/jellarr 0750 jellarr jellarr -"
        "d /var/lib/jellarr/config 0750 jellarr jellarr -"
      ];

      systemd.services.jellarr-bootstrap = {
        description = "Jellarr bootstrap: inject API key into Jellyfin DB";
        after = ["jellyfin.service"];
        path = [pkgs.sqlite];
        serviceConfig = {
          Type = "oneshot";
          User = config.services.jellyfin.user;
          Group = config.services.jellyfin.group;
          RemainAfterExit = true;
        };
        script = let
          db = "${config.services.jellyfin.dataDir}/data/jellyfin.db";
          apiKeyFile = config.sops.secrets."jellarr/apiKey".path;
        in ''
          API_KEY=$(cat ${apiKeyFile})
          if ! echo "$API_KEY" | grep -qE '^[0-9a-fA-F]+$'; then
            echo "ERROR: API key contains unexpected characters" >&2
            exit 1
          fi
          EXISTING=$(sqlite3 ${db} "SELECT COUNT(*) FROM ApiKeys WHERE AccessToken = '$API_KEY';")
          if [ "$EXISTING" = "0" ]; then
            sqlite3 ${db} "INSERT INTO ApiKeys (DateCreated, DateLastActivity, Name, AccessToken) VALUES (datetime('now'), datetime('now'), 'Jellarr', '$API_KEY');"
            echo "Jellarr API key inserted into Jellyfin DB."
          else
            echo "Jellarr API key already exists in Jellyfin DB."
          fi
        '';
      };

      systemd.services.jellarr = {
        description = "Jellarr: declarative Jellyfin configuration";
        after = ["jellyfin.service" "jellarr-bootstrap.service" "network-online.target"];
        wants = ["jellyfin.service" "jellarr-bootstrap.service"];
        requires = ["network-online.target"];
        path = [pkgs.curl];
        serviceConfig = {
          Type = "oneshot";
          User = "jellarr";
          Group = "jellarr";
          WorkingDirectory = "/var/lib/jellarr";
          EnvironmentFile = config.sops.templates."jellarr.env".path;
        };
        preStart = ''
          for i in $(seq 1 120); do
            if curl -sf "${config.links.jellyfin.url}/health" > /dev/null 2>&1; then
              break
            fi
            if [ "$i" = "120" ]; then
              echo "Jellyfin did not become healthy within 120 seconds"
              exit 1
            fi
            sleep 1
          done
          install -m 0400 ${config.sops.templates."jellarr.yml".path} /var/lib/jellarr/config/config.yml
        '';
        script = ''
          exec ${inputs'.jellarr.packages.default}/bin/jellarr
        '';
      };

      systemd.timers.jellarr = {
        description = "Run Jellarr daily";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "5m";
          Persistent = true;
          Unit = "jellarr.service";
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/jellarr";
          user = "jellarr";
          group = "jellarr";
        }
      ];
    })
  ];
}
