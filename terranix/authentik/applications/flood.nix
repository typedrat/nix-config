{
  authentik.applications.flood = {
    name = "Flood";
    group = "Torrents";
    icon = "https://raw.githubusercontent.com/jesec/flood/master/flood.svg";
    description = "A modern web UI for various torrent clients.";
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://flood.thisratis.gay";
    };
  };
}
