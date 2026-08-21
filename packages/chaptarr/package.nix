{
  lib,
  stdenvNoCC,
  dockerTools,
  autoPatchelfHook,
  makeWrapper,
  icu,
  openssl,
  zlib,
  curl,
  libmediainfo,
  sqlite,
  dotnetCorePackages,
  stdenv,
  writeShellApplication,
  skopeo,
  nix-prefetch-docker,
  jq,
  gnused,
  gnugrep,
  coreutils,
}: let
  arch =
    {
      x86_64-linux = "amd64";
      aarch64-linux = "arm64";
    }
    .${
      stdenv.hostPlatform.system
    } or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  hash =
    {
      amd64 = "sha256-JBD8vnw+aW7X6sWaId2NiU5Cc7twpUIT2MEMjXesNiw=";
      arm64 = "sha256-qqsmlsjKOqsgcDxDnnkqsBo6CRPTITWOUzitYbWTBl4=";
    }
    .${
      arch
    };
in
  stdenvNoCC.mkDerivation rec {
    pname = "chaptarr";
    version = "0.9.929";

    src = dockerTools.pullImage {
      imageName = "robertlordhood/chaptarr";
      imageDigest = "sha256:2f5409fad4b02386fdd57169d93f7533342eafd036357a2c2b7256df19cda7eb";
      inherit hash;
      finalImageTag = version;
      os = "linux";
      inherit arch;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = [
      icu
      openssl
      zlib
      curl
      libmediainfo
      sqlite
      stdenv.cc.cc.lib # libstdc++
    ];

    unpackPhase = ''
      runHook preUnpack

      mkdir -p image
      tar xf "$src" -C image

      # Extract all layers into a merged root
      mkdir -p root
      for layer in image/*.tar.gz; do
        tar xzf "$layer" -C root 2>/dev/null || true
      done
      # Handle uncompressed tar layers too
      for layer in image/*/layer.tar; do
        tar xf "$layer" -C root 2>/dev/null || true
      done

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/{bin,share/${pname}}
      cp -r root/app/* $out/share/${pname}/

      # Remove PDB debug files to save space
      find $out/share/${pname} -name '*.pdb' -delete

      makeWrapper $out/share/${pname}/Chaptarr $out/bin/Chaptarr \
        --set DOTNET_ROOT "${dotnetCorePackages.aspnetcore_10_0}/share/dotnet" \
        --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          curl
          sqlite
          libmediainfo
          icu
          openssl
          zlib
        ]
      }

      runHook postInstall
    '';

    passthru.updateScript = lib.getExe (writeShellApplication {
      name = "chaptarr-update";
      runtimeInputs = [
        curl
        jq
        skopeo
        nix-prefetch-docker
        gnused
        gnugrep
        coreutils
      ];
      text = builtins.readFile ./update.sh;
    });

    meta = {
      description = "Audiobook and E-book fork of the now retired Readarr";
      homepage = "https://github.com/robertlordhood/Chaptarr";
      license = lib.licenses.gpl3;
      mainProgram = "Chaptarr";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  }
