{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "krita-ai-diffusion";
  version = "1.47.0";

  src = fetchFromGitHub {
    owner = "Acly";
    repo = "krita-ai-diffusion";
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-OYcBxwNMg8ztf9aaO4kJFE1afLqMzTutGhMsViutIZM=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/krita/pykrita
    cp -r ai_diffusion $out/share/krita/pykrita/
    cp ai_diffusion.desktop $out/share/krita/pykrita/

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {};

  meta = {
    description = "Generative AI for Krita - image generation plugin using ComfyUI as backend";
    homepage = "https://github.com/Acly/krita-ai-diffusion";
    changelog = "https://github.com/Acly/krita-ai-diffusion/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
    maintainers = [];
  };
})
