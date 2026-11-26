{
  lib,
  stdenv,
  stdenvNoCC,
  fetchgit,
  cmake,
  ninja,
  pkg-config,
  makeShellWrapper,
  wrapGAppsHook4,
  gobject-introspection,
  copyDesktopItems,
  makeDesktopItem,
  git,
  writeShellApplication,
  perl,
  glslang,
  spirv-cross,
  curl,
  cacert,
  jq,
  gnused,
  coreutils,
  nix-prefetch-git,
  python3,
  bash,
  util-linux,
  gtk4,
  libadwaita,
  adwaita-icon-theme,
  librsvg,
  mangohud,
  vulkan-headers,
  vulkan-loader,
  sdl3,
  ffmpeg-headless,
  boost,
  fmt,
  magic-enum,
  robin-map,
  xxhash,
  vulkan-memory-allocator,
  xbyak,
  zydis,
  spirv-headers,
  miniz,
  libx11,
  libxcb,
  xorgproto,
  wayland,
  protobuf,
  openssl,
  zlib,
  nlohmann_json,
  miniupnpc,
}: let
  pname = "bloodborne-pc";
  version = "unstable-2026-11-20";
  rev = "11f0493bd2671b00395f07924e9da789e17b9f7f";

  # Path tracing lands through PR 173 of Supermedo/bloodborne_pc. update.sh follows
  # the PR's head while it is open and its base branch once it has merged.
  src = fetchgit {
    url = "https://github.com/Supermedo/bloodborne_pc.git";
    inherit rev;
    fetchSubmodules = true;
    hash = "sha256-BhoyYAuIzCfyiWUKzaHG9Or53lse5oTpIoh/Z++GTKc=";
  };

  # The Q2RTX commit tools/fetch_fsr4_assets.sh downloads from. postPatch fails
  # when the source pins another one, since this fixed-output derivation would
  # otherwise keep serving the old assets.
  fsr4Commit = "ae8d628fae208813172446d1e49ed94150b04658";

  # FSR 4 v07 SPIR-V passes and model weights, built by Q2RTX from AMD's
  # MIT-licensed FidelityFX source. The port does not ship them in git; without
  # them FSR 4 cannot run.
  fsr4Shaders = stdenvNoCC.mkDerivation {
    pname = "fsr4-shaders";
    version = "q2rtx-${builtins.substring 0 7 fsr4Commit}";
    nativeBuildInputs = [curl cacert];
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-LgxdbZmvyeIzNwwhIWCZPouvlR2+jH24QHIhuy1VkR0=";
    buildCommand = ''
      mkdir -p tools
      cp ${src}/tools/fetch_fsr4_assets.sh tools/
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
      BB_FSR4_TIERS="1080 2160" bash tools/fetch_fsr4_assets.sh
      mkdir -p $out
      cp -a fsr4_shaders/. $out/
    '';
  };

  # Pillow turns the game's trophy pictures into the pop-up's; PyGObject runs
  # the GTK launcher.
  pythonEnv = python3.withPackages (ps: [ps.pillow ps.pygobject3]);

  # Shared by the game and the launcher, which starts run.sh itself. run.sh
  # puts saves, mods and patches under BB_DATA_DIR on its own.
  gameWrapperArgs = ''
    --prefix PATH : ${lib.makeBinPath [bash coreutils pythonEnv]} \
    --set BB_PREBUILT 1 \
    --set PYTHON ${lib.getExe pythonEnv} \
    --run '
      data="''${XDG_DATA_HOME:-$HOME/.local/share}/bloodborne-pc"
      config="''${XDG_CONFIG_HOME:-$HOME/.config}/bloodborne-pc"
      mkdir -p "$data" "$config"
      export BB_DATA_DIR="$data"
      export BB_CONFIG="''${BB_CONFIG:-$config/bbport.ini}"
      export BB_GAME_DIR="''${BB_GAME_DIR:-$HOME/Games/Bloodborne}"
      export BB_RT_SKY_CACHE="''${BB_RT_SKY_CACHE:-$data/rt_sky}"
      export BB_RT_CFG="''${BB_RT_CFG:-$data/rt.cfg}"
    '
  '';
in
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
      makeShellWrapper
      wrapGAppsHook4
      gobject-introspection
      copyDesktopItems
      git
      perl
      pythonEnv
      glslang
      spirv-cross
    ];
    buildInputs = [
      vulkan-headers
      vulkan-loader
      sdl3
      ffmpeg-headless
      boost
      fmt
      magic-enum
      robin-map
      xxhash
      vulkan-memory-allocator
      glslang
      spirv-cross
      xbyak
      zydis
      spirv-headers
      miniz
      libx11
      libxcb
      xorgproto
      wayland
      protobuf
      openssl
      zlib
      nlohmann_json
      miniupnpc
      gtk4
      libadwaita
      adwaita-icon-theme
      librsvg
    ];

    patches = [
      # Three Linux build fixes: newer Vulkan headers, a missing uint32_t alias,
      # and rt_map_files.cpp for the geometry test target.
      ./linux-build-fixes.patch
      # Path tracing switches in the launcher. The live ones are written to
      # BB_RT_CFG, which the running game re-reads.
      ./launcher-path-tracing.patch
    ];

    dontConfigure = true;
    # patchelf's RPATH shrinking corrupts the non-PIE bb-probe's symbol
    # versions; upstream packaging/default.nix disables it for the same reason.
    dontPatchELF = true;
    # Only the launcher needs the GApps environment; postFixup wraps it.
    dontWrapGApps = true;

    postPatch = ''
      if ! grep -qx 'commit=${fsr4Commit}' tools/fetch_fsr4_assets.sh; then
        echo 'fetch_fsr4_assets.sh pins another Q2RTX commit; run the update script' >&2
        exit 1
      fi
      cp -a ${fsr4Shaders} fsr4_shaders
      # The store copy is read-only; installPhase writes fsr4_shaders/opt.
      chmod -R u+w fsr4_shaders

      # Without the build-tree entry, bb-probe's RUNPATH is $ORIGIN/gpu plus the
      # store paths the ld wrapper adds, so nothing has to rewrite it afterwards.
      substituteInPlace build.sh \
        --replace-fail ' -Wl,-rpath,"$PWD/out/gpu"' ""

      # A packaged launcher starts with no game folder; take the wrapper's.
      substituteInPlace launcher/bbport_launcher.py \
        --replace-fail '"game_dir": "" if PACKAGED' '"game_dir": os.environ.get("BB_GAME_DIR", "") if PACKAGED'
    '';

    buildPhase = ''
      runHook preBuild
      export BB_IN_NIX_SHELL=1
      export BB_LTO=ON
      bash build.sh
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      d=$out/libexec/bloodborne-pc
      mkdir -p $d/bin/gpu $out/bin
      install -m755 out/bb-probe $d/bin/bb-probe
      install -m755 out/bb-gpu-capabilities $d/bin/bb-gpu-capabilities
      install -Dm755 out/gpu/libbbgpu.so $d/bin/gpu/libbbgpu.so

      # run.sh only optimizes FSR 4 when it builds the port itself, so do it here:
      # fsr4_shaders/opt holds the bit-exact, ~3.5x faster post passes.
      BB_FSR4_DIR=$PWD/fsr4_shaders bash tools/fsr4_optimize.sh \
        || echo 'FSR 4: optimized post passes not built' >&2

      cp run.sh run.py $d/
      chmod 755 $d/run.sh
      # run.py imports the trophy pop-up's names and icons from launcher/.
      cp -r scripts patches launcher fsr4_shaders $d/

      install -Dm644 launcher/bloodborne.png $out/share/icons/hicolor/128x128/apps/bloodborne-pc.png

      makeShellWrapper $d/run.sh $out/bin/bloodborne-pc \
        ${gameWrapperArgs}
      runHook postInstall
    '';

    # gappsWrapperArgs is only filled in during preFixup.
    postFixup = ''
      makeShellWrapper ${lib.getExe pythonEnv} $out/bin/bloodborne-pc-launcher \
        --add-flags $out/libexec/bloodborne-pc/launcher/bbport_launcher.py \
        "''${gappsWrapperArgs[@]}" \
        --prefix PATH : ${lib.makeBinPath [util-linux]} \
        --prefix XDG_DATA_DIRS : ${mangohud}/share \
        ${gameWrapperArgs}
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "bloodborne-pc";
        desktopName = "Bloodborne";
        comment = "Native Linux port of Bloodborne";
        exec = "bloodborne-pc-launcher";
        icon = "bloodborne-pc";
        categories = ["Game"];
      })
    ];

    passthru.updateScript = lib.getExe (writeShellApplication {
      name = "bloodborne-pc-update";
      runtimeInputs = [
        curl
        jq
        gnused
        coreutils
        nix-prefetch-git
      ];
      text = builtins.readFile ./update.sh;
    });

    meta = {
      description = "Native Linux port of Bloodborne with path tracing, built from source";
      homepage = "https://github.com/Supermedo/bloodborne_pc";
      license = [lib.licenses.gpl2Only lib.licenses.mit];
      # The FSR 4 SPIR-V passes and model weights are downloaded prebuilt.
      sourceProvenance = [lib.sourceTypes.fromSource lib.sourceTypes.binaryBytecode];
      mainProgram = pname;
      platforms = lib.platforms.linux;
    };
  }
