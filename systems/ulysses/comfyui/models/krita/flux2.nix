{hf, ...}: [
  # Text Encoders
  (hf {
    name = "Qwen3-4B-Q4_K_M.gguf";
    url = "https://huggingface.co/unsloth/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf";
    hash = "sha256-9vhRd3cJhhBW782tOvAdo4sxIjo7om5hpPi/OiGVgTo=";
    installPath = "text_encoders";
  })

  # VAE
  (hf {
    name = "flux2-vae.safetensors";
    url = "https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-4b/resolve/main/split_files/vae/flux2-vae.safetensors";
    hash = "sha256-ho/ns0PMjzoZ28/K+8PV+IiAK+P4m9gbZbNiGgZs6PM=";
    installPath = "vae";
  })

  # LoRAs
  (hf {
    name = "flux-2-klein-4B-outpaint-lora.safetensors";
    url = "https://huggingface.co/fal/flux-2-klein-4B-outpaint-lora/resolve/main/LyNiaZ53Tudg0J6sT8Xbx_pytorch_lora_weights_comfy_converted.safetensors";
    hash = "sha256-uKUUK0Dy4kqh9c/QcQMjGIg29J6nCxW1+FseNkMWvFs=";
    installPath = "loras";
  })

  # Diffusion Models
  (hf {
    name = "flux-2-klein-4b-fp8.safetensors";
    url = "https://huggingface.co/black-forest-labs/FLUX.2-klein-4b-fp8/resolve/main/flux-2-klein-4b-fp8.safetensors";
    hash = "sha256-l+00/gVn5DYgDy+u45ObiPK12Z+K8qTcFlMsQkXAzLY=";
    installPath = "diffusion_models";
  })
]
