{
  lib,
  fetchFromGitHub,
  python3Packages,
  cudaPackages,
  symlinkJoin,
}: let
  cuda-native-redist = symlinkJoin {
    name = "cuda-redist";
    paths = with cudaPackages; [
      cuda_cudart # cuda_runtime.h
      cuda_nvcc
    ];
  };
in
  python3Packages.buildPythonPackage rec {
    pname = "nunchaku";
    version = "1.1.0";
    pyproject = true;

    CUDA_HOME = cuda-native-redist;
    CUDA_VERSION = cudaPackages.cudaMajorMinorVersion;

    disabled = python3Packages.pythonOlder "3.10";

    src = fetchFromGitHub {
      owner = "mit-han-lab";
      repo = "nunchaku";
      tag = "v${version}";
      hash = "sha256-VePDdarlcIm9g7wXsXAA6pUkDfvKFKPJ5nRqZm8Kz/I=";
      fetchSubmodules = true;
    };

    build-system = with python3Packages; [
      setuptools
      ninja
      torch
    ];

    buildInputs = [
      cudaPackages.cudatoolkit
    ];

    dependencies = with python3Packages; [
      accelerate
      diffusers
      einops
      huggingface-hub
      peft
      protobuf
      sentencepiece
      torch
      torchvision
      transformers
    ];

    # These are set by the ComfyUI/nixified-ai build environment
    NUNCHAKU_INSTALL_MODE = "ALL";

    preConfigure = ''
      export MAX_JOBS="$NIX_BUILD_CORES"
      export NVCC_THREADS="$NIX_BUILD_CORES"
    '';

    doCheck = false;

    pythonImportsCheck = ["nunchaku"];

    meta = {
      description = "Efficient inference engine for 4-bit quantized neural networks using SVDQuant";
      homepage = "https://github.com/mit-han-lab/nunchaku";
      changelog = "https://github.com/mit-han-lab/nunchaku/releases/tag/v${version}";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux;
      maintainers = [];
    };
  }
