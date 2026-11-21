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
  version = "1.36.0";

  sources = {
    x86_64-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_x86_64.tar.gz";
      hash = "sha256-cPzeJCnlR0XLbpV6pGxnufehVsgY1cSgVAAY0h1Tbqc=";
    };
    aarch64-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_arm64.tar.gz";
      hash = "sha256-Y0GVM4HD1xwq/KByjLm3TlMY0zkoHd/IzHwP50Hu6oY=";
    };
    armv7l-linux = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_linux_arm.tar.gz";
      hash = "sha256-U9q2zO/X/iUm6o3c3jatTm7rUYA4CH+J52KZIYd6lL0=";
    };
    aarch64-darwin = fetchurl {
      url = "https://github.com/autobrr/qui/releases/download/v${version}/qui_${version}_darwin_arm64.tar.gz";
      hash = "sha256-G8PyJ2IV9+VMtnJdHfAAoHUQNy1KiAKQeofL1N8n8/o=";
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
