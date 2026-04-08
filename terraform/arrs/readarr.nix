{links, ...}: {
  resource = {
    readarr_download_client_qbittorrent = {
      "readarr" = {
        name = "qBittorrent";
        enable = true;
        priority = 1;

        host = links.qbittorrent-webui.hostname;
        inherit (links.qbittorrent-webui) port;

        book_category = "readarr";
        book_imported_category = "readarr-imported";
        remove_completed_downloads = false;
        remove_failed_downloads = true;
      };
      "readarr-audiobooks" = {
        provider = "readarr.audiobooks";
        name = "qBittorrent";
        enable = true;
        priority = 1;

        host = links.qbittorrent-webui.hostname;
        inherit (links.qbittorrent-webui) port;

        book_category = "readarr-audiobooks";
        book_imported_category = "readarr-audiobooks-imported";
        remove_completed_downloads = false;
        remove_failed_downloads = true;
      };
    };

    prowlarr_application_readarr = {
      readarr = {
        name = "Readarr";
        api_key = "\${ data.sops_file.arrs.data[\"readarr.apiKey\"] }";
        base_url = links.readarr.url;
        prowlarr_url = links.prowlarr.url;
        sync_categories = [
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
      "readarr-audiobooks" = {
        name = "Readarr (Audiobooks)";
        api_key = "\${ data.sops_file.arrs.data[\"readarr-audiobooks.apiKey\"] }";
        base_url = links.readarr-audiobooks.url;
        prowlarr_url = links.prowlarr.url;
        sync_categories = [
          3030 # Audio/Audiobook
        ];
        sync_level = "fullSync";
      };
    };

    readarr_root_folder = {
      readarr = {
        name = "Books";
        path = "/mnt/media/books";
        default_quality_profile_id = 1;
        default_metadata_profile_id = 1;
        default_monitor_option = "all";
        default_monitor_new_item_option = "all";
        is_calibre_library = false;
      };
      "readarr-audiobooks" = {
        provider = "readarr.audiobooks";
        name = "Audiobooks";
        path = "/mnt/media/audiobooks";
        default_quality_profile_id = 1;
        default_metadata_profile_id = 1;
        default_monitor_option = "all";
        default_monitor_new_item_option = "all";
        is_calibre_library = false;
      };
    };

    readarr_naming = {
      readarr = {
        rename_books = true;
        replace_illegal_characters = true;
        colon_replacement_format = 4; # smart
        author_folder_format = "{Author Name}";
        standard_book_format = "{Book Title} ({Release Year})/{Author Name} - {Book Title}{ (Release Year)}";
      };
      "readarr-audiobooks" = {
        provider = "readarr.audiobooks";
        rename_books = true;
        replace_illegal_characters = true;
        colon_replacement_format = 4; # smart
        author_folder_format = "{Author Name}";
        standard_book_format = "{Book Title} ({Release Year})/{Author Name} - {Book Title}{ (Release Year)}";
      };
    };
  };
}
