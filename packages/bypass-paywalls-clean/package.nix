{
  inputs,
  stdenv,
  lib,
}:
(inputs.firefox-addons.lib.${stdenv.hostPlatform.system}.buildFirefoxXpiAddon {
  pname = "bypass-paywalls-clean";
  version = "4.3.2.2";
  addonId = "magnolia@12.34";
  url = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-4.3.2.2.xpi";
  sha256 = "sha256-7Z7jC9N7HWFLG+4iGzubG5RGkBcKMDC5jopBPz5m4xc=";

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
