{
  inputs,
  stdenv,
  lib,
}:
(inputs.firefox-addons.lib.${stdenv.hostPlatform.system}.buildFirefoxXpiAddon {
  pname = "bypass-paywalls-clean";
  version = "4.4.2.2";
  addonId = "magnolia@12.34";
  url = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-4.4.2.2.xpi";
  sha256 = "sha256-UdHx4TRB5p6Z+uPyDZ+pPk5EOMAH6lJNwYxShHu2h8E=";

  meta = {
    homepage = "https://twitter.com/Magnolia1234B";
    description = "Bypass Paywalls of (custom) news sites";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}).overrideAttrs (old: {
  passthru =
    old.passthru
    // {
      updateScript = ./update.sh;
    };
})
