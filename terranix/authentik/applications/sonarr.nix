{
  authentik.applications = {
    sonarr = {
      name = "Sonarr";
      group = "Torrents";
      icon = "https://raw.githubusercontent.com/Sonarr/Sonarr/refs/heads/develop/Logo/Sonarr.svg";
      description = "Sonarr is an internet PVR for Usenet and Torrents.";
      accessGroups = ["discord-sysop"];

      proxy = {
        externalHost = "https://sonarr.thisratis.gay";
      };
    };

    "sonarr-anime" = {
      name = "Sonarr (Anime)";
      group = "Torrents";
      icon = "https://raw.githubusercontent.com/Sonarr/Sonarr/refs/heads/develop/Logo/Sonarr.svg";
      description = "Sonarr is an internet PVR for Usenet and Torrents.";
      accessGroups = ["discord-sysop"];

      proxy = {
        externalHost = "https://sonarr-anime.thisratis.gay";
      };
    };
  };
}
