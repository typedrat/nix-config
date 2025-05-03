{
  authentik.applications.qbittorrent = {
    name = "qBittorrent";
    group = "Torrents";
    icon = "https://github.com/loganmarchione/homelab-svg-assets/raw/refs/heads/main/assets/qbittorrent.svg";
    description = "An advanced BitTorrent client programmed in C++, based on the Qt toolkit and libtorrent-rasterbar.";
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://qbittorrent.thisratis.gay";
    };
  };
}
