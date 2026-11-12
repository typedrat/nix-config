{
  lib,
  stdenvNoCC,
  fetchurl,
  nix-update-script,
}: let
  version = "6.5.5";
in
  stdenvNoCC.mkDerivation {
    pname = "hekate-payload";
    inherit version;

    src = fetchurl {
      url = "https://github.com/CTCaer/hekate/releases/download/v${version}/hekate_ctcaer_${version}.bin";
      hash = "sha256-CXUqvSB4A3CK3W4iFR6Utx/7qv92nRutdZWEt2728F4=";
    };

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm644 $src $out/share/hekate/hekate_ctcaer.bin

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    meta = {
      description = "hekate (CTCaer) RCM bootloader payload for Nintendo Switch";
      homepage = "https://github.com/CTCaer/hekate";
      changelog = "https://github.com/CTCaer/hekate/releases/tag/v${version}";
      license = lib.licenses.gpl2Only;
      sourceProvenance = with lib.sourceTypes; [binaryFirmware];
      platforms = lib.platforms.all;
    };
  }
