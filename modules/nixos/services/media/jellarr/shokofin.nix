{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  jellarrCfg = config.rat.services.jellarr;
  cfg = config.rat.services.jellarr.plugins.shokofin;

  # --- Enum types ---

  titleProviderEnum = types.enum [
    "Shoko_Default"
    "AniDB_Default"
    "AniDB_LibraryLanguage"
    "AniDB_CountryOfOrigin"
    "TMDB_Default"
    "TMDB_LibraryLanguage"
    "TMDB_CountryOfOrigin"
  ];

  descProviderEnum = types.enum ["Shoko" "AniDB" "TMDB"];

  imageLanguageEnum = types.enum ["None" "Metadata" "Original" "English"];

  descriptionConversionModeEnum = types.enum ["Disabled" "PlainText" "Markdown"];

  libraryOperationModeEnum = types.enum ["VFS" "Direct"];

  vfsLocationEnum = types.enum ["Default" "Custom"];

  collectionGroupingEnum = types.enum ["None" "Default" "ShokoGroup" "ShokoSeries"];

  seasonOrderingEnum = types.enum ["Default" "AiringDate" "AddedDate"];

  specialsPlacementEnum = types.enum ["Excluded" "AfterSeason" "InBetween"];

  seasonMergingBehaviorEnum = types.enum ["NoMerge" "Merge" "Always"];

  tagMinimumWeightEnum = types.enum ["Weightless" "One" "Two" "Three" "Four" "Five" "Six"];

  metadataRefreshModeEnum = types.enum ["Disabled" "LegacyRefresh" "SmartRefresh" "ForceRefresh"];

  mergeVersionSortSelectorEnum = types.enum [
    "ImportedAt"
    "CreatedAt"
    "Resolution"
    "ReleaseGroupName"
    "FileSource"
    "FileVersion"
    "RelativeDepth"
    "NoVariation"
  ];

  providerNameEnum = types.enum ["AniDB" "TMDB"];

  seriesTypeEnum = types.enum ["Unknown" "TV" "TVSpecial" "Web" "Movie" "OVA" "Other"];

  thirdPartyIdProviderEnum = types.enum ["AniDB" "TMDB" "TvDB"];

  signalrEventSourceEnum = types.enum ["Shoko" "AniDB" "TMDB"];

  # --- Shared submodule types ---

  allTitleProviders = ["Shoko_Default" "AniDB_Default" "AniDB_LibraryLanguage" "AniDB_CountryOfOrigin" "TMDB_Default" "TMDB_LibraryLanguage" "TMDB_CountryOfOrigin"];
  allDescProviders = ["Shoko" "AniDB" "TMDB"];
  allImageLanguages = ["None" "Metadata" "Original" "English"];

  titleConfigType = types.submodule {
    options = {
      List = options.mkOption {
        type = types.listOf titleProviderEnum;
        default = [];
        description = "Selected title providers.";
      };
      Order = options.mkOption {
        type = types.listOf titleProviderEnum;
        default = allTitleProviders;
        description = "Order of title providers.";
      };
      AllowAny = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to allow any title provider.";
      };
    };
  };

  mkTitleEntityType = {isDefault ? false}:
    types.submodule {
      options =
        (lib.optionalAttrs (!isDefault) {
          Enabled = options.mkOption {
            type = types.bool;
            default = false;
            description = "Whether this title entity override is enabled.";
          };
        })
        // {
          RemoveDuplicates = options.mkOption {
            type = types.bool;
            default = false;
            description = "Whether to remove duplicate titles.";
          };
          MainTitle = options.mkOption {
            type = titleConfigType;
            default = {
              List = ["Shoko_Default"];
              Order = allTitleProviders;
              AllowAny = false;
            };
            description = "Main title configuration.";
          };
          AlternateTitles = options.mkOption {
            type = types.listOf titleConfigType;
            default = [
              {
                List = [];
                Order = allTitleProviders;
                AllowAny = false;
              }
            ];
            description = "Alternate title configurations.";
          };
        };
    };

  mkDescEntityType = {isDefault ? false}:
    types.submodule {
      options =
        (lib.optionalAttrs (!isDefault) {
          Enabled = options.mkOption {
            type = types.bool;
            default = false;
            description = "Whether this description entity override is enabled.";
          };
        })
        // {
          AddNotes = options.mkOption {
            type = types.bool;
            default = true;
            description = "Whether to add notes to descriptions.";
          };
          List = options.mkOption {
            type = types.listOf descProviderEnum;
            default = ["Shoko"];
            description = "Selected description providers.";
          };
          Order = options.mkOption {
            type = types.listOf descProviderEnum;
            default = allDescProviders;
            description = "Order of description providers.";
          };
        };
    };

  mkImageEntityType = {
    isDefault ? false,
    defaultUsePreferred ? false,
    defaultPosterList ? [],
  }:
    types.submodule {
      options =
        (lib.optionalAttrs (!isDefault) {
          Enabled = options.mkOption {
            type = types.bool;
            default = false;
            description = "Whether this image entity override is enabled.";
          };
        })
        // {
          UsePreferred = options.mkOption {
            type = types.bool;
            default = defaultUsePreferred;
            description = "Whether to use preferred images.";
          };
          UseCommunityRating = options.mkOption {
            type = types.bool;
            default = false;
            description = "Whether to use community rating for image selection.";
          };
          UseDimensions = options.mkOption {
            type = types.bool;
            default = false;
            description = "Whether to use dimensions for image selection.";
          };
          PosterList = options.mkOption {
            type = types.listOf imageLanguageEnum;
            default = defaultPosterList;
            description = "Selected poster image languages.";
          };
          PosterOrder = options.mkOption {
            type = types.listOf imageLanguageEnum;
            default = allImageLanguages;
            description = "Order of poster image languages.";
          };
          LogoList = options.mkOption {
            type = types.listOf imageLanguageEnum;
            default = [];
            description = "Selected logo image languages.";
          };
          LogoOrder = options.mkOption {
            type = types.listOf imageLanguageEnum;
            default = allImageLanguages;
            description = "Order of logo image languages.";
          };
          BackdropList = options.mkOption {
            type = types.listOf imageLanguageEnum;
            default = [];
            description = "Selected backdrop image languages.";
          };
          BackdropOrder = options.mkOption {
            type = types.listOf imageLanguageEnum;
            default = allImageLanguages;
            description = "Order of backdrop image languages.";
          };
        };
    };

  # Entity type names (excluding Default which is handled separately)
  overrideEntityNames = [
    "ShokoCollection"
    "TmdbCollection"
    "AnidbMovie"
    "ShokoMovie"
    "TmdbMovie"
    "AnidbAnime"
    "ShokoSeries"
    "TmdbShow"
    "AnidbSeason"
    "ShokoSeason"
    "TmdbSeason"
    "AnidbEpisode"
    "ShokoEpisode"
    "TmdbEpisode"
  ];

  mkEntityOverrideOptions = mkEntityFn:
    options.mkOption {
      type = types.attrsOf (mkEntityFn {isDefault = false;});
      default = {};
      description = ''
        Per-entity-type overrides. Keys must be one of: ${lib.concatStringsSep ", " overrideEntityNames}.
        Unspecified entity types use defaults with Enabled = false.
      '';
    };

  # --- Default JSON values for override entities (Enabled = false) ---

  defaultTitleOverride = {
    Enabled = false;
    RemoveDuplicates = false;
    MainTitle = {
      List = ["Shoko_Default"];
      Order = allTitleProviders;
      AllowAny = false;
    };
    AlternateTitles = [
      {
        List = [];
        Order = allTitleProviders;
        AllowAny = false;
      }
    ];
  };

  defaultDescOverride = {
    Enabled = false;
    AddNotes = true;
    List = ["Shoko"];
    Order = allDescProviders;
  };

  defaultImageOverride = {
    Enabled = false;
    UsePreferred = false;
    UseCommunityRating = false;
    UseDimensions = false;
    PosterList = [];
    PosterOrder = allImageLanguages;
    LogoList = [];
    LogoOrder = allImageLanguages;
    BackdropList = [];
    BackdropOrder = allImageLanguages;
  };

  # Convert a module-evaluated title entity config to JSON attrset
  titleEntityToAttrs = isDefault: v:
    (lib.optionalAttrs (!isDefault) {inherit (v) Enabled;})
    // {
      inherit (v) RemoveDuplicates;
      MainTitle = {inherit (v.MainTitle) List Order AllowAny;};
      AlternateTitles = map (t: {inherit (t) List Order AllowAny;}) v.AlternateTitles;
    };

  descEntityToAttrs = isDefault: v:
    (lib.optionalAttrs (!isDefault) {inherit (v) Enabled;})
    // {inherit (v) AddNotes List Order;};

  imageEntityToAttrs = isDefault: v:
    (lib.optionalAttrs (!isDefault) {inherit (v) Enabled;})
    // {
      inherit (v) UsePreferred UseCommunityRating UseDimensions;
      inherit (v) PosterList PosterOrder LogoList LogoOrder BackdropList BackdropOrder;
    };

  # Build full entity section: Default + all 14 override entity types
  buildEntitySection = {
    defaultValue,
    overrides,
    mkDefaultAttrs,
    mkOverrideAttrs,
    defaultOverrideAttrs,
  }: let
    mkOverride = name:
      if overrides ? ${name}
      then mkOverrideAttrs overrides.${name}
      else defaultOverrideAttrs;
  in
    {Default = mkDefaultAttrs defaultValue;}
    // lib.genAttrs overrideEntityNames mkOverride;

  buildTitleSection = buildEntitySection {
    defaultValue = cfg.title.Default;
    inherit (cfg.title) overrides;
    mkDefaultAttrs = titleEntityToAttrs true;
    mkOverrideAttrs = titleEntityToAttrs false;
    defaultOverrideAttrs = defaultTitleOverride;
  };

  buildDescSection = buildEntitySection {
    defaultValue = cfg.description.Default;
    inherit (cfg.description) overrides;
    mkDefaultAttrs = descEntityToAttrs true;
    mkOverrideAttrs = descEntityToAttrs false;
    defaultOverrideAttrs = defaultDescOverride;
  };

  buildImageSection = buildEntitySection {
    defaultValue = cfg.image.Default;
    inherit (cfg.image) overrides;
    mkDefaultAttrs = imageEntityToAttrs true;
    mkOverrideAttrs = imageEntityToAttrs false;
    defaultOverrideAttrs = defaultImageOverride;
  };
in {
  options.rat.services.jellarr.plugins.shokofin = {
    enable = options.mkEnableOption "Shokofin Jellyfin plugin";

    # --- Connection ---

    url = options.mkOption {
      type = types.str;
      default = config.links.shoko.url;
      defaultText = lib.literalExpression "config.links.shoko.url";
      description = "Shoko server URL.";
    };

    publicUrl = options.mkOption {
      type = types.str;
      default = "";
      description = "Shoko server public URL.";
    };

    webPrefix = options.mkOption {
      type = types.str;
      default = "";
      description = "Web prefix for Shoko.";
    };

    username = options.mkOption {
      type = types.str;
      default = "Default";
      description = "Shoko server username.";
    };

    # --- Third-party IDs ---

    thirdPartyIdProviderList = options.mkOption {
      type = types.listOf thirdPartyIdProviderEnum;
      default = ["AniDB"];
      description = "List of third-party ID providers to include.";
    };

    # --- General metadata ---

    markSpecialsWhenGrouped = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to mark specials when grouped.";
    };

    descriptionConversionMode = options.mkOption {
      type = descriptionConversionModeEnum;
      default = "Markdown";
      description = "How to convert descriptions.";
    };

    studioOnlyAnimationWorks = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to only show animation studios.";
    };

    # --- Tags ---

    tagSources = options.mkOption {
      type = types.str;
      default = "ContentIndicators, Dynamic, DynamicCast, DynamicEnding, Elements, ElementsPornographyAndSexualAbuse, ElementsTropesAndMotifs, Fetishes, OriginProduction, OriginDevelopment, SettingPlace, SettingTimePeriod, SettingTimeSeason, SourceMaterial, TargetAudience, TechnicalAspects, TechnicalAspectsAdaptions, TechnicalAspectsAwards, TechnicalAspectsMultiAnimeProjects, Themes, ThemesDeath, ThemesTales, CustomTags, AllYearlySeasons";
      description = "Comma-separated tag source flags.";
    };

    tagIncludeFilters = options.mkOption {
      type = types.str;
      default = "Parent, Child, Abstract, Weightless, Weighted";
      description = "Comma-separated tag include filter flags.";
    };

    tagMinimumWeight = options.mkOption {
      type = tagMinimumWeightEnum;
      default = "Weightless";
      description = "Minimum weight for tags.";
    };

    tagMaximumDepth = options.mkOption {
      type = types.int;
      default = 0;
      description = "Maximum depth for tags (0 = unlimited).";
    };

    tagExcludeList = options.mkOption {
      type = types.listOf types.str;
      default = ["18 restricted"];
      description = "Tags to exclude.";
    };

    # --- Genres ---

    genreSources = options.mkOption {
      type = types.str;
      default = "Elements, SourceMaterial, TargetAudience";
      description = "Comma-separated genre source flags.";
    };

    genreIncludeFilters = options.mkOption {
      type = types.str;
      default = "Parent, Child, Abstract, Weightless, Weighted";
      description = "Comma-separated genre include filter flags.";
    };

    genreMinimumWeight = options.mkOption {
      type = tagMinimumWeightEnum;
      default = "Four";
      description = "Minimum weight for genres.";
    };

    genreMaximumDepth = options.mkOption {
      type = types.int;
      default = 1;
      description = "Maximum depth for genres.";
    };

    genreExcludeList = options.mkOption {
      type = types.listOf types.str;
      default = ["18 restricted"];
      description = "Genres to exclude.";
    };

    hideUnverifiedTags = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to hide unverified tags.";
    };

    # --- Content rating & production location ---

    contentRatingList = options.mkOption {
      type = types.listOf providerNameEnum;
      default = ["TMDB" "AniDB"];
      description = "Selected content rating providers.";
    };

    contentRatingOrder = options.mkOption {
      type = types.listOf providerNameEnum;
      default = ["TMDB" "AniDB"];
      description = "Order of content rating providers.";
    };

    productionLocationList = options.mkOption {
      type = types.listOf providerNameEnum;
      default = ["AniDB" "TMDB"];
      description = "Selected production location providers.";
    };

    productionLocationOrder = options.mkOption {
      type = types.listOf providerNameEnum;
      default = ["AniDB" "TMDB"];
      description = "Order of production location providers.";
    };

    # --- Users ---

    userList = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of Shoko user mappings.";
    };

    # --- Version merging ---

    autoMergeVersions = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically merge versions.";
    };

    mergeVersionSortSelectorList = options.mkOption {
      type = types.listOf mergeVersionSortSelectorEnum;
      default = ["ImportedAt"];
      description = "Selected merge version sort selectors.";
    };

    mergeVersionSortSelectorOrder = options.mkOption {
      type = types.listOf mergeVersionSortSelectorEnum;
      default = ["ImportedAt" "CreatedAt" "Resolution" "ReleaseGroupName" "FileSource" "FileVersion" "RelativeDepth" "NoVariation"];
      description = "Order of merge version sort selectors.";
    };

    # --- Library structure ---

    separateMovies = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to separate movies from series.";
    };

    filterMovieLibraries = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to filter movie libraries.";
    };

    movieSpecialsAsExtraFeaturettes = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to treat movie specials as extra featurettes.";
    };

    addTrailers = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add trailers.";
    };

    addCreditsAsThemeVideos = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add credits as theme videos.";
    };

    addCreditsAsSpecialFeatures = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to add credits as special features.";
    };

    defaultSeasonOrdering = options.mkOption {
      type = seasonOrderingEnum;
      default = "Default";
      description = "Default season ordering mode.";
    };

    defaultSpecialsPlacement = options.mkOption {
      type = specialsPlacementEnum;
      default = "Excluded";
      description = "Default placement for specials.";
    };

    addMissingMetadata = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add missing metadata.";
    };

    libraryScanReactionTimeInSeconds = options.mkOption {
      type = types.int;
      default = 1;
      description = "Reaction time in seconds for library scan events.";
    };

    ignoredFolders = options.mkOption {
      type = types.listOf types.str;
      default = [".streams" "@recently-snapshot"];
      description = "Folders to ignore during library scans.";
    };

    # --- Collections ---

    autoReconstructCollections = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically reconstruct collections.";
    };

    collectionGrouping = options.mkOption {
      type = collectionGroupingEnum;
      default = "None";
      description = "Collection grouping mode.";
    };

    collectionMinSizeOfTwo = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to require a minimum of two items for a collection.";
    };

    # --- Library operation mode ---

    defaultLibraryOperationMode = options.mkOption {
      type = libraryOperationModeEnum;
      default = "VFS";
      description = "Default library operation mode.";
    };

    # --- VFS ---

    vfs = {
      threads = options.mkOption {
        type = types.int;
        default = 4;
        description = "Number of VFS threads.";
      };

      addReleaseGroup = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to add release group to VFS paths.";
      };

      addResolution = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to add resolution to VFS paths.";
      };

      resolveLinks = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to resolve symbolic links in VFS.";
      };

      maxTotalExceptionsBeforeAbort = options.mkOption {
        type = types.int;
        default = 10;
        description = "Maximum total exceptions before aborting VFS generation.";
      };

      maxSeriesExceptionsBeforeAbort = options.mkOption {
        type = types.int;
        default = 3;
        description = "Maximum per-series exceptions before aborting VFS generation.";
      };

      useSemaphore = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use a semaphore for VFS operations.";
      };

      location = options.mkOption {
        type = vfsLocationEnum;
        default = "Default";
        description = "VFS location mode.";
      };

      alwaysIncludedAnidbIdList = options.mkOption {
        type = types.listOf types.int;
        default = [3651];
        description = "AniDB IDs to always include in VFS.";
      };

      iterativeGenerationEnabled = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable iterative VFS generation.";
      };

      iterativeGenerationMaxCount = options.mkOption {
        type = types.int;
        default = 0;
        description = "Maximum count for iterative VFS generation (0 = unlimited).";
      };
    };

    # --- Libraries ---

    libraries = options.mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Library configurations (passed through as-is).";
    };

    libraryFolders = options.mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Library folder configurations (passed through as-is).";
    };

    # --- SignalR ---

    signalR = {
      autoConnectEnabled = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to automatically connect via SignalR.";
      };

      autoReconnectInSeconds = options.mkOption {
        type = types.listOf types.int;
        default = [0 2 10 30 60 120 300];
        description = "SignalR auto-reconnect delay schedule in seconds.";
      };

      refreshEnabled = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable SignalR-triggered metadata refresh.";
      };

      fileEvents = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable SignalR file events.";
      };

      eventSources = options.mkOption {
        type = types.listOf signalrEventSourceEnum;
        default = ["Shoko" "AniDB" "TMDB"];
        description = "SignalR event sources.";
      };
    };

    # --- Season merging ---

    seasonMerging = {
      enabled = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable season merging.";
      };

      defaultBehavior = options.mkOption {
        type = seasonMergingBehaviorEnum;
        default = "NoMerge";
        description = "Default season merging behavior.";
      };

      seriesTypes = options.mkOption {
        type = types.listOf seriesTypeEnum;
        default = ["OVA" "TV" "TVSpecial" "Web" "OVA"];
        description = "Series types to consider for season merging.";
      };

      mergeWindowInDays = options.mkOption {
        type = types.int;
        default = 185;
        description = "Merge window in days.";
      };
    };

    # --- Metadata refresh ---

    metadataRefresh = {
      updateUnaired = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to update unaired metadata.";
      };

      autoRefreshRangeInDays = options.mkOption {
        type = types.int;
        default = 7;
        description = "Auto-refresh range in days.";
      };

      antiRefreshDeadZoneInHours = options.mkOption {
        type = types.int;
        default = 24;
        description = "Anti-refresh dead zone in hours.";
      };

      outOfSyncInDays = options.mkOption {
        type = types.int;
        default = 180;
        description = "Out of sync threshold in days.";
      };

      collection = options.mkOption {
        type = metadataRefreshModeEnum;
        default = "LegacyRefresh";
        description = "Metadata refresh mode for collections.";
      };

      movie = options.mkOption {
        type = metadataRefreshModeEnum;
        default = "LegacyRefresh";
        description = "Metadata refresh mode for movies.";
      };

      series = options.mkOption {
        type = metadataRefreshModeEnum;
        default = "LegacyRefresh";
        description = "Metadata refresh mode for series.";
      };

      season = options.mkOption {
        type = metadataRefreshModeEnum;
        default = "LegacyRefresh";
        description = "Metadata refresh mode for seasons.";
      };

      video = options.mkOption {
        type = metadataRefreshModeEnum;
        default = "LegacyRefresh";
        description = "Metadata refresh mode for videos.";
      };

      episode = options.mkOption {
        type = metadataRefreshModeEnum;
        default = "LegacyRefresh";
        description = "Metadata refresh mode for episodes.";
      };
    };

    # --- Debug ---

    debug = {
      showInUI = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to show debug options in UI.";
      };

      usageTrackerStalledTimeInSeconds = options.mkOption {
        type = types.int;
        default = 60;
        description = "Usage tracker stalled time in seconds.";
      };

      maxInFlightRequests = options.mkOption {
        type = types.int;
        default = 10;
        description = "Maximum in-flight requests.";
      };

      seriesPageSize = options.mkOption {
        type = types.int;
        default = 25;
        description = "Series page size for API requests.";
      };

      autoClearClientCache = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to auto-clear client cache.";
      };

      autoClearManagerCache = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to auto-clear manager cache.";
      };

      autoClearVfsCache = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to auto-clear VFS cache.";
      };

      expirationScanFrequencyInMinutes = options.mkOption {
        type = types.int;
        default = 25;
        description = "Cache expiration scan frequency in minutes.";
      };

      slidingExpirationInMinutes = options.mkOption {
        type = types.int;
        default = 15;
        description = "Sliding cache expiration in minutes.";
      };

      absoluteExpirationRelativeToNowInMinutes = options.mkOption {
        type = types.int;
        default = 120;
        description = "Absolute cache expiration relative to now in minutes.";
      };
    };

    # --- Misc ---

    showInMenu = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to show Shokofin in the Jellyfin menu.";
    };

    advancedMode = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable advanced mode in the plugin UI.";
    };

    # --- Entity-type sections ---

    title = {
      Default = options.mkOption {
        type = mkTitleEntityType {isDefault = true;};
        default = {};
        description = "Default title configuration.";
      };
      overrides = mkEntityOverrideOptions mkTitleEntityType;
    };

    description = {
      Default = options.mkOption {
        type = mkDescEntityType {isDefault = true;};
        default = {};
        description = "Default description configuration.";
      };
      overrides = mkEntityOverrideOptions mkDescEntityType;
    };

    image = {
      Default = options.mkOption {
        type = mkImageEntityType {
          isDefault = true;
          defaultUsePreferred = true;
          defaultPosterList = ["None"];
        };
        default = {};
        description = "Default image configuration.";
      };
      overrides = mkEntityOverrideOptions (args:
        mkImageEntityType (args
          // {
            defaultUsePreferred = false;
            defaultPosterList = [];
          }));
    };
  };

  config = modules.mkIf (jellarrCfg.enable && cfg.enable) {
    sops.secrets."jellarr/shokofin/apiKey" = {
      sopsFile = ../../../../../secrets/jellyfin.yaml;
      key = "jellarr/shokofin/apiKey";
      owner = "jellarr";
      mode = "0400";
    };

    rat.services.jellarr._jellarrPluginRepos = [
      {
        name = "Shokofin";
        url = "https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json";
        enabled = true;
      }
    ];

    rat.services.jellarr._jellarrPlugins = [
      {
        name = "Shoko";
        configuration = {
          # Connection
          Url = cfg.url;
          PublicUrl = cfg.publicUrl;
          WebPrefix = cfg.webPrefix;
          Username = cfg.username;
          ApiKey = config.sops.placeholder."jellarr/shokofin/apiKey";
          HasPluginsExposed = false;

          # Third-party IDs
          ThirdPartyIdProviderList = cfg.thirdPartyIdProviderList;

          # General metadata
          MarkSpecialsWhenGrouped = cfg.markSpecialsWhenGrouped;
          DescriptionConversionMode = cfg.descriptionConversionMode;
          Metadata_StudioOnlyAnimationWorks = cfg.studioOnlyAnimationWorks;

          # Tags
          TagSources = cfg.tagSources;
          TagIncludeFilters = cfg.tagIncludeFilters;
          TagMinimumWeight = cfg.tagMinimumWeight;
          TagMaximumDepth = cfg.tagMaximumDepth;
          TagExcludeList = cfg.tagExcludeList;

          # Genres
          GenreSources = cfg.genreSources;
          GenreIncludeFilters = cfg.genreIncludeFilters;
          GenreMinimumWeight = cfg.genreMinimumWeight;
          GenreMaximumDepth = cfg.genreMaximumDepth;
          GenreExcludeList = cfg.genreExcludeList;
          HideUnverifiedTags = cfg.hideUnverifiedTags;

          # Content rating & production location
          ContentRatingList = cfg.contentRatingList;
          ContentRatingOrder = cfg.contentRatingOrder;
          ProductionLocationList = cfg.productionLocationList;
          ProductionLocationOrder = cfg.productionLocationOrder;

          # Users
          UserList = cfg.userList;

          # Version merging
          AutoMergeVersions = cfg.autoMergeVersions;
          MergeVersionSortSelectorList = cfg.mergeVersionSortSelectorList;
          MergeVersionSortSelectorOrder = cfg.mergeVersionSortSelectorOrder;

          # Library structure
          SeparateMovies = cfg.separateMovies;
          FilterMovieLibraries = cfg.filterMovieLibraries;
          MovieSpecialsAsExtraFeaturettes = cfg.movieSpecialsAsExtraFeaturettes;
          AddTrailers = cfg.addTrailers;
          AddCreditsAsThemeVideos = cfg.addCreditsAsThemeVideos;
          AddCreditsAsSpecialFeatures = cfg.addCreditsAsSpecialFeatures;
          DefaultSeasonOrdering = cfg.defaultSeasonOrdering;
          DefaultSpecialsPlacement = cfg.defaultSpecialsPlacement;
          AddMissingMetadata = cfg.addMissingMetadata;
          LibraryScanReactionTimeInSeconds = cfg.libraryScanReactionTimeInSeconds;
          IgnoredFolders = cfg.ignoredFolders;

          # Collections
          AutoReconstructCollections = cfg.autoReconstructCollections;
          CollectionGrouping = cfg.collectionGrouping;
          CollectionMinSizeOfTwo = cfg.collectionMinSizeOfTwo;

          # Library operation mode
          DefaultLibraryOperationMode = cfg.defaultLibraryOperationMode;

          # VFS
          VFS_Threads = cfg.vfs.threads;
          VFS_AddReleaseGroup = cfg.vfs.addReleaseGroup;
          VFS_AddResolution = cfg.vfs.addResolution;
          VFS_ResolveLinks = cfg.vfs.resolveLinks;
          VFS_MaxTotalExceptionsBeforeAbort = cfg.vfs.maxTotalExceptionsBeforeAbort;
          VFS_MaxSeriesExceptionsBeforeAbort = cfg.vfs.maxSeriesExceptionsBeforeAbort;
          VFS_UseSemaphore = cfg.vfs.useSemaphore;
          VFS_Location = cfg.vfs.location;
          VFS_AlwaysIncludedAnidbIdList = cfg.vfs.alwaysIncludedAnidbIdList;
          VFS_IterativeGenerationEnabled = cfg.vfs.iterativeGenerationEnabled;
          VFS_IterativeGenerationMaxCount = cfg.vfs.iterativeGenerationMaxCount;

          # Libraries
          Libraries = cfg.libraries;
          LibraryFolders = cfg.libraryFolders;

          # SignalR
          SignalR_AutoConnectEnabled = cfg.signalR.autoConnectEnabled;
          SignalR_AutoReconnectInSeconds = cfg.signalR.autoReconnectInSeconds;
          SignalR_RefreshEnabled = cfg.signalR.refreshEnabled;
          SignalR_FileEvents = cfg.signalR.fileEvents;
          SignalR_EventSources = cfg.signalR.eventSources;

          # Season merging
          SeasonMerging_Enabled = cfg.seasonMerging.enabled;
          SeasonMerging_DefaultBehavior = cfg.seasonMerging.defaultBehavior;
          SeasonMerging_SeriesTypes = cfg.seasonMerging.seriesTypes;
          SeasonMerging_MergeWindowInDays = cfg.seasonMerging.mergeWindowInDays;

          # Metadata refresh
          MetadataRefresh = {
            UpdateUnaired = cfg.metadataRefresh.updateUnaired;
            AutoRefreshRangeInDays = cfg.metadataRefresh.autoRefreshRangeInDays;
            AntiRefreshDeadZoneInHours = cfg.metadataRefresh.antiRefreshDeadZoneInHours;
            OutOfSyncInDays = cfg.metadataRefresh.outOfSyncInDays;
            Collection = cfg.metadataRefresh.collection;
            Movie = cfg.metadataRefresh.movie;
            Series = cfg.metadataRefresh.series;
            Season = cfg.metadataRefresh.season;
            Video = cfg.metadataRefresh.video;
            Episode = cfg.metadataRefresh.episode;
          };

          # Debug
          Debug = {
            ShowInUI = cfg.debug.showInUI;
            UsageTrackerStalledTimeInSeconds = cfg.debug.usageTrackerStalledTimeInSeconds;
            MaxInFlightRequests = cfg.debug.maxInFlightRequests;
            SeriesPageSize = cfg.debug.seriesPageSize;
            AutoClearClientCache = cfg.debug.autoClearClientCache;
            AutoClearManagerCache = cfg.debug.autoClearManagerCache;
            AutoClearVfsCache = cfg.debug.autoClearVfsCache;
            ExpirationScanFrequencyInMinutes = cfg.debug.expirationScanFrequencyInMinutes;
            SlidingExpirationInMinutes = cfg.debug.slidingExpirationInMinutes;
            AbsoluteExpirationRelativeToNowInMinutes = cfg.debug.absoluteExpirationRelativeToNowInMinutes;
          };

          # Misc
          Misc_ShowInMenu = cfg.showInMenu;
          AdvancedMode = cfg.advancedMode;

          # Entity-type sections
          Title = buildTitleSection;
          Description = buildDescSection;
          Image = buildImageSection;
        };
      }
    ];
  };
}
