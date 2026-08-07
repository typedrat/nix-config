{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  writeShellApplication,
  curl,
  jq,
  gawk,
  gnused,
  gnugrep,
  coreutils,
}: let
  version = "1.25.0";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_x86_64.tar.gz";
      hash = "sha256-kIEqJBYp8HrKKNFYppAMBJY3jJdLatMLkmlmvTADLeM=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_arm64.tar.gz";
      hash = "sha256-OKfoIo+GefHorCjssG662KXwqcyqBEh3nV1xWfvaRIQ=";
    };
    armv7l-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_arm.tar.gz";
      hash = "sha256-bPfDDGEOb1kyEs5/3RH5DMNgbE+KQALMHacrdocdzu0=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_darwin_arm64.tar.gz";
      hash = "sha256-LwKs20gZ37oqkkxun7ihGOOD1rdAeHxxgqD0gA11fXQ=";
    };
  };
in
  stdenvNoCC.mkDerivation {
    pname = "qui-bin";
    inherit version;

    src =
      sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

    sourceRoot = ".";

    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 qui $out/bin/qui

      runHook postInstall
    '';

    passthru.updateScript = lib.getExe (writeShellApplication {
      name = "qui-bin-update";
      runtimeInputs = [
        curl
        jq
        gawk
        gnused
        gnugrep
        coreutils
      ];
      text = builtins.readFile ./update.sh;
    });

    meta = {
      description = "Modern alternative webUI for qBittorrent, with multi-instance support (pre-built binary)";
      homepage = "https://github.com/autobrr/qui";
      changelog = "https://github.com/autobrr/qui/releases/tag/v${version}";
      license = lib.licenses.gpl2Plus;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "qui";
      platforms = builtins.attrNames sources;
    };
  }
