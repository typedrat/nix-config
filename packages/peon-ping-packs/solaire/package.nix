{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation {
  pname = "peon-ping-pack-solaire";
  version = "0-unstable-2026-03-22";

  src = fetchFromGitHub {
    owner = "jmfiebak";
    repo = "openpeon-solaire-sound-pack";
    rev = "b4d81c1c6e84dc17038dd2949f3b1d55125e5101";
    hash = "sha256-75wcUb8U48fVyLgVCXSCN0Q3jZniEId3oiuRlxjQ0wo=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake" "--version=branch"];};

  meta = {
    description = "Solaire sound pack for peon-ping";
    homepage = "https://github.com/jmfiebak/openpeon-solaire-sound-pack";
    platforms = lib.platforms.all;
  };
}
