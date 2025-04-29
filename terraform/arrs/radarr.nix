{links, ...}: {
  resource = {
    radarr_download_client_flood = {
      radarr = {
        enable = true;
        priority = 1;
        name = "Flood";
        host = "localhost";
        port = links.flood.port;
        destination = "/mnt/media/torrents/movies";
        field_tags = ["radarr"];
        post_import_tags = ["imported"];
      };
      "radarr-anime" = {
        provider = "radarr.anime";
        enable = true;
        priority = 1;
        name = "Flood";
        host = "localhost";
        port = links.flood.port;
        destination = "/mnt/media/torrents/anime-movies";
        field_tags = ["radarr-anime"];
        post_import_tags = ["imported"];
      };
    };

    prowlarr_application_radarr = {
      radarr = {
        name = "Radarr";
        api_key = "\${ data.sops_file.arrs.data[\"radarr.apiKey\"] }";
        base_url = links.radarr.url;
        prowlarr_url = links.prowlarr.url;
        sync_categories = [
          2000 # Movies
          2010 # Movies/Foreign
          2020 # Movies/Other
          2030 # Movies/SD
          2040 # Movies/HD
          2045 # Movies/UHD
          2050 # Movies/BluRay
          2060 # Movies/3D
          2070 # Movies/DVD
          2080 # Movies/WEB-DL
          2090 # Movies/x265
        ];
        sync_level = "fullSync";
        tags = ["\${ prowlarr_tag.western.id }"];
      };
      "radarr-anime" = {
        name = "Radarr (Anime)";
        api_key = "\${ data.sops_file.arrs.data[\"radarr-anime.apiKey\"] }";
        base_url = links.radarr-anime.url;
        prowlarr_url = links.prowlarr.url;
        sync_categories = [
          2000 # Movies
          2010 # Movies/Foreign
          2020 # Movies/Other
          2030 # Movies/SD
          2040 # Movies/HD
          2045 # Movies/UHD
          2050 # Movies/BluRay
          2060 # Movies/3D
          2070 # Movies/DVD
          2080 # Movies/WEB-DL
          2090 # Movies/x265
          5070 # Anime
        ];
        sync_level = "fullSync";
        tags = ["\${ prowlarr_tag.anime.id }"];
      };
    };

    radarr_root_folder = {
      radarr = {
        path = "/mnt/media/movies";
      };
      "radarr-anime" = {
        provider = "radarr.anime";
        path = "/mnt/media/anime-movies";
      };
    };

    radarr_naming = {
      radarr = {
        rename_movies = true;
        replace_illegal_characters = true;
        colon_replacement_format = "smart";
        movie_folder_format = "{Movie CleanTitle} ({Release Year})";
        standard_movie_format = "{Movie CleanTitle} {(Release Year)} [imdbid-{ImdbId}] - {Edition Tags }{[Custom Formats]}{[Quality Full]}{[MediaInfo 3D]}{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[Mediainfo VideoCodec]}{-Release Group}";
      };
      "radarr-anime" = {
        provider = "radarr.anime";
        rename_movies = true;
        replace_illegal_characters = true;
        colon_replacement_format = "smart";
        movie_folder_format = "{Movie CleanTitle} ({Release Year})";
        standard_movie_format = "{Movie CleanTitle} {(Release Year)} [imdbid-{ImdbId}] - {Edition Tags }{[Custom Formats]}{[Quality Full]}{[MediaInfo 3D]}{[MediaInfo VideoDynamicRangeType]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[Mediainfo VideoCodec]}{-Release Group}";
      };
    };
  };
}
