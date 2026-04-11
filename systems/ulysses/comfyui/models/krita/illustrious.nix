{ hf, ... }:
[
  # ControlNet
  (hf {
    name = "noobaiInpainting_v10.fp16.safetensors";
    url = "https://huggingface.co/Acly/NoobAI-Inpainting/resolve/main/noobaiInpainting_v10.fp16.safetensors";
    hash = "sha256-izwhVeyKSbQ6ijLaw5ohuMCepgp6+v/jx6b7UTE6RdY=";
    installPath = "controlnet";
  })
  (hf {
    name = "noob-sdxl-controlnet-scribble_pidinet.fp16.safetensors";
    url = "https://huggingface.co/Eugeoter/noob-sdxl-controlnet-scribble_pidinet/resolve/main/diffusion_pytorch_model.fp16.safetensors";
    hash = "sha256-a6VddeNPY9BTjC3BAGQVxJXyVGJMHIJt99+vS8Fy7kc=";
    installPath = "controlnet";
  })
  (hf {
    name = "noob-sdxl-controlnet-lineart_anime.fp16.safetensors";
    url = "https://huggingface.co/Eugeoter/noob-sdxl-controlnet-lineart_anime/resolve/main/diffusion_pytorch_model.fp16.safetensors";
    hash = "sha256-ROrmpRSmCuQm/5ZuzbueFwrWPYiJRWmCuykDffQrhqg=";
    installPath = "controlnet";
  })
  (hf {
    name = "noob-sdxl-controlnet-softedge_hed.fp16.safetensors";
    url = "https://huggingface.co/Eugeoter/noob-sdxl-controlnet-softedge_hed/resolve/main/diffusion_pytorch_model.fp16.safetensors";
    hash = "sha256-xUDpu0dNewkM7l9FAXzrotWHdccbwPbq+kELQ1sd/ZI=";
    installPath = "controlnet";
  })
  (hf {
    name = "noob_sdxl_controlnet_canny.fp16.safetensors";
    url = "https://huggingface.co/Eugeoter/noob-sdxl-controlnet-canny/resolve/main/noob_sdxl_controlnet_canny.fp16.safetensors";
    hash = "sha256-43vNsvSm0Xgtr2qUOjJr7m5tMCfDT2AWRgosk3up+6A=";
    installPath = "controlnet";
  })
  (hf {
    name = "noob-sdxl-controlnet-depth_midas-v1-1.fp16.safetensors";
    url = "https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors";
    hash = "sha256-Z4uU7zJgdEoenlCTLviJXn9/q/Je7H/VzJYpj3Ig/lA=";
    installPath = "controlnet";
  })
  (hf {
    name = "noob-sdxl-controlnet-normal.fp16.safetensors";
    url = "https://huggingface.co/Eugeoter/noob-sdxl-controlnet-normal/resolve/main/diffusion_pytorch_model.fp16.safetensors";
    hash = "sha256-vPx+pBcFLdVBJcV30B6c9/DoGGP/anXOI7ROuh1/o9M=";
    installPath = "controlnet";
  })
  (hf {
    name = "noobaiXLControlnet_openposeModel.safetensors";
    url = "https://huggingface.co/Laxhar/noob_openpose/resolve/main/openpose_pre.safetensors";
    hash = "sha256-kYz8TX3vFl6noGvuEIQf5SUzJRX4oEhsXLKhcexAuHM=";
    installPath = "controlnet";
  })
  (hf {
    name = "noob-sdxl-controlnet-tile.fp16.safetensors";
    url = "https://huggingface.co/Eugeoter/noob-sdxl-controlnet-tile/resolve/main/diffusion_pytorch_model.fp16.safetensors";
    hash = "sha256-1tZ28pFTNXrI1Xcn41uO3AkKpN5X6GG4eIcv9FxDJhU=";
    installPath = "controlnet";
  })

  # CLIP Vision
  (hf {
    name = "clip-vision_vit-g.safetensors";
    url = "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors";
    hash = "sha256-ZXcj4J9Gp8OVffZRYBAp9msXSK+xK0GYFjMPFu1F1k0=";
    installPath = "clip_vision";
  })

  # IP-Adapter
  (hf {
    name = "noobIPAMARK1_mark1.safetensors";
    url = "https://huggingface.co/r3gm/noob-ipa/resolve/main/model_G/noobIPAMARK1_mark1.safetensors";
    hash = "sha256-XNtqAL4bEleXRbW+0Me4PwhpBz2Khk+ozVCpNWYBkZo=";
    installPath = "ipadapter";
  })

  # Checkpoints
  (hf {
    name = "novaAnimeXL_ilV125.safetensors";
    url = "https://huggingface.co/Acly/SD-Checkpoints/resolve/main/novaAnimeXL_ilV125.safetensors";
    hash = "sha256-vRV+Yt5zHb0bWwChFPX1wTeBTs5OFigbNxSLh95/TUg=";
    installPath = "checkpoints";
  })
]
