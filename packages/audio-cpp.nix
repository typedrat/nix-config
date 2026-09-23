{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  python3,
  openssl,
  espeak-ng,
  autoAddDriverRunpath,
  cudaPackages,
  rocmPackages,
  glslang,
  shaderc,
  spirv-headers,
  vulkan-headers,
  vulkan-loader,
  nix-update-script,
  config,
  # Backends.
  cudaSupport ? config.cudaSupport or false,
  rocmSupport ? config.rocmSupport or false,
  vulkanSupport ? false,
  metalSupport ? stdenv.hostPlatform.isDarwin,
  rocmGpuTargets ? rocmPackages.clr.localGpuTargets or rocmPackages.clr.gpuTargets,
  # Only validated on Strix Halo, so it stays tied to that target by default.
  strixHaloOptimizations ? rocmSupport && rocmGpuTargets == ["gfx1151"],
  cudaGraphsSupport ? true,
  # null takes the nixpkgs default, which is every capability the CUDA version
  # supports and therefore compiles each .cu once per entry. Naming only the
  # capabilities you run cuts that down, and ggml compiles its SageAttention2
  # kernels only when every entry is 89 or above.
  cudaArchitectures ? null,
  # Host code.
  openmpSupport ? !stdenv.hostPlatform.isDarwin,
  llamafileSupport ? true,
  # -march=native: correct only when the build host and the run host are the
  # same machine, which is not something a Nix build can assume.
  nativeCpuOptimizations ? false,
  # Per-ISA CPU backends selected at runtime, as dynamic libraries beside the
  # executables. Mutually exclusive with nativeCpuOptimizations upstream.
  cpuAllVariants ? false,
  # Model downloading and installation, in the CLI tool and in the server.
  nativeModelManagerSupport ? true,
  # eSpeak-ng is dlopen()ed at runtime by the TTS phonemizer frontends.
  espeakSupport ? true,
  # Compile the model spec catalog into the binaries. Without it specs are
  # looked up by walking up from the working directory, which finds nothing
  # for a store-installed build.
  deploymentBuild ? true,
  buildCApi ? false,
  buildExamples ? false,
  # "full" builds all 83 model runtimes, "core" none of them; "custom" takes
  # the families listed in `models`.
  modelSet ?
    if models != []
    then "custom"
    else "full",
  models ? [],
  # An out-of-tree server frontend package (a directory containing
  # server_frontends.cmake) and the modules from it to build.
  serverFrontendsDir ? null,
  serverFrontendModules ? [],
}: let
  inherit (lib) cmakeBool cmakeFeature optionals optionalString;

  # CUDA pins a maximum supported gcc, and mixing stdenvs produces libstdc++
  # mismatches further down the closure.
  effectiveStdenv =
    if cudaSupport
    then cudaPackages.backendStdenv
    else stdenv;

  inherit (effectiveStdenv.hostPlatform.extensions) sharedLibrary;

  # The phonemizer dlopen()s eSpeak by soname from a fixed list of FHS paths,
  # none of which exist on NixOS.
  espeakCandidates =
    if effectiveStdenv.hostPlatform.isDarwin
    then ''"libespeak-ng.dylib", "libespeak-ng.1.dylib",''
    else ''"libespeak-ng.so.1", "libespeak-ng.so",'';
  espeakLibrary =
    if effectiveStdenv.hostPlatform.isDarwin
    then "libespeak-ng.dylib"
    else "libespeak-ng.so.1";
in
  assert lib.assertMsg (!(cpuAllVariants && nativeCpuOptimizations))
  "audio-cpp: cpuAllVariants selects a CPU backend per ISA at runtime, so the kernels cannot also be compiled for the build host's ISA";
  # ggml_simple_inference links only ggml, and cpuAllVariants moves the CPU
  # kernels into a backend module that is loaded at runtime instead.
  assert lib.assertMsg (!(cpuAllVariants && buildExamples))
  "audio-cpp: buildExamples does not link against the dynamically loaded CPU backend that cpuAllVariants builds";
    effectiveStdenv.mkDerivation (finalAttrs: {
      pname = "audio-cpp";
      version = "0.8.1";

      src = fetchFromGitHub {
        owner = "0xShug0";
        repo = "audio.cpp";
        tag = "v${finalAttrs.version}";
        hash = "sha256-sFpLoUtSin+oS3gNUjWvZO5ShBmjR4T47IyGBF3egxg=";
      };

      strictDeps = true;

      outputs = ["out"] ++ optionals buildExamples ["examples"];

      postPatch = optionalString espeakSupport ''
        substituteInPlace src/framework/audio/espeak_phonemizer.cpp \
          --replace-fail '${espeakCandidates}' \
            '"${lib.getLib espeak-ng}/lib/${espeakLibrary}", ${espeakCandidates}'
      '';

      nativeBuildInputs =
        [
          cmake
          ninja
          pkg-config
        ]
        ++ optionals cudaSupport [
          cudaPackages.cuda_nvcc
          autoAddDriverRunpath
        ]
        ++ optionals rocmSupport [
          rocmPackages.clr
        ]
        # vulkan-shaders-gen compiles the backend's shaders with glslc.
        ++ optionals vulkanSupport [
          glslang
          shaderc
        ];

      buildInputs =
        [
          # model_manager_v2.py is stdlib-only; this is for its shebang.
          python3
        ]
        ++ optionals nativeModelManagerSupport [openssl]
        ++ optionals espeakSupport [espeak-ng]
        ++ optionals cudaSupport (with cudaPackages; [
          cccl
          cuda_cudart
          libcublas
          libcufft
        ])
        ++ optionals rocmSupport (with rocmPackages; [
          clr
          hipblas
          rocblas
        ])
        ++ optionals vulkanSupport [
          spirv-headers
          vulkan-headers
          vulkan-loader
        ];

      cmakeFlags =
        [
          (cmakeFeature "AUDIOCPP_VERSION" finalAttrs.version)
          (cmakeFeature "AUDIOCPP_MODEL_SET" modelSet)
          (cmakeBool "AUDIOCPP_DEPLOYMENT_BUILD" deploymentBuild)
          (cmakeBool "AUDIOCPP_BUILD_C_API" buildCApi)
          (cmakeBool "AUDIOCPP_BUILD_NATIVE_MODEL_MANAGER" nativeModelManagerSupport)
          (cmakeBool "ENGINE_BUILD_EXAMPLES" buildExamples)
          (cmakeBool "ENGINE_ENABLE_CPU_ALL_VARIANTS" cpuAllVariants)
          (cmakeBool "ENGINE_ENABLE_CUDA" cudaSupport)
          (cmakeBool "ENGINE_ENABLE_CUDA_GRAPHS" cudaGraphsSupport)
          (cmakeBool "ENGINE_ENABLE_HIP" rocmSupport)
          (cmakeBool "ENGINE_ENABLE_LLAMAFILE" llamafileSupport)
          (cmakeBool "ENGINE_ENABLE_METAL" metalSupport)
          (cmakeBool "ENGINE_ENABLE_NATIVE_CPU" nativeCpuOptimizations)
          (cmakeBool "ENGINE_ENABLE_OPENMP" openmpSupport)
          (cmakeBool "ENGINE_ENABLE_VULKAN" vulkanSupport)
          (cmakeBool "ENGINE_HIP_STRIX_HALO_OPTIMIZATIONS" strixHaloOptimizations)
        ]
        ++ optionals (modelSet == "custom") [
          (cmakeFeature "AUDIOCPP_MODELS" (lib.concatStringsSep "," models))
        ]
        # Otherwise cpp-httplib fetches and builds BoringSSL, which needs network
        # access during the build.
        ++ optionals nativeModelManagerSupport [
          (cmakeBool "AUDIOCPP_USE_SYSTEM_OPENSSL" true)
        ]
        ++ optionals cudaSupport [
          (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" (
            if cudaArchitectures == null
            then cudaPackages.flags.cmakeCudaArchitecturesString
            else lib.concatStringsSep ";" cudaArchitectures
          ))
        ]
        ++ optionals rocmSupport [
          (cmakeFeature "CMAKE_HIP_COMPILER" "${rocmPackages.llvm.clang}/bin/clang")
          (cmakeFeature "GPU_TARGETS" (lib.concatStringsSep ";" rocmGpuTargets))
        ]
        ++ optionals (serverFrontendsDir != null) [
          (cmakeBool "AUDIOCPP_BUILD_SERVER_FRONTENDS" true)
          (cmakeFeature "AUDIOCPP_SERVER_FRONTENDS_DIR" "${serverFrontendsDir}")
          (cmakeFeature "AUDIOCPP_SERVER_FRONTEND_MODULES" (lib.concatStringsSep ";" serverFrontendModules))
        ];

      env = lib.optionalAttrs rocmSupport {
        ROCM_PATH = "${rocmPackages.clr}";
      };

      # Upstream declares no install rules.
      installPhase = ''
        runHook preInstall

        install -Dm755 -t $out/bin \
          bin/audiocpp_cli \
          bin/audiocpp_gguf \
          bin/audiocpp_server
        ${optionalString nativeModelManagerSupport ''
          install -Dm755 -t $out/bin bin/audiocpp_model_manager
        ''}
        ${optionalString buildExamples ''
          install -Dm755 -t $examples/bin \
            bin/ggml_simple_inference \
            bin/model_spec_demo \
            bin/model_spec_download_demo
        ''}
        ${optionalString cpuAllVariants ''
          find bin -maxdepth 1 -name '*${sharedLibrary}*' ! -name 'libaudiocpp*' \
            -exec install -Dm755 -t $out/bin {} +
        ''}
        ${optionalString buildCApi ''
          install -Dm755 -t $out/lib bin/libaudiocpp${sharedLibrary}
          install -Dm644 -t $out/include $src/include/audiocpp.h
        ''}
        ${optionalString (buildCApi && cpuAllVariants) ''
          # libaudiocpp resolves ggml and its backend modules through $ORIGIN,
          # which is $out/lib for a consumer linking against the C ABI.
          ln -s $out/bin/libggml*${sharedLibrary}* $out/lib/
        ''}

        # The Python manager predates audiocpp_model_manager and is only a
        # fallback for builds without it, so it stays off $PATH otherwise.
        install -Dm755 $src/tools/model_manager_v2.py $out/libexec/audio.cpp/model_manager_v2.py
        ${optionalString (!nativeModelManagerSupport) ''
          ln -s $out/libexec/audio.cpp/model_manager_v2.py $out/bin/audiocpp_model_manager_v2.py
        ''}

        mkdir -p $out/share/audio.cpp
        cp -R $src/model_specs $out/share/audio.cpp/model_specs

        runHook postInstall
      '';

      passthru.updateScript = nix-update-script {};

      meta = {
        description = "High-performance C++ audio inference framework";
        homepage = "https://github.com/0xShug0/audio.cpp";
        changelog = "https://github.com/0xShug0/audio.cpp/releases/tag/v${finalAttrs.version}";
        license = lib.licenses.asl20;
        mainProgram = "audiocpp_cli";
        platforms = lib.platforms.unix;
        badPlatforms = optionals (cudaSupport || rocmSupport) lib.platforms.darwin;
        broken = metalSupport && !effectiveStdenv.hostPlatform.isDarwin;
      };
    })
