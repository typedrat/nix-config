{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  ninja,
  glslang,
  pkg-config,
  python3,
  qt6,
  kdePackages,
  wrapGAppsHook3,
  boost,
  cpp-jwt,
  cubeb,
  eden,
  enet,
  ffmpeg-headless,
  fmt,
  frozen-containers,
  gamemode,
  httplib,
  libopus,
  libusb1,
  lz4,
  nlohmann_json,
  oaknut,
  openssl,
  pipewire,
  sdl3,
  simpleini,
  sirit,
  spirv-headers,
  vulkan-headers,
  vulkan-loader,
  vulkan-memory-allocator,
  vulkan-utility-libraries,
  xbyak,
  xxhash,
  zlib,
  nix-update-script,
}: let
  # Sources the build only reads headers or a few files from. CPMUtil would
  # download them at configure time; *_CUSTOM_DIR points it at these instead.
  zbic = fetchFromGitHub {
    owner = "kinnay";
    repo = "zbic";
    rev = "11b08f2712264bbed731545085cbd9702096ceb7";
    hash = "sha256-pHvxa1gkUvQo6mUgmLWtj1kcu01BLdGmttZyb8ZAj/o=";
  };

  # Upstream always builds this exact zstd so .nup archives compress
  # byte-identically on every platform; the system zstd is never used.
  zstd-pinned = fetchFromGitHub {
    owner = "facebook";
    repo = "zstd";
    rev = "33618c89e511637f8a6ef955b3501766d71feb53";
    hash = "sha256-UP99PUq8N+fmU972Jxim4f9u//T+4hRW+wuTZzWg3uI=";
  };

  reshade = fetchFromGitHub {
    owner = "crosire";
    repo = "reshade";
    tag = "v6.8.0";
    hash = "sha256-K6QC7CLqy8M318n9WbuqGvcRF9g9abvDD/xbr7T+nXo=";
  };

  # Prebuilt static library for the .nx converter in the Qt frontend; upstream
  # only offers it as release binaries. Without it the converter is left out.
  nxformat = stdenv.mkDerivation (finalAttrs: {
    pname = "nxformat-bin";
    version = "1.0.3";
    src = fetchurl {
      url = "https://github.com/fab918/nxformat/releases/download/V${finalAttrs.version}/nxformat-${finalAttrs.version}-linux-x64.tar.gz";
      hash = "sha256-0FjBtaZzLzA/BuhAkOfYyWfiWkcEobNf9cvgaAb2hXs=";
    };
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r include lib $out/
    '';
  });

  bundledSource = name: dir: [
    (lib.cmakeBool "${name}_FORCE_BUNDLED" true)
    (lib.cmakeFeature "${name}_CUSTOM_DIR" "${dir}")
  ];
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "lichii";
    version = "386";

    src = fetchFromGitHub {
      owner = "zortos293";
      repo = "Lichii";
      tag = "build-${finalAttrs.version}";
      hash = "sha256-3RCdoAIFYC1du3KpK3tLm0LOZQg1OJLI0SCizKOCrLY=";
    };

    strictDeps = true;
    __structuredAttrs = true;

    nativeBuildInputs = [
      cmake
      ninja
      glslang
      pkg-config
      python3
      qt6.qttools
      qt6.wrapQtAppsHook
      wrapGAppsHook3
    ];

    buildInputs =
      [
        boost
        cpp-jwt
        cubeb
        enet
        ffmpeg-headless
        fmt
        frozen-containers
        gamemode
        httplib
        kdePackages.quazip
        libopus
        libusb1
        lz4
        nlohmann_json
        openssl
        qt6.qtbase
        qt6.qtmultimedia
        qt6.qtwayland
        qt6.qtwebengine
        sdl3
        simpleini
        sirit
        spirv-headers
        vulkan-headers
        vulkan-memory-allocator
        vulkan-utility-libraries
        zlib
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [xbyak]
      ++ lib.optionals stdenv.hostPlatform.isAarch64 [oaknut];

    cmakeFlags =
      [
        (lib.cmakeBool "CPMUTIL_FORCE_SYSTEM" true)
        (lib.cmakeBool "BUILD_TESTING" false)
        (lib.cmakeBool "LICHII_TESTS" false)
        (lib.cmakeBool "ENABLE_WERROR" false)

        (lib.cmakeFeature "LICHII_TZDB_PATH" "${eden.nx_tzdb}")
        (lib.cmakeFeature "LICHII_NXFORMAT_ROOT" "${nxformat}")
        (lib.cmakeFeature "LICHII_BUILD_TAG" finalAttrs.src.tag)

        (lib.cmakeBool "LICHII_USE_QT_WEB_ENGINE" true)
        (lib.cmakeBool "LICHII_USE_QT_MULTIMEDIA" true)
        (lib.cmakeBool "ENABLE_QT_TRANSLATION" true)
        (lib.cmakeBool "LICHII_INSTALL_UDEV_RULES" true)
      ]
      ++ [(lib.cmakeFeature "zstd_CUSTOM_DIR" "${zstd-pinned}")]
      ++ bundledSource "zbic" zbic
      ++ bundledSource "xxhash" xxhash.src
      ++ bundledSource "reshade" reshade;

    preFixup = ''
      qtWrapperArgs+=(--prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          vulkan-loader
          pipewire
        ]
      })
    '';

    passthru.updateScript = nix-update-script {
      extraArgs = ["--version-regex" "build-(.*)"];
    };

    meta = {
      description = "Experimental Nintendo Switch and Switch 2 emulator forked from Eglantine and Eden";
      homepage = "https://github.com/zortos293/Lichii";
      license = with lib.licenses; [gpl3Plus gpl2Plus mit];
      sourceProvenance = with lib.sourceTypes; [fromSource binaryNativeCode];
      mainProgram = "lichii";
      platforms = ["x86_64-linux"];
    };
  })
