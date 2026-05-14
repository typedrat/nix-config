{
  inputs,
  stdenv,
  lib,
}: let
  fileId = "4797584";
in
  (inputs.firefox-addons.lib.${stdenv.hostPlatform.system}.buildFirefoxXpiAddon rec {
    pname = "ttv_lol_pro";
    version = "2.6.2";
    addonId = "{76ef94a4-e3d0-4c6f-961a-d38a429a332b}";
    url = "https://addons.mozilla.org/firefox/downloads/file/${fileId}/${pname}-${version}.xpi";
    sha256 = "sha256-1eMt+1HOBQ/EIhctezru5KpLGOYPaHg7VW5b8053EP4=";

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
  }).overrideAttrs (old: {
    passthru =
      old.passthru
      // {
        updateScript = ./update.sh;
      };
  })
