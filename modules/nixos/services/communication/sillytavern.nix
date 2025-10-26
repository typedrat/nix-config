{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.sillytavern;
  impermanenceCfg = config.rat.impermanence;
  inherit (config.links.sillytavern) port;

  sillytavernExtensions = pkgs.linkFarm "sillytavern-extensions" (
    lib.mapAttrsToList (name: path: {inherit name path;}) cfg.systemExtensions
  );

  configFile = pkgs.writeText "sillytavern-config.yaml" (lib.generators.toYAML {} {
    # Data configuration
    dataRoot = "/var/lib/SillyTavern/data";

    # Server configuration
    listen = true;
    inherit port;
    listenAddress = {
      ipv4 = "0.0.0.0";
      ipv6 = "[::]";
    };
    protocol = {
      ipv4 = true;
      ipv6 = false;
    };
    dnsPreferIPv6 = false;

    # Browser launch configuration
    browserLaunch = {
      enabled = false;
      browser = "default";
      hostname = "auto";
      port = -1;
      avoidLocalhost = false;
    };

    # SSL configuration
    ssl = {
      enabled = false;
      certPath = "./certs/cert.pem";
      keyPath = "./certs/privkey.pem";
      keyPassphrase = "";
    };

    # Security configuration
    inherit (cfg) allowKeysExposure;
    inherit (cfg) skipContentCheck;
    whitelistImportDomains = [
      "localhost"
      "cdn.discordapp.com"
      "files.catbox.moe"
      "raw.githubusercontent.com"
      "char-archive.evulid.cc"
    ];
    requestOverrides = [];

    # Authentication and access control
    autheliaAuth = true;
    basicAuthMode = false;
    basicAuthUser = {
      username = "user";
      password = "password";
    };
    perUserBasicAuth = false;
    enableCorsProxy = false;

    # Request proxy configuration
    requestProxy = {
      enabled = false;
      url = "socks5://username:password@example.com:1080";
      bypass = ["localhost" "127.0.0.1"];
    };

    # Host whitelist configuration
    hostWhitelist = {
      enabled = false;
      scan = true;
      hosts = [];
    };

    # Security settings
    securityOverride = true;
    disableCsrfProtection = false;
    enableUserAccounts = cfg.multiUser.enable;
    inherit (cfg.multiUser) enableDiscreetLogin;
    whitelistMode = false;
    whitelist = ["127.0.0.1" "::1"];
    enableForwardedWhitelist = true;
    whitelistDockerHosts = false;
    sessionTimeout = -1;

    # Logging configuration
    logging = {
      inherit (cfg.logging) enableAccessLog;
      inherit (cfg.logging) minLogLevel;
    };

    # Rate limiting configuration
    rateLimiting = {
      preferRealIpHeader = true;
    };

    # Backup configuration
    backups = {
      chat = {
        inherit (cfg.backups) enabled;
        inherit (cfg.backups) checkIntegrity;
        inherit (cfg.backups) maxTotalBackups;
        inherit (cfg.backups) throttleInterval;
      };
      common = {
        inherit (cfg.backups) numberOfBackups;
      };
    };

    # Thumbnail configuration
    thumbnails = {
      inherit (cfg.thumbnails) enabled;
      inherit (cfg.thumbnails) quality;
      inherit (cfg.thumbnails) format;
      dimensions = lib.mapAttrs (_name: dim: [dim.width dim.height]) cfg.thumbnails.dimensions;
    };

    # Performance configuration
    performance = {
      inherit (cfg.performance) lazyLoadCharacters;
      inherit (cfg.performance) memoryCacheCapacity;
      inherit (cfg.performance) useDiskCache;
    };

    # Cache buster configuration
    cacheBuster = {
      inherit (cfg.cacheBuster) enabled;
      inherit (cfg.cacheBuster) userAgentPattern;
    };

    # Extensions configuration
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

    # Additional configuration
    inherit (cfg) enableDownloadableTokenizers;
    inherit (cfg) enableServerPlugins;
    inherit (cfg) enableServerPluginsAutoUpdate;

    # API-specific configurations
    inherit (cfg) promptPlaceholder;
    openai = {
      inherit (cfg.openai) randomizeUserId;
      inherit (cfg.openai) captionSystemPrompt;
    };
    deepl = {
      inherit (cfg.deepl) formality;
    };
    mistral = {
      inherit (cfg.mistral) enablePrefix;
    };
    ollama = {
      inherit (cfg.ollama) keepAlive;
      inherit (cfg.ollama) batchSize;
    };
    claude = {
      inherit (cfg.claude) enableSystemPromptCache;
      inherit (cfg.claude) cachingAtDepth;
      inherit (cfg.claude) extendedTTL;
    };
    gemini = {
      inherit (cfg.gemini) apiVersion;
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
          persona = {
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

      maxTotalBackups = options.mkOption {
        type = types.int;
        default = -1;
        description = "Maximum number of chat backups to keep per user. Set to -1 to keep all backups.";
      };

      throttleInterval = options.mkOption {
        type = types.int;
        default = 10000;
        description = "Interval in milliseconds to throttle chat backups per user.";
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

    performance = {
      lazyLoadCharacters = options.mkOption {
        type = types.bool;
        default = false;
        description = "Enables lazy loading of character cards. Improves performances with large card libraries.";
      };

      memoryCacheCapacity = options.mkOption {
        type = types.str;
        default = "100mb";
        description = "The maximum amount of memory that parsed character cards can use. Set to 0 to disable memory caching.";
      };

      useDiskCache = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enables disk caching for character cards. Improves performances with large card libraries.";
      };
    };

    cacheBuster = {
      enabled = options.mkOption {
        type = types.bool;
        default = false;
        description = "Clear browser cache on first load or after uploading image files.";
      };

      userAgentPattern = options.mkOption {
        type = types.str;
        default = "";
        description = "Only clear cache for the specified user agent regex pattern.";
      };
    };

    promptPlaceholder = options.mkOption {
      type = types.str;
      default = "[Start a new chat]";
      description = "A placeholder message to use in strict prompt post-processing mode.";
    };

    openai = {
      randomizeUserId = options.mkOption {
        type = types.bool;
        default = false;
        description = "Will send a random user ID to OpenAI completion API.";
      };

      captionSystemPrompt = options.mkOption {
        type = types.str;
        default = "";
        description = "System message to add to the start of every caption completion prompt.";
      };
    };

    deepl = {
      formality = options.mkOption {
        type = types.enum ["default" "more" "less" "prefer_more" "prefer_less"];
        default = "default";
        description = "DeepL translation formality setting.";
      };
    };

    mistral = {
      enablePrefix = options.mkOption {
        type = types.bool;
        default = false;
        description = "Enables prefilling of the reply with the last assistant message in the prompt.";
      };
    };

    ollama = {
      keepAlive = options.mkOption {
        type = types.int;
        default = -1;
        description = "Controls how long the model will stay loaded into memory following the request.";
      };

      batchSize = options.mkOption {
        type = types.int;
        default = -1;
        description = "Controls the batch size parameter of the generation request.";
      };
    };

    claude = {
      enableSystemPromptCache = options.mkOption {
        type = types.bool;
        default = false;
        description = "Enables caching of the system prompt (if supported).";
      };

      cachingAtDepth = options.mkOption {
        type = types.int;
        default = -1;
        description = "Enables caching of the message history at depth (if supported).";
      };

      extendedTTL = options.mkOption {
        type = types.bool;
        default = false;
        description = "Use 1h TTL instead of the default 5m.";
      };
    };

    gemini = {
      apiVersion = options.mkOption {
        type = types.str;
        default = "v1beta";
        description = "API endpoint version.";
      };
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      # Enable upstream NixOS module
      services.sillytavern = {
        enable = true;
        inherit port;
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
