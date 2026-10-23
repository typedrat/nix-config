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
  #
  # Upstream also tags prereleases as vX.Y.Z-dev.N. buildHomeAssistantComponent's
  # position points into nixpkgs, so nix-update needs this file named.
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "^v([0-9]+\\.[0-9]+\\.[0-9]+)$"
      "--override-filename"
      "packages/spoolman-homeassistant/package.nix"
    ];
  };

  meta = {
    description = "Home Assistant integration for the Spoolman filament inventory";
    homepage = "https://github.com/Disane87/spoolman-homeassistant";
    license = lib.licenses.mit;
    maintainers = [];
  };
}
