{
  authentik.applications.prowlarr = {
    name = "Prowlarr";
    group = "Torrents";
    icon = "https://raw.githubusercontent.com/Prowlarr/Prowlarr/refs/heads/develop/Logo/Prowlarr.svg";
    description = "Indexer manager/proxy to integrate with various PVR apps.";
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://prowlarr.thisratis.gay";
    };
  };
}
