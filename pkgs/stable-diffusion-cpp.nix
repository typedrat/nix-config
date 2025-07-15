{
  lib,
  stdenv,
  fetchFromGitHub,
  gitMinimal,
  cmake,
  pkg-config,
  cudaPackages,
  vulkan-headers,
  vulkan-loader,
  shaderc,
  mkl,
  openblas,
  darwin,
  enableOpenBLAS ? true,
  enableMetal ? stdenv.hostPlatform.isDarwin,
  enableVulkan ? stdenv.hostPlatform.isLinux,
  enableCuda ? false,
  enableHipBLAS ? false,
  enableSYCL ? false,
}:
stdenv.mkDerivation {
  pname = "stable-diffusion-cpp";
  version = "unstable-2025-03-08";

  src = fetchFromGitHub {
    owner = "leejet";
    repo = "stable-diffusion.cpp";
    rev = "10feacf031cccc19b7f1257048ec32b778a01dbf";
    hash = "sha256-LrWS16rddPqJJc+73/6mNqWdweAd0ZboxI5m1rvIxtA=";
    fetchSubmodules = true;
  };

  nativeBuildInputs =
    [
      gitMinimal
      cmake
      pkg-config
    ]
    ++ lib.optionals enableCuda [
      cudaPackages.cuda_nvcc
    ];

  buildInputs =
    lib.optionals enableCuda [
      cudaPackages.cudatoolkit
    ]
    ++ lib.optionals enableMetal [
      darwin.apple_sdk.frameworks.Foundation
      darwin.apple_sdk.frameworks.Metal
      darwin.apple_sdk.frameworks.MetalKit
    ]
    ++ lib.optionals enableVulkan [
      vulkan-headers
      vulkan-loader
      shaderc
    ]
    ++ lib.optionals enableSYCL [
      mkl
    ]
    ++ lib.optionals enableOpenBLAS [
      openblas
    ];

  cmakeFlags =
    [
      "-DCMAKE_BUILD_TYPE=Release"
    ]
    ++ lib.optionals enableCuda [
      "-DSD_CUDA=ON"
    ]
    ++ lib.optionals enableMetal [
      "-DSD_METAL=ON"
    ]
    ++ lib.optionals enableVulkan [
      "-DSD_VULKAN=ON"
    ]
    ++ lib.optionals enableHipBLAS [
      "-DSD_HIPBLAS=ON"
    ]
    ++ lib.optionals enableSYCL [
      "-DSD_SYCL=ON"
    ]
    ++ lib.optionals enableOpenBLAS [
      "-DGGML_OPENBLAS=ON"
    ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ./bin/sd $out/bin/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Stable Diffusion inference in pure C/C++";
    homepage = "https://github.com/leejet/stable-diffusion.cpp";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "sd";
  };
}
