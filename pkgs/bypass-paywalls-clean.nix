{
  inputs',
  lib,
}:
inputs'.firefox-addons.lib.buildFirefoxXpiAddon rec {
  pname = "bypass-paywalls-clean";
  version = "4.2.9.6";
  addonId = "magnolia@12.34";
  url = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-${version}.xpi";
  sha256 = "sha256-Jf9wYjFVxEfAGXo7qMFG28gW4pipvNuOAvqJGXKBq4s=";
  meta = with lib; {
    homepage = "https://twitter.com/Magnolia1234B";
    description = "Bypass Paywalls of (custom) news sites";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
