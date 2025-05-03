{
  authentik.applications.lidarr = {
    name = "Lidarr";
    group = "Torrents";
    icon = "https://raw.githubusercontent.com/Lidarr/Lidarr/refs/heads/develop/Logo/Lidarr.svg";
    description = "Lidarr is a music collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new albums from your favorite artists and will interface with clients and indexers to grab, sort, and rename them. It can also be configured to automatically upgrade the quality of existing files in the library when a better quality format becomes available.";
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://lidarr.thisratis.gay";
    };
  };
}
