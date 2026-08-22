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
  version = "1.26.0";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_x86_64.tar.gz";
      hash = "sha256-3UZyliBB1KIIrIjR6fiS1gamOOGzi1rVl/hCegBONr4=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_arm64.tar.gz";
      hash = "sha256-ot65JxQI/NAUX1tvZ8wJuHw3s6Zb+7l/E/kJXeKRfcA=";
    };
    armv7l-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_arm.tar.gz";
      hash = "sha256-KsllNXrQLdk7v2Om9X1LOcP1z+QYnobCQmlekxdW1JM=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_darwin_arm64.tar.gz";
      hash = "sha256-BsS/ZDNrxrSgiigq0CCkFaz9CL3OnwHwkQOrmaQ3WZs=";
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
