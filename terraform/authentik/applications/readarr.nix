{
  authentik.applications.chaptarr = {
    name = "Chaptarr";
    group = "Media";
    icon = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/chaptarr.svg";
    description = "Audiobook and e-book organizer/manager for usenet and torrent users.";
    accessGroups = [ "discord-sysop" ];

    proxy = {
      externalHost = "https://chaptarr.thisratis.gay";
    };
  };
}
