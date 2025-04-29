{links, ...}: {
  resource = {
    sonarr_download_client_flood = {
      sonarr = {
        enable = true;
        priority = 1;
        name = "Flood";
        host = "localhost";
        port = links.flood.port;
        destination = "/mnt/media/torrents/tv-shows";
        field_tags = ["sonarr"];
        post_import_tags = ["imported"];
      };
      "sonarr-anime" = {
        provider = "sonarr.anime";
        enable = true;
        priority = 1;
        name = "Flood";
        host = "localhost";
        port = links.flood.port;
        destination = "/mnt/media/torrents/anime";
        field_tags = ["sonarr-anime"];
        post_import_tags = ["imported"];
      };
    };

    prowlarr_application_sonarr = {
      sonarr = {
        name = "Sonarr";
        api_key = "\${ data.sops_file.arrs.data[\"sonarr.apiKey\"] }";
        base_url = links.sonarr.url;
        prowlarr_url = links.prowlarr.url;
        sync_level = "fullSync";
        tags = ["\${ prowlarr_tag.western.id }"];
      };
      "sonarr-anime" = {
        name = "Sonarr (Anime)";
        api_key = "\${ data.sops_file.arrs.data[\"sonarr-anime.apiKey\"] }";
        base_url = links.sonarr-anime.url;
        prowlarr_url = links.prowlarr.url;
        sync_level = "fullSync";
        tags = ["\${ prowlarr_tag.anime.id }"];
      };
    };

    sonarr_root_folder = {
      sonarr = {
        path = "/mnt/media/tv-shows";
      };
      "sonarr-anime" = {
        provider = "sonarr.anime";
        path = "/mnt/media/anime";
      };
    };

    sonarr_naming = {
      sonarr = {
        rename_episodes = true;
        replace_illegal_characters = true;
        colon_replacement_format = 4; # smart
        multi_episode_style = 5; # prefixed range
        series_folder_format = "{Series Title}";
        season_folder_format = "Season {season:00}";
        specials_folder_format = "Specials";
        standard_episode_format = "{Series TitleYear} - S{season:00}E{episode:00} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}";
        daily_episode_format = "{Series TitleYear} - {Air-Date} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}";
        anime_episode_format = "{Series TitleYear} - S{season:00}E{episode:00} - {absolute:000} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}[{MediaInfo VideoBitDepth}bit]{[MediaInfo VideoCodec]}[{Mediainfo AudioCodec} { Mediainfo AudioChannels}]{MediaInfo AudioLanguages}{-Release Group}";
      };
      "sonarr-anime" = {
        provider = "sonarr.anime";
        rename_episodes = true;
        replace_illegal_characters = true;
        colon_replacement_format = 4; # smart
        multi_episode_style = 5; # prefixed range
        series_folder_format = "{Series Title}";
        season_folder_format = "Season {season:00}";
        specials_folder_format = "Specials";
        standard_episode_format = "{Series TitleYear} - S{season:00}E{episode:00} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}";
        daily_episode_format = "{Series TitleYear} - {Air-Date} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}";
        anime_episode_format = "{Series TitleYear} - S{season:00}E{episode:00} - {absolute:000} - {Episode CleanTitle} [{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}[{MediaInfo VideoBitDepth}bit]{[MediaInfo VideoCodec]}[{Mediainfo AudioCodec} { Mediainfo AudioChannels}]{MediaInfo AudioLanguages}{-Release Group}";
      };
    };
  };
}
