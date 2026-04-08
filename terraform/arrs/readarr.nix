{links, ...}: {
  resource = {
    readarr_download_client_qbittorrent.readarr = {
      name = "qBittorrent";
      enable = true;
      priority = 1;

      host = links.qbittorrent-webui.hostname;
      inherit (links.qbittorrent-webui) port;

      book_category = "chaptarr";
      book_imported_category = "chaptarr-imported";
      remove_completed_downloads = false;
      remove_failed_downloads = true;
    };

    prowlarr_application_readarr.readarr = {
      name = "Chaptarr";
      api_key = "\${ data.sops_file.arrs.data[\"chaptarr.apiKey\"] }";
      base_url = links.chaptarr.url;
      prowlarr_url = links.prowlarr.url;
      sync_categories = [
        3030 # Audio/Audiobook
        7000 # Books
        7010 # Books/Mags
        7020 # Books/EBook
        7030 # Books/Comics
        7040 # Books/Technical
        7050 # Books/Other
        7060 # Books/Foreign
      ];
      sync_level = "fullSync";
    };
  };
}
