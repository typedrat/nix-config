# Conversion from nested Nix settings to flat INI format.
#
# This module provides functions to transform the user-friendly nested
# structure into the flat key=value format expected by Skyscraper's config.ini.
{lib}: let
  inherit (lib) filterAttrs;

  # Import types for helper functions
  skyscraperTypes = import ./types.nix {inherit lib;};

  # ── Helper Functions ───────────────────────────────────────────────

  # Convert a list to comma-separated string
  listToComma = list:
    if list == null || list == []
    then null
    else lib.concatStringsSep "," list;

  # Convert a list of extensions to space-separated with *. prefix
  extensionsToStr = list:
    if list == null || list == []
    then null
    else lib.concatMapStringsSep " " (e: "*.${e}") list;

  # Convert path (which might be a Nix store path) to string
  pathToStr = p:
    if p == null
    then null
    else toString p;

  # Filter out null values and empty attrsets
  filterNulls = attrs:
    filterAttrs (
      _: v:
        v != null && v != {} && v != []
    )
    attrs;

  # ── Main Settings Conversion ───────────────────────────────────────

  # Convert main settings to INI attrset
  # Returns { attrs = { ... }; secrets = [ ... ]; }
  mainSettingsToIni = cfg:
    filterNulls {
      # Paths
      inputFolder = cfg.paths.roms or null;
      gameListFolder = cfg.paths.gameLists or null;
      mediaFolder = cfg.paths.media or null;
      cacheFolder = cfg.paths.cache or null;
      importFolder = cfg.paths.import or null;

      # Localization
      region = cfg.localization.region or null;
      lang = cfg.localization.language or null;
      regionPrios = listToComma (cfg.localization.regionPriorities or null);
      langPrios = listToComma (cfg.localization.languagePriorities or null);

      # Output
      frontend = cfg.output.frontend or null;
      platform = cfg.output.platform or null;
      artworkXml = pathToStr (cfg.output.artworkXml or null);
      emulator = cfg.output.emulator or null;
      launch = cfg.output.launchCommand or null;

      # Game list
      gameListFilename = cfg.output.gameList.filename or null;
      gameListVariants = listToComma (cfg.output.gameList.variants or []);
      gameListBackup = cfg.output.gameList.backup or null;
      relativePaths = cfg.output.gameList.relativePaths or null;
      skipped = cfg.output.gameList.includeSkipped or null;
      addFolders = cfg.output.gameList.includeFolders or null;
      mediaFolderHidden = cfg.output.gameList.hiddenMediaFolder or null;

      # Titles
      brackets = cfg.titles.keepBrackets or null;
      theInFront = let
        pos = cfg.titles.articlePosition or null;
      in
        if pos != null
        then skyscraperTypes.articlePositionToBool pos
        else null;
      forceFilename = cfg.titles.forceFilename or null;
      nameTemplate = cfg.titles.template or null;
      keepDiscInfo = cfg.titles.keepDiscInfo or null;
      ignoreYearInFilename = cfg.titles.ignoreYearMismatch or null;
      innerBracketsReplace = cfg.titles.bracketSeparator or null;
      innerParenthesesReplace = cfg.titles.parenthesisSeparator or null;

      # Media
      videos = cfg.media.videos.enable or null;
      videoSizeLimit = cfg.media.videos.maxSize or null;
      symlink = cfg.media.videos.symlink or null;
      videoPreferNormalized = cfg.media.videos.preferNormalized or null;
      videoConvertCommand = cfg.media.videos.convert.command or null;
      videoConvertExtension = cfg.media.videos.convert.extension or null;
      manuals = cfg.media.manuals or null;
      backcovers = cfg.media.backcovers or null;
      fanarts = cfg.media.fanart or null;
      cropBlack = cfg.media.cropBlackBorders or null;

      # Cache
      cacheCovers = cfg.cache.covers or null;
      cacheScreenshots = cfg.cache.screenshots or null;
      cacheWheels = cfg.cache.wheels or null;
      cacheMarquees = cfg.cache.marquees or null;
      cacheTextures = cfg.cache.textures or null;
      cacheResize = cfg.cache.resize or null;
      cacheRefresh = cfg.cache.forceRefresh or null;
      jpgQuality = cfg.cache.jpegQuality or null;

      # Matching
      minMatch = cfg.matching.minPercent or null;
      maxLength = cfg.matching.maxDescriptionLength or null;
      tidyDesc = cfg.matching.tidyDescriptions or null;
      unpack = cfg.matching.unpackArchives or null;
      searchStem = cfg.matching.searchByStem or null;

      # Filter
      subdirs = cfg.filter.includeSubdirs or null;
      onlyMissing = cfg.filter.onlyMissing or null;
      excludePattern = cfg.filter.excludePattern or null;
      includePattern = cfg.filter.includePattern or null;
      excludeFrom = cfg.filter.excludeFile or null;
      includeFrom = cfg.filter.includeFile or null;
      startAt = cfg.filter.startAt or null;
      endAt = cfg.filter.endAt or null;

      # Extensions
      extensions = extensionsToStr (cfg.extensions.set or null);
      addExtensions = extensionsToStr (cfg.extensions.add or []);

      # Runtime
      verbosity = let
        v = cfg.runtime.verbosity or null;
      in
        if v != null
        then skyscraperTypes.verbosityToInt v
        else null;
      threads = cfg.runtime.threads or null;
      pretend = cfg.runtime.pretend or null;
      interactive = cfg.runtime.interactive or null;
      hints = cfg.runtime.hints or null;
      spaceCheck = cfg.runtime.spaceCheck or null;
      maxFails = cfg.runtime.maxConsecutiveFails or null;
      unattend = cfg.runtime.unattended.enable or null;
      unattendSkip = cfg.runtime.unattended.skipExisting or null;

      # Misc
      scummIni = cfg.scummIni or null;
    };

  # ── Platform Settings Conversion ───────────────────────────────────

  platformSettingsToIni = cfg:
    filterNulls {
      # Paths (no auto-append for platforms)
      inputFolder = cfg.paths.roms or null;
      gameListFolder = cfg.paths.gameLists or null;
      mediaFolder = cfg.paths.media or null;
      cacheFolder = cfg.paths.cache or null;
      importFolder = cfg.paths.import or null;

      # Localization
      region = cfg.localization.region or null;
      lang = cfg.localization.language or null;
      regionPrios = listToComma (cfg.localization.regionPriorities or null);
      langPrios = listToComma (cfg.localization.languagePriorities or null);

      # Output
      artworkXml = pathToStr (cfg.output.artworkXml or null);
      emulator = cfg.output.emulator or null;
      launch = cfg.output.launchCommand or null;
      relativePaths = cfg.output.gameList.relativePaths or null;
      skipped = cfg.output.gameList.includeSkipped or null;

      # Titles
      brackets = cfg.titles.keepBrackets or null;
      theInFront = let
        pos = cfg.titles.articlePosition or null;
      in
        if pos != null
        then skyscraperTypes.articlePositionToBool pos
        else null;
      forceFilename = cfg.titles.forceFilename or null;
      nameTemplate = cfg.titles.template or null;
      keepDiscInfo = cfg.titles.keepDiscInfo or null;
      ignoreYearInFilename = cfg.titles.ignoreYearMismatch or null;
      innerBracketsReplace = cfg.titles.bracketSeparator or null;
      innerParenthesesReplace = cfg.titles.parenthesisSeparator or null;

      # Media
      videos = cfg.media.videos.enable or null;
      videoSizeLimit = cfg.media.videos.maxSize or null;
      symlink = cfg.media.videos.symlink or null;
      videoConvertCommand = cfg.media.videos.convert.command or null;
      videoConvertExtension = cfg.media.videos.convert.extension or null;
      manuals = cfg.media.manuals or null;
      cropBlack = cfg.media.cropBlackBorders or null;

      # Cache
      cacheCovers = cfg.cache.covers or null;
      cacheScreenshots = cfg.cache.screenshots or null;
      cacheWheels = cfg.cache.wheels or null;
      cacheMarquees = cfg.cache.marquees or null;
      cacheTextures = cfg.cache.textures or null;
      cacheResize = cfg.cache.resize or null;
      jpgQuality = cfg.cache.jpegQuality or null;

      # Matching
      minMatch = cfg.matching.minPercent or null;
      maxLength = cfg.matching.maxDescriptionLength or null;
      tidyDesc = cfg.matching.tidyDescriptions or null;
      unpack = cfg.matching.unpackArchives or null;
      searchStem = cfg.matching.searchByStem or null;

      # Filter
      subdirs = cfg.filter.includeSubdirs or null;
      onlyMissing = cfg.filter.onlyMissing or null;
      excludePattern = cfg.filter.excludePattern or null;
      includePattern = cfg.filter.includePattern or null;
      excludeFrom = cfg.filter.excludeFile or null;
      includeFrom = cfg.filter.includeFile or null;
      startAt = cfg.filter.startAt or null;
      endAt = cfg.filter.endAt or null;

      # Extensions
      extensions = extensionsToStr (cfg.extensions.set or null);
      addExtensions = extensionsToStr (cfg.extensions.add or []);

      # Runtime
      verbosity = let
        v = cfg.runtime.verbosity or null;
      in
        if v != null
        then skyscraperTypes.verbosityToInt v
        else null;
      threads = cfg.runtime.threads or null;
      pretend = cfg.runtime.pretend or null;
      interactive = cfg.runtime.interactive or null;
      unattend = cfg.runtime.unattended.enable or null;
      unattendSkip = cfg.runtime.unattended.skipExisting or null;

      # Platform-only
      gameBaseFile = cfg.gameBaseFile or null;
    };

  # ── Frontend Settings Conversion ───────────────────────────────────

  frontendSettingsToIni = cfg:
    filterNulls {
      # Paths
      inputFolder = cfg.paths.roms or null;
      gameListFolder = cfg.paths.gameLists or null;
      mediaFolder = cfg.paths.media or null;

      # Output
      artworkXml = pathToStr (cfg.output.artworkXml or null);
      emulator = cfg.output.emulator or null;
      launch = cfg.output.launchCommand or null;
      gameListFilename = cfg.output.gameList.filename or null;
      gameListVariants = listToComma (cfg.output.gameList.variants or []);
      gameListBackup = cfg.output.gameList.backup or null;
      relativePaths = cfg.output.gameList.relativePaths or null;
      skipped = cfg.output.gameList.includeSkipped or null;
      addFolders = cfg.output.gameList.includeFolders or null;
      mediaFolderHidden = cfg.output.gameList.hiddenMediaFolder or null;

      # Titles
      brackets = cfg.titles.keepBrackets or null;
      theInFront = let
        pos = cfg.titles.articlePosition or null;
      in
        if pos != null
        then skyscraperTypes.articlePositionToBool pos
        else null;
      forceFilename = cfg.titles.forceFilename or null;

      # Media
      videos = cfg.media.videos.enable or null;
      symlink = cfg.media.videos.symlink or null;
      cropBlack = cfg.media.cropBlackBorders or null;

      # Matching
      maxLength = cfg.matching.maxDescriptionLength or null;

      # Filter
      excludePattern = cfg.filter.excludePattern or null;
      includePattern = cfg.filter.includePattern or null;
      startAt = cfg.filter.startAt or null;
      endAt = cfg.filter.endAt or null;

      # Runtime
      verbosity = let
        v = cfg.runtime.verbosity or null;
      in
        if v != null
        then skyscraperTypes.verbosityToInt v
        else null;
      unattend = cfg.runtime.unattended.enable or null;
      unattendSkip = cfg.runtime.unattended.skipExisting or null;
    };

  # ── Scraper Settings Conversion ────────────────────────────────────

  # Returns { attrs = { ... }; secretFile = path | null; }
  scraperSettingsToIni = name: cfg: let
    creds = cfg.credentials or {};
    hasFileSecret = (creds.file or null) != null;
  in {
    attrs = filterNulls {
      # Credentials (text or placeholder)
      userCreds = skyscraperTypes.credentialsToTemplate name creds;

      # Media
      videos = cfg.media.videos.enable or null;
      videoSizeLimit = cfg.media.videos.maxSize or null;
      videoConvertCommand = cfg.media.videos.convert.command or null;
      videoConvertExtension = cfg.media.videos.convert.extension or null;
      videoPreferNormalized = cfg.media.videos.preferNormalized or null;

      # Cache
      cacheCovers = cfg.cache.covers or null;
      cacheScreenshots = cfg.cache.screenshots or null;
      cacheWheels = cfg.cache.wheels or null;
      cacheMarquees = cfg.cache.marquees or null;
      cacheTextures = cfg.cache.textures or null;
      cacheResize = cfg.cache.resize or null;
      cacheRefresh = cfg.cache.forceRefresh or null;
      jpgQuality = cfg.cache.jpegQuality or null;

      # Matching
      minMatch = cfg.matching.minPercent or null;
      maxLength = cfg.matching.maxDescriptionLength or null;
      tidyDesc = cfg.matching.tidyDescriptions or null;

      # Filter
      onlyMissing = cfg.filter.onlyMissing or null;

      # Runtime
      threads = cfg.runtime.threads or null;
      interactive = cfg.runtime.interactive or null;
      unattend = cfg.runtime.unattended.enable or null;
      unattendSkip = cfg.runtime.unattended.skipExisting or null;
    };

    secret =
      if hasFileSecret
      then {
        placeholder = "@${lib.toUpper name}_CREDS@";
        inherit (creds) file;
      }
      else null;
  };
in {
  inherit
    mainSettingsToIni
    platformSettingsToIni
    frontendSettingsToIni
    scraperSettingsToIni
    filterNulls
    ;
}
