{ hf, ... }:
[
  # Model Patches
  (hf {
    name = "Z-Image-Turbo-Fun-Controlnet-Union-2.1-lite-2601-8steps.safetensors";
    url = "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union-2.1-lite-2601-8steps.safetensors";
    hash = "sha256-qkKLyFewCVzdtSzRrNfAxq2kxXZY7A7TnNZCgDVbOc8=";
    installPath = "model_patches";
  })
  (hf {
    name = "Z-Image-Turbo-Fun-Controlnet-Tile-2.1-lite-2601-8steps.safetensors";
    url = "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1/resolve/main/Z-Image-Turbo-Fun-Controlnet-Tile-2.1-lite-2601-8steps.safetensors";
    hash = "sha256-iAv0UrBgq/y8zt7lb409v4rtLLAxG1mSEDYbQU/I8v0=";
    installPath = "model_patches";
  })

  # VAE
  (hf {
    name = "flux_vae.safetensors";
    url = "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors";
    hash = "sha256-r8jignLNFds5GbrNtpGM6cHtIulssSxNXtD7qCNSnjg=";
    installPath = "vae";
  })

  # Diffusion Models
  (hf {
    name = "z_image_turbo_fp8_e4m3fn.safetensors";
    url = "https://huggingface.co/drbaph/Z-Image-Turbo-FP8/resolve/main/z_image_turbo_fp8_e4m3fn.safetensors";
    hash = "sha256-VsBq1suAlB6CA9PiSKFq0SY0mbqHDywZMapyT9x8JdM=";
    installPath = "diffusion_models";
  })
]
