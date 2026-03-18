{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  jellarrCfg = config.rat.services.jellarr;
  cfg = config.rat.services.jellarr.plugins.shokofin;

  titleSourceOrder = types.enum ["Shoko" "AniDB" "TMDB"];
  titleList = types.enum ["Romaji" "English" "Japanese" "Default"];
in {
  options.rat.services.jellarr.plugins.shokofin = {
    enable = options.mkEnableOption "Shokofin Jellyfin plugin";

    # Connection
    url = options.mkOption {
      type = types.str;
      default = config.links.shoko.url;
      defaultText = lib.literalExpression "config.links.shoko.url";
      description = "Shoko server URL.";
    };

    username = options.mkOption {
      type = types.str;
      default = "Default";
      description = "Shoko server username.";
    };

    # Library structure
    libraryOperationMode = options.mkOption {
      type = types.enum ["VFS" "Direct"];
      default = "VFS";
      description = "Library operation mode.";
    };

    useGroupsForShows = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use groups for shows.";
    };

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

    addTrailers = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add trailers.";
    };

    addMissingMetadata = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add missing metadata.";
    };

    # VFS options
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
    };

    # Titles
    titleMainOrder = options.mkOption {
      type = types.listOf titleSourceOrder;
      default = ["Shoko" "AniDB" "TMDB"];
      description = "Ordered list of sources for the main title.";
    };

    titleMainList = options.mkOption {
      type = types.listOf titleList;
      default = ["Romaji" "English" "Default"];
      description = "Ordered list of title languages for the main title.";
    };

    titleAlternateOrder = options.mkOption {
      type = types.listOf titleSourceOrder;
      default = ["Shoko" "AniDB" "TMDB"];
      description = "Ordered list of sources for alternate titles.";
    };

    titleAlternateList = options.mkOption {
      type = types.listOf titleList;
      default = ["English" "Romaji" "Japanese" "Default"];
      description = "Ordered list of title languages for alternate titles.";
    };

    # Descriptions
    descriptionSourceOrder = options.mkOption {
      type = types.listOf titleSourceOrder;
      default = ["AniDB" "TMDB" "Shoko"];
      description = "Ordered list of sources for descriptions.";
    };

    synopsisEnableMarkdown = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Markdown in synopses.";
    };

    synopsisCleanLinks = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to clean links from synopses.";
    };

    synopsisCleanMiscLines = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to clean miscellaneous lines from synopses.";
    };

    synopsisRemoveSummary = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to remove summary lines from synopses.";
    };

    # Tags & Genres
    hideUnverifiedTags = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to hide unverified tags.";
    };

    tagMaximumDepth = options.mkOption {
      type = types.int;
      default = 0;
      description = "Maximum depth for tags (0 = unlimited).";
    };

    genreMaximumDepth = options.mkOption {
      type = types.int;
      default = 1;
      description = "Maximum depth for genres.";
    };

    addAniDBId = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add the AniDB ID to metadata.";
    };

    addTMDBId = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to add the TMDB ID to metadata.";
    };

    # SignalR
    signalrAutoConnect = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically connect via SignalR.";
    };

    signalrRefreshEnabled = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable SignalR-triggered metadata refresh.";
    };

    signalrFileEvents = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable SignalR file events.";
    };

    # Collections
    autoMergeVersions = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically merge versions.";
    };

    autoReconstructCollections = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically reconstruct collections.";
    };

    collectionMinSizeOfTwo = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to require a minimum of two items for a collection.";
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
          Url = cfg.url;
          Username = cfg.username;
          ApiKey = config.sops.placeholder."jellarr/shokofin/apiKey";

          DefaultLibraryOperationMode = cfg.libraryOperationMode;
          UseGroupsForShows = cfg.useGroupsForShows;
          SeparateMovies = cfg.separateMovies;
          FilterMovieLibraries = cfg.filterMovieLibraries;
          AddTrailers = cfg.addTrailers;
          AddMissingMetadata = cfg.addMissingMetadata;

          VFS_Threads = cfg.vfs.threads;
          VFS_AddReleaseGroup = cfg.vfs.addReleaseGroup;
          VFS_AddResolution = cfg.vfs.addResolution;
          VFS_ResolveLinks = cfg.vfs.resolveLinks;

          TitleMainOrder = cfg.titleMainOrder;
          TitleMainList = cfg.titleMainList;
          TitleAlternateOrder = cfg.titleAlternateOrder;
          TitleAlternateList = cfg.titleAlternateList;

          DescriptionSourceOrder = cfg.descriptionSourceOrder;
          SynopsisEnableMarkdown = cfg.synopsisEnableMarkdown;
          SynopsisCleanLinks = cfg.synopsisCleanLinks;
          SynopsisCleanMiscLines = cfg.synopsisCleanMiscLines;
          SynopsisRemoveSummary = cfg.synopsisRemoveSummary;

          HideUnverifiedTags = cfg.hideUnverifiedTags;
          TagMaximumDepth = cfg.tagMaximumDepth;
          GenreMaximumDepth = cfg.genreMaximumDepth;
          AddAniDBId = cfg.addAniDBId;
          AddTMDBId = cfg.addTMDBId;

          SignalR_AutoConnectEnabled = cfg.signalrAutoConnect;
          SignalR_RefreshEnabled = cfg.signalrRefreshEnabled;
          SignalR_FileEvents = cfg.signalrFileEvents;

          AutoMergeVersions = cfg.autoMergeVersions;
          AutoReconstructCollections = cfg.autoReconstructCollections;
          CollectionMinSizeOfTwo = cfg.collectionMinSizeOfTwo;
        };
      }
    ];
  };
}
