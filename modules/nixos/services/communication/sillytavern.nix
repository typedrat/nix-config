{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.sillytavern;
  impermanenceCfg = config.rat.impermanence;

  sillytavernExtensions = pkgs.linkFarm "sillytavern-extensions" (
    lib.mapAttrsToList (name: path: {inherit name path;}) cfg.systemExtensions
  );

  configFile = pkgs.writeText "sillytavern-config.yaml" (lib.generators.toYAML {} {
    listen = true;
    inherit (cfg) port;
    protocol = {
      ipv4 = true;
      ipv6 = false;
    };
    autorun = false;
    autorunHostname = "auto";
    inherit (cfg) allowKeysExposure;
    inherit (cfg) skipContentCheck;
    inherit (cfg) enableDownloadableTokenizers;
    logging = {
      inherit (cfg.logging) enableAccessLog;
      inherit (cfg.logging) minLogLevel;
    };
    thumbnails = {
      inherit (cfg.thumbnails) enabled;
      inherit (cfg.thumbnails) quality;
      inherit (cfg.thumbnails) format;
      dimensions = lib.mapAttrs (_name: dim: [dim.width dim.height]) cfg.thumbnails.dimensions;
    };
    backups = {
      chat = {
        inherit (cfg.backups) enabled;
        inherit (cfg.backups) checkIntegrity;
      };
      common = {
        inherit (cfg.backups) numberOfBackups;
      };
    };
    extensions = {
      inherit (cfg.extensions) enabled;
      inherit (cfg.extensions) autoUpdate;
      models = {
        inherit (cfg.extensions.models) autoDownload;
        inherit (cfg.extensions.models) classification;
        inherit (cfg.extensions.models) captioning;
        inherit (cfg.extensions.models) embedding;
        inherit (cfg.extensions.models) speechToText;
        inherit (cfg.extensions.models) textToSpeech;
      };
    };
    inherit (cfg) enableServerPlugins;
    inherit (cfg) enableServerPluginsAutoUpdate;
    # Configure for Authentik SSO
    autheliaAuth = true;
    basicAuthMode = false;
    securityOverride = true;
    enableUserAccounts = cfg.multiUser.enable;
    inherit (cfg.multiUser) enableDiscreetLogin;
    whitelistMode = false;
    whitelist = ["127.0.0.1" "::1"];
    enableForwardedWhitelist = true;
    whitelistDockerHosts = false;
    sessionTimeout = -1;
    # Rate limiting configuration for authenticated users
    rateLimiting = {
      preferRealIpHeader = true;
    };
  });
in {
  options.rat.services.sillytavern = {
    enable = options.mkEnableOption "SillyTavern";

    subdomain = options.mkOption {
      type = types.str;
      default = "sillytavern";
      description = "The subdomain for SillyTavern.";
    };

    port = options.mkOption {
      type = types.port;
      default = 8000;
      description = "Port for SillyTavern to listen on.";
    };

    allowKeysExposure = options.mkOption {
      type = types.bool;
      default = false;
      description = "Allow API keys exposure via API.";
    };

    skipContentCheck = options.mkOption {
      type = types.bool;
      default = false;
      description = "Skip new default content checks.";
    };

    enableDownloadableTokenizers = options.mkOption {
      type = types.bool;
      default = true;
      description = "Enable on-demand tokenizer downloads.";
    };

    enableServerPlugins = options.mkOption {
      type = types.bool;
      default = false;
      description = "Enable server-side plugins.";
    };

    enableServerPluginsAutoUpdate = options.mkOption {
      type = types.bool;
      default = true;
      description = "Attempt to automatically update server plugins on startup.";
    };

    multiUser = {
      enable = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable multi-user mode.";
      };

      enableDiscreetLogin = options.mkOption {
        type = types.bool;
        default = true;
        description = "Hide user list on login screen (users must enter handle manually).";
      };
    };

    logging = {
      enableAccessLog = options.mkOption {
        type = types.bool;
        default = true;
        description = "Write server access log.";
      };

      minLogLevel = options.mkOption {
        type = types.int;
        default = 0;
        description = "Minimum log level to display (DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3).";
      };
    };

    thumbnails = {
      enabled = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable thumbnail generation.";
      };

      quality = options.mkOption {
        type = types.int;
        default = 95;
        description = "JPEG thumbnail quality (0-100).";
      };

      format = options.mkOption {
        type = types.enum ["jpg" "png"];
        default = "jpg";
        description = "Image format for thumbnails.";
      };

      dimensions = options.mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            width = options.mkOption {
              type = types.int;
              description = "Width in pixels.";
            };
            height = options.mkOption {
              type = types.int;
              description = "Height in pixels.";
            };
          };
        });
        default = {
          bg = {
            width = 160;
            height = 90;
          };
          avatar = {
            width = 96;
            height = 144;
          };
        };
        description = "Thumbnail dimensions for different types.";
      };
    };

    backups = {
      enabled = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic chat backups.";
      };

      checkIntegrity = options.mkOption {
        type = types.bool;
        default = true;
        description = "Verify integrity of chat files before saving.";
      };

      numberOfBackups = options.mkOption {
        type = types.int;
        default = 50;
        description = "Number of backups to keep.";
      };
    };

    systemExtensions = options.mkOption {
      type = types.attrsOf types.package;
      default = {};
      description = "System-wide extensions to install. Keys are extension names, values are packages.";
      example = lib.literalExpression ''
        {
          "my-extension" = pkgs.fetchFromGitHub {
            owner = "owner";
            repo = "repo";
            rev = "main";
            sha256 = "...";
          };
        }
      '';
    };

    extensions = {
      enabled = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable UI extensions.";
      };

      autoUpdate = options.mkOption {
        type = types.bool;
        default = true;
        description = "Auto-update extensions when release version changes.";
      };

      models = {
        autoDownload = options.mkOption {
          type = types.bool;
          default = true;
          description = "Enable automatic model downloads.";
        };

        classification = options.mkOption {
          type = types.str;
          default = "Cohee/distilbert-base-uncased-go-emotions-onnx";
          description = "HuggingFace model ID for classification.";
        };

        captioning = options.mkOption {
          type = types.str;
          default = "Xenova/vit-gpt2-image-captioning";
          description = "HuggingFace model ID for image captioning.";
        };

        embedding = options.mkOption {
          type = types.str;
          default = "Cohee/jina-embeddings-v2-base-en";
          description = "HuggingFace model ID for embeddings.";
        };

        speechToText = options.mkOption {
          type = types.str;
          default = "Xenova/whisper-small";
          description = "HuggingFace model ID for speech-to-text.";
        };

        textToSpeech = options.mkOption {
          type = types.str;
          default = "Xenova/speecht5_tts";
          description = "HuggingFace model ID for text-to-speech.";
        };
      };
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      # Enable upstream NixOS module
      services.sillytavern = {
        enable = true;
        inherit (cfg) port;
        listen = true;
        whitelist = false;
        configFile = toString configFile;
      };

      # Install system extensions if configured
      systemd.tmpfiles.settings.sillytavern-extensions = lib.mkIf (cfg.systemExtensions != {}) {
        "/var/lib/SillyTavern/extensions/third-party".L = {
          argument = toString sillytavernExtensions;
          user = "sillytavern";
          group = "sillytavern";
        };
      };

      links.sillytavern = {
        protocol = "http";
        inherit (cfg) port;
      };

      rat.services.traefik.routes.sillytavern = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.sillytavern.url;
        authentik = true;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/SillyTavern";
            user = "sillytavern";
            group = "sillytavern";
          }
        ];
      };
    })
  ];
}
