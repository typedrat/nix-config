{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  git,
  pkg-config,
  sentencepiece,
  openssl,
  alsa-lib,
  libpulseaudio,
  libjack2,
  autoAddDriverRunpath,
  cudaPackages,
  shaderc,
  spirv-headers,
  vulkan-headers,
  vulkan-loader,
  versionCheckHook,
  nix-update-script,
  config,
  # Backends.
  cudaSupport ? config.cudaSupport or false,
  vulkanSupport ? false,
  # null takes the nixpkgs default, which is every capability the CUDA version
  # supports and therefore compiles each .cu once per entry.
  cudaArchitectures ? null,
  # Components. The defaults match upstream's <backend>-server presets.
  nmtSupport ? true,
  httpSupport ? true,
  micCaptureSupport ? true,
  japaneseSupport ? false,
  mandarinSupport ? false,
  # check_backend_coverage, bench_asr_batching and nanocodec.
  buildTools ? false,
}: let
  inherit (lib) cmakeBool cmakeFeature optionals optionalString;

  # CUDA pins a maximum supported gcc, and mixing stdenvs produces libstdc++
  # mismatches further down the closure.
  effectiveStdenv =
    if cudaSupport
    then cudaPackages.backendStdenv
    else stdenv;

  # miniaudio dlopen()s these for microphone capture, so they only reach the
  # CLI through its RUNPATH.
  audioBackends = [
    alsa-lib
    libpulseaudio
    libjack2
  ];
in
  assert lib.assertMsg (!(cudaSupport && vulkanSupport))
  "nemo-speech: ggml is built with a single GPU backend; pick cudaSupport or vulkanSupport";
    effectiveStdenv.mkDerivation (finalAttrs: {
      pname = "nemo-speech";
      version = "0.2.0";

      src = fetchFromGitHub {
        owner = "NVIDIA";
        repo = "NeMo-Speech.cpp";
        tag = "v${finalAttrs.version}";
        # llama.cpp provides ggml; cpp-httplib, open_jtalk and cppjieba are
        # vendored per component. The Mandarin G2P data live in Git LFS.
        fetchSubmodules = true;
        fetchLFS = true;
        hash = "sha256-EE0V240b031y6PJYdekVs1R+IAtVrSI957KY6W1oOpI=";
      };

      strictDeps = true;
      __structuredAttrs = true;

      nativeBuildInputs =
        [
          cmake
          ninja
          # CMake applies patches/ to a copy of llama.cpp with `git apply`.
          git
          pkg-config
        ]
        ++ optionals cudaSupport [
          cudaPackages.cuda_nvcc
          autoAddDriverRunpath
        ]
        ++ optionals vulkanSupport [
          shaderc
        ];

      buildInputs =
        [
          sentencepiece
        ]
        ++ optionals httpSupport [openssl]
        ++ optionals cudaSupport (with cudaPackages;
          [
            cccl
            cuda_cudart
            libcublas
          ]
          # bench_asr_batching brackets its timed region with cudaProfilerStart.
          ++ optionals buildTools [cuda_profiler_api])
        ++ optionals vulkanSupport [
          spirv-headers
          vulkan-headers
          vulkan-loader
        ];

      cmakeFlags =
        [
          (cmakeBool "GGML_NATIVE" false)
          (cmakeBool "GGML_CUDA" cudaSupport)
          (cmakeBool "GGML_VULKAN" vulkanSupport)
          # Upstream's vulkan-* presets build pristine llama.cpp; patches/
          # targets the CPU and CUDA backends.
          (cmakeBool "NEMO_SPEECH_GGML_PATCHED" (!vulkanSupport))
          (cmakeBool "NEMO_SPEECH_BUILD_NMT" nmtSupport)
          (cmakeBool "NEMO_SPEECH_BUILD_HTTP" httpSupport)
          (cmakeBool "NEMO_SPEECH_HTTP_TLS" httpSupport)
          (cmakeBool "NEMO_SPEECH_BUILD_MIC_CAPTURE" micCaptureSupport)
          (cmakeBool "NEMO_SPEECH_TTS_WITH_JA" japaneseSupport)
          (cmakeBool "NEMO_SPEECH_TTS_WITH_ZH" mandarinSupport)
          (cmakeBool "NEMO_SPEECH_BUILD_TOOLS" buildTools)
        ]
        ++ optionals cudaSupport [
          (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" (
            if cudaArchitectures == null
            then cudaPackages.flags.cmakeCudaArchitecturesString
            else lib.concatStringsSep ";" cudaArchitectures
          ))
        ];

      # The vendored llama.cpp is patched and shares upstream's sonames, so keep
      # it out of lib/ where it would collide with llama-cpp in a profile.
      postInstall =
        ''
          mkdir $out/lib/nemo-speech
          mv $out/lib/libggml* $out/lib/libllama* $out/lib/nemo-speech/
          for f in $out/bin/nemo-speech $(find $out/lib -maxdepth 1 -type f -name 'libnemo_speech_*.so*'); do
            patchelf --add-rpath $out/lib/nemo-speech "$f"
          done
        ''
        # The tools/ targets declare no install rules.
        + optionalString buildTools ''
          install -Dm755 -t $out/bin bin/check_backend_coverage bin/bench_asr_batching bin/nanocodec
          for f in $out/bin/check_backend_coverage $out/bin/bench_asr_batching $out/bin/nanocodec; do
            patchelf --add-rpath $out/lib/nemo-speech "$f"
          done
        '';

      postFixup = optionalString (micCaptureSupport && effectiveStdenv.hostPlatform.isLinux) ''
        patchelf --add-rpath ${lib.makeLibraryPath audioBackends} $out/bin/nemo-speech
      '';

      # The CLI links libcuda.so.1, which only the host's driver provides.
      doInstallCheck = !cudaSupport;
      nativeInstallCheckInputs = [versionCheckHook];
      versionCheckProgramArg = "--version";

      passthru.updateScript = nix-update-script {};

      meta = {
        description = "NeMo speech models (ASR, diarization, TTS, translation) on ggml";
        homepage = "https://github.com/NVIDIA/NeMo-Speech.cpp";
        changelog = "https://github.com/NVIDIA/NeMo-Speech.cpp/releases/tag/v${finalAttrs.version}";
        license = lib.licenses.asl20;
        mainProgram = "nemo-speech";
        platforms = lib.platforms.unix;
        badPlatforms = optionals cudaSupport lib.platforms.darwin;
      };
    })
