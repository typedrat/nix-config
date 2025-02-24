{
  programs.ncspot = {
    enable = true;
  };

  xdg.desktopEntries.ncspot = {
    name = "ncspot";
    icon = "spotify";
    exec = "ncspot";
    terminal = true;
    type = "Application";
    categories = ["AudioVideo" "Audio"];
  };
}
