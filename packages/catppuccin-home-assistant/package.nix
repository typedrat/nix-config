{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  catppuccin-whiskers,
  nix-update-script,
}:
stdenvNoCC.mkDerivation rec {
  pname = "catppuccin-home-assistant";
  version = "2.1.3";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "home-assistant";
    tag = "v${version}";
    hash = "sha256-+m6lWer9a4AwmTgckhSHOKd0Oo6x9N0jjza4/F0ye3E=";
  };

  nativeBuildInputs = [catppuccin-whiskers];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    whiskers home-assistant.tera

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/home-assistant
    cp -r themes $out/share/home-assistant/themes

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Catppuccin theme for Home Assistant";
    homepage = "https://github.com/catppuccin/home-assistant";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
