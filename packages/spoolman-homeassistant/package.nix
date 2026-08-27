{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  nix-update-script,
}:
buildHomeAssistantComponent rec {
  owner = "Disane87";
  domain = "spoolman";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "Disane87";
    repo = "spoolman-homeassistant";
    tag = "v${version}";
    hash = "sha256-4pwsNUFAha0n55QJrrEw+sHmQRCijs41yl7VLORT1cw=";
  };

  # Upstream stamps the real version into the manifest only when it builds a
  # release archive, so Home Assistant reports this integration as 0.0.0.
  passthru.updateScript = nix-update-script {};

  meta = {
    description = "Home Assistant integration for the Spoolman filament inventory";
    homepage = "https://github.com/Disane87/spoolman-homeassistant";
    license = lib.licenses.mit;
    maintainers = [];
  };
}
