{
  authentik.applications.printguard = {
    name = "PrintGuard";
    group = "Home";
    # PrintGuard is not in homelab-svg-assets; this is its own icon, pinned to
    # the packaged tag so a rename upstream cannot silently break it.
    icon = "https://raw.githubusercontent.com/oliverbravery/PrintGuard/v2.4.0/web/public/apple-touch-icon.png";
    description = "Real-time 3D print failure detection";
    # Pausing and cancelling prints is a control surface, not a dashboard.
    accessGroups = ["discord-sysop"];

    proxy = {
      externalHost = "https://printguard.thisratis.gay";
    };
  };
}
