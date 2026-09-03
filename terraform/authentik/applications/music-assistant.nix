{
  authentik.applications.music-assistant = {
    name = "Music Assistant";
    group = "Media";
    icon = "https://cdn.jsdelivr.net/gh/selfhst/icons@main/svg/music-assistant.svg";
    description = "Music library manager and multi-room player";
    # The UI is where streaming provider credentials are entered and where any
    # speaker in the house can be taken over, so it is a control surface.
    # Playback for everyone else goes through Home Assistant instead.
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://music.thisratis.gay";
    };
  };
}
