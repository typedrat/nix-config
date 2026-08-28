{
  authentik.applications.spoolman = {
    name = "Spoolman";
    group = "Home";
    # Spoolman is not in homelab-svg-assets; this is its own icon, pinned to the
    # packaged tag so a rename upstream cannot silently break it.
    icon = "https://raw.githubusercontent.com/Donkie/Spoolman/v0.26.1/client/icons/spoolman.svg";
    description = "Filament spool inventory";
    # The whole inventory is writable through the UI, so this is a control
    # surface rather than a dashboard.
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://spoolman.thisratis.gay";
    };
  };
}
