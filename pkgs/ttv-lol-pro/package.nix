{
  inputs',
  lib,
}: let
  fileId = "4638568";
in
  inputs'.firefox-addons.lib.buildFirefoxXpiAddon rec {
    pname = "ttv_lol_pro";
    version = "2.6.1";
    addonId = "{76ef94a4-e3d0-4c6f-961a-d38a429a332b}";
    url = "https://addons.mozilla.org/firefox/downloads/file/${fileId}/${pname}-${version}.xpi";
    sha256 = "sha256-gutff9ZQZxnoYZe5c95ypfTo76s6t+sS6CMxfkxU+vM=";

    passthru.updateScript = ./update.sh;

    meta = {
      description = "TTV LOL PRO removes most livestream ads from Twitch.";
      license = lib.licenses.gpl3;
      mozPermissions = [
        "proxy"
        "storage"
        "webRequest"
        "webRequestBlocking"
        "https://*.live-video.net/*"
        "https://*.ttvnw.net/*"
        "https://*.twitch.tv/*"
        "https://perfprod.com/ttvlolpro/telemetry"
      ];
    };
  }
