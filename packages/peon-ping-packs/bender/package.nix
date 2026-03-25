{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation {
  pname = "peon-ping-pack-bender";
  version = "0-unstable-2025-07-27";

  src = fetchFromGitHub {
    owner = "ravenrs";
    repo = "peon-ping-futurama-bender-";
    rev = "2523d13c8562b7bea03f63217a635f152ee59df0";
    hash = "sha256-TnBHFbFUZb6Y6feGlLeL0i9o391SA9nyiHSTas4QLLs=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake" "--version=branch"];};

  meta = {
    description = "Futurama Bender sound pack for peon-ping";
    homepage = "https://github.com/ravenrs/peon-ping-futurama-bender-";
    platforms = lib.platforms.all;
  };
}
