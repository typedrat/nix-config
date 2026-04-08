{
  authentik.applications = {
    readarr = {
      name = "Readarr";
      group = "Torrents";
      icon = "https://raw.githubusercontent.com/Readarr/Readarr/refs/heads/develop/Logo/Readarr.svg";
      description = "Book organizer/manager for usenet and torrent users.";
      accessGroups = ["discord-sysop"];

      proxy = {
        externalHost = "https://readarr.thisratis.gay";
      };
    };

    "readarr-audiobooks" = {
      name = "Readarr (Audiobooks)";
      group = "Torrents";
      icon = "https://raw.githubusercontent.com/Readarr/Readarr/refs/heads/develop/Logo/Readarr.svg";
      description = "Audiobook organizer/manager for usenet and torrent users.";
      accessGroups = ["discord-sysop"];

      proxy = {
        externalHost = "https://readarr-audiobooks.thisratis.gay";
      };
    };
  };
}
