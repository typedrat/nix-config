{links, ...}: {
  resource = {
    lidarr_download_client_qbittorrent.lidarr = {
      name = "qBittorrent";
      enable = true;
      priority = 1;

      host = links.qbittorrent-webui.hostname;
      port = links.qbittorrent-webui.port;

      music_category = "lidarr";
      music_imported_category = "lidarr-imported";
      remove_completed_downloads = false;
      remove_failed_downloads = true;
    };

    prowlarr_application_lidarr.lidarr = {
      name = "Lidarr";
      api_key = "\${ data.sops_file.arrs.data[\"lidarr.apiKey\"] }";
      base_url = links.lidarr.url;
      prowlarr_url = links.prowlarr.url;
      sync_categories = [
        3000 # Audio
        3010 # Audio/MP3
        3030 # Audio/Audiobook
        3040 # Audio/Lossless
        3050 # Audio/Other
        3060 # Audio/Foreign
      ];
      sync_level = "fullSync";
    };
  };
}
