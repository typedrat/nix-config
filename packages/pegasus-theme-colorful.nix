{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  unzip,
  nix-update-script,
}:
stdenvNoCC.mkDerivation {
  pname = "pegasus-theme-colorful";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "RobZombie9043";
    repo = "COLORFUL";
    rev = "5afca291bbf82cb63cc07bd1d8ad052d547c8903";
    hash = "sha256-M4SOCDoSlGwIEI1Wy+1GNgv2r9mHs9xKxfoc2j3M1Yo=";
  };

  videos = fetchurl {
    url = "https://github.com/RobZombie9043/COLORFUL/releases/download/v0.2.0/videos.zip";
    hash = "sha256-zAdcs592GnavLudysvuOLR32WYQVVViEK244Q14OVKA=";
  };

  nativeBuildInputs = [unzip];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/pegasus-frontend/themes/colorful
    cp -r . $out/share/pegasus-frontend/themes/colorful
    unzip $videos -d $out/share/pegasus-frontend/themes/colorful

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {};

  meta = {
    description = "A port of the COLORFUL bigbox theme to Pegasus";
    homepage = "https://github.com/RobZombie9043/COLORFUL";
    platforms = lib.platforms.all;
  };
}
