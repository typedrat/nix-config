# Krita 5.3 (Qt5 build of the 6.0.1.1 codebase) with krita-vision-tools.
# "5.3" is Krita 6.x built with Qt5 instead of Qt6 - same source, different build flag.
# Pinned because krita-ai-diffusion does not support the Qt6 build yet.
# Includes krita-vision-tools v2.2.0 built in-tree (C++ plugin that links against Krita internals).
{
  mkDerivation,
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  fetchFromGitLab,
  cmake,
  extra-cmake-modules,
  karchive,
  kconfig,
  kwidgetsaddons,
  kcompletion,
  kcoreaddons,
  kguiaddons,
  ki18n,
  kitemmodels,
  kitemviews,
  kwindowsystem,
  kio,
  kcrash,
  breeze-icons,
  boost,
  libraw,
  fftw,
  eigen,
  exiv2,
  fribidi,
  libaom,
  libheif,
  lcms2,
  gsl,
  openexr,
  giflib,
  libjxl,
  mlt,
  openjpeg,
  opencolorio,
  xsimd, # nixpkgs has 13.x; Krita 6.0.x prefers 14 but accepts >=8.1.0
  poppler,
  curl,
  immer,
  lager,
  libmypaint,
  libunibreak,
  libwebp,
  qtmultimedia,
  qtx11extras,
  qtquickcontrols2,
  quazip,
  SDL2,
  zug,
  pkg-config,
  python3Packages,
  freetype,
  harfbuzz,
  fontconfig,
  # kseexpr build deps
  bison,
  flex,
  llvm,
  qtbase,
  wrapQtAppsHook,
  # Vulkan deps for krita-vision-tools (GGML Vulkan backend)
  vulkan-headers,
  vulkan-loader,
  shaderc,
}: let
  # kseexpr 4.x for Qt5 mode (nixpkgs unstable has 6.x for KF6)
  kseexpr = stdenv.mkDerivation {
    pname = "kseexpr";
    version = "4.0.4.0";
    src = fetchFromGitLab {
      domain = "invent.kde.org";
      owner = "graphics";
      repo = "kseexpr";
      rev = "v4.0.4.0";
      hash = "sha256-XjFGAN7kK2b0bLouYG3OhajhOQk4AgC4EQRzseccGCE=";
    };
    # Fix libdir in pkg-config file (NixOS/nixpkgs#144170)
    postPatch = ''
      substituteInPlace cmake/kseexpr.pc.in \
        --replace 'libdir=''${prefix}/@CMAKE_INSTALL_LIBDIR@' 'libdir=@CMAKE_INSTALL_FULL_LIBDIR@'
    '';
    nativeBuildInputs = [cmake extra-cmake-modules wrapQtAppsHook];
    buildInputs = [bison flex ki18n llvm qtbase];
    meta.license = lib.licenses.lgpl3Plus;
  };
  visionToolsSrc = fetchFromGitHub {
    owner = "Acly";
    repo = "krita-vision-tools";
    tag = "v2.2.0";
    fetchSubmodules = true;
    hash = "sha256-Eah1acV3b/lIE8Cw+q9MTfTTHCMEOTagYMFPVbxmC6E=";
  };

  # vision.cpp FetchContent dependencies - pre-fetched for the Nix sandbox.
  stbSrc = fetchFromGitHub {
    owner = "nothings";
    repo = "stb";
    rev = "5736b15f7ea0ffb08dd38af21067c314d6a3aae9";
    hash = "sha256-s2ASdlT3bBNrqvwfhhN6skjbmyEnUgvNOrvhgUSRj98=";
  };
  fmtSrc = fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "40626af88bd7df9a5fb80be7b25ac85b122d6c21"; # 11.2.0
    hash = "sha256-sAlU5L/olxQUYcv8euVYWTTB8TrVeQgXLHtXy8IMEnU=";
  };

  # ML model files that krita-vision-tools downloads at CMake configure time.
  # Pre-fetched as fixed-output derivations for the Nix sandbox.
  model-mobilesam = fetchurl {
    url = "https://huggingface.co/Acly/MobileSAM-GGUF/resolve/main/MobileSAM-F16.gguf";
    hash = "sha256-tUY2ZHXjrXRLsur3Y034jpqvJfZiJ5fS3jAPWlMIMfc=";
  };
  model-birefnet = fetchurl {
    url = "https://huggingface.co/Acly/BiRefNet-GGUF/resolve/main/BiRefNet-lite-F16.gguf";
    hash = "sha256-e1OXosmNZmd/j3Qxd3S76sSduzIbij3HRK+RPbcdT6U=";
  };
  model-migan = fetchurl {
    url = "https://huggingface.co/Acly/MIGAN-GGUF/resolve/main/MIGAN-512-places2-F16.gguf";
    hash = "sha256-PkdZK/cW0Nwwb43ALUR2z82vLAVfo8PI4M7U23detks=";
  };
in
  mkDerivation rec {
    pname = "krita5-unwrapped";
    version = "6.0.1.1"; # Source version; built as "5.3" (Qt5 mode)

    src = fetchurl {
      url = "mirror://kde/stable/krita/6.0.1/krita-${version}.tar.gz";
      hash = "sha256-V8V+bwgAEqjLN8PafLfDA+ACTEcWgcgG2wqCr2x/hWw=";
    };

    nativeBuildInputs = [
      cmake
      extra-cmake-modules
      pkg-config
      python3Packages.sip
      shaderc # provides glslc for GGML Vulkan shader compilation (krita-vision-tools)
    ];

    buildInputs = [
      karchive
      kconfig
      kwidgetsaddons
      kcompletion
      kcoreaddons
      kguiaddons
      ki18n
      kitemmodels
      kitemviews
      kwindowsystem
      kio
      kcrash
      breeze-icons
      boost
      libraw
      fftw
      eigen
      exiv2
      fribidi
      lcms2
      gsl
      openexr
      lager
      libaom
      libheif
      giflib
      libjxl
      mlt
      openjpeg
      opencolorio
      xsimd
      poppler
      curl
      immer
      kseexpr
      libmypaint
      libunibreak
      libwebp
      qtmultimedia
      qtx11extras
      qtquickcontrols2
      quazip
      SDL2
      zug
      python3Packages.pyqt5
      # New deps in 6.0.x
      freetype
      harfbuzz
      fontconfig
      # krita-vision-tools deps
      vulkan-headers
      vulkan-loader
      shaderc
    ];

    env.NIX_CFLAGS_COMPILE = toString (lib.optional stdenv.cc.isGNU "-Wno-deprecated-copy");

    # Krita runs custom python scripts in CMake with custom PYTHONPATH which krita determined in their CMake script.
    # Patch the PYTHONPATH so python scripts can import sip successfully.
    postPatch = let
      pythonPath = python3Packages.makePythonPath (
        with python3Packages; [
          sip
          setuptools
        ]
      );
    in ''
      substituteInPlace cmake/modules/FindSIP.cmake \
        --replace 'PYTHONPATH=''${_pyqt5_python_path}' 'PYTHONPATH=${pythonPath}'
      substituteInPlace cmake/modules/SIPMacros.cmake \
        --replace 'PYTHONPATH=''${_krita_python_path}' 'PYTHONPATH=${pythonPath}'

      substituteInPlace plugins/impex/jp2/jp2_converter.cc \
        --replace '<openjpeg.h>' '<${openjpeg.incDir}/openjpeg.h>'

      # --- krita-vision-tools integration ---
      # Copy plugin source into the Krita plugins directory
      cp -r ${visionToolsSrc} plugins/krita-vision-tools
      chmod -R u+w plugins/krita-vision-tools

      # Pre-place model files so CMake file(DOWNLOAD) becomes a no-op
      mkdir -p plugins/krita-vision-tools/vision.cpp/models/sam
      mkdir -p plugins/krita-vision-tools/vision.cpp/models/birefnet
      mkdir -p plugins/krita-vision-tools/vision.cpp/models/migan
      cp ${model-mobilesam} plugins/krita-vision-tools/vision.cpp/models/sam/MobileSAM-F16.gguf
      cp ${model-birefnet} plugins/krita-vision-tools/vision.cpp/models/birefnet/BiRefNet-lite-F16.gguf
      cp ${model-migan} plugins/krita-vision-tools/vision.cpp/models/migan/MIGAN-512-places2-F16.gguf

      # Remove the CMake file(DOWNLOAD) blocks - models are pre-placed above.
      # Each block spans: message(...) + file(DOWNLOAD ... EXPECTED_HASH ... )
      sed -i '/\[VisionML Plugin\] Downloading/,/^)/d' plugins/krita-vision-tools/CMakeLists.txt

      # Register the plugin in Krita's plugin build
      echo 'add_subdirectory( krita-vision-tools )' >> plugins/CMakeLists.txt
    '';

    # Move krita-vision-tools from its custom install location into the
    # standard pykrita directory where Krita discovers Python plugins.
    postInstall = ''
      if [ -d "$out/krita-vision-tools" ]; then
        mkdir -p $out/share/krita/pykrita
        mv $out/krita-vision-tools/vision_tools.desktop $out/share/krita/pykrita/
        mv $out/krita-vision-tools/vision_tools $out/share/krita/pykrita/
        rmdir $out/krita-vision-tools
      fi
    '';

    cmakeBuildType = "RelWithDebInfo";

    cmakeFlags = [
      "-DPYQT5_SIP_DIR=${python3Packages.pyqt5}/${python3Packages.python.sitePackages}/PyQt5/bindings"
      "-DPYQT_SIP_DIR_OVERRIDE=${python3Packages.pyqt5}/${python3Packages.python.sitePackages}/PyQt5/bindings"
      "-DBUILD_KRITA_QT_DESIGNER_PLUGINS=ON"
      # Pre-fetched sources for vision.cpp FetchContent dependencies
      "-DFETCHCONTENT_SOURCE_DIR_STB=${stbSrc}"
      "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmtSrc}"
    ];

    meta = {
      description = "Free and open source painting application (Qt5 build of 6.0.x, for krita-ai-diffusion/vision-tools compatibility)";
      homepage = "https://krita.org/";
      maintainers = with lib.maintainers; [
        sifmelcara
      ];
      mainProgram = "krita";
      platforms = lib.platforms.linux;
      license = lib.licenses.gpl3Only;
    };
  }
