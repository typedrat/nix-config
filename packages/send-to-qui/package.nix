{
  inputs,
  stdenv,
  lib,
}:
(inputs.firefox-addons.lib.${stdenv.hostPlatform.system}.buildFirefoxXpiAddon rec {
  pname = "send-to-qui";
  version = "1.0.0";
  addonId = "send-to-qui@typedr.at";
  # The Mozilla-signed build from the GitHub release; the flake's own package is unsigned.
  url = "https://github.com/typedrat/send-to-qui-firefox/releases/download/v${version}/send-to-qui-${version}.xpi";
  sha256 = "sha256-l0+8Z+XmLxanFjZzpxgrkmR1UaLPRrv3cJJqDyvptRM=";

  meta = {
    homepage = "https://github.com/typedrat/send-to-qui-firefox";
    description = "Send .torrent files and magnet links to qui";
    license = lib.licenses.gpl2Plus;
    mozPermissions = [
      "menus"
      "downloads"
      "notifications"
      "storage"
      "nativeMessaging"
      "<all_urls>"
    ];
    platforms = lib.platforms.all;
  };
}).overrideAttrs (old: {
  passthru =
    old.passthru
    // {
      updateScript = ./update.sh;
    };
})
