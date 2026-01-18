{
  inputs,
  lib,
  stdenv,
}:
inputs.firefox-addons.lib.${stdenv.hostPlatform.system}.buildFirefoxXpiAddon rec {
  pname = "bypass-paywalls-clean";
  version = "4.2.8.7";
  addonId = "magnolia@12.34";
  url = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-${version}.xpi";
  sha256 = "sha256-9ON7dRylqQEdETbi7a0hKibtf6dBw8hROhQokdP2RBk=";
  meta = with lib; {
    homepage = "https://twitter.com/Magnolia1234B";
    description = "Bypass Paywalls of (custom) news sites";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
