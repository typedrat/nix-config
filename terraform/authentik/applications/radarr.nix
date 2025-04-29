{
  authentik.applications = {
    radarr = {
      name = "Radarr";
      group = "Torrents";
      icon = "https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg";
      description = "Movie organizer/manager for usenet and torrent users.";
      accessGroups = ["discord-sysop"];

      proxy = {
        externalHost = "https://radarr.thisratis.gay";
      };
    };

    "radarr-anime" = {
      name = "Radarr (Anime)";
      group = "Torrents";
      icon = "https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg";
      description = "Movie organizer/manager for usenet and torrent users.";
      accessGroups = ["discord-sysop"];

      proxy = {
        externalHost = "https://radarr-anime.thisratis.gay";
      };
    };
  };
}
