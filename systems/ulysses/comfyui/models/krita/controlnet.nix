{hf, ...}: [
  # ControlNet (SDXL)
  (hf {
    name = "xinsir-controlnet-union-sdxl-1.0-promax.safetensors";
    url = "https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors";
    hash = "sha256-n64uUMtDG/y+BYIrWewiKN9UXvJ/cR3qiUnp9O2ffNw=";
    installPath = "controlnet";
  })
  (hf {
    name = "control_v1p_sdxl_qrcode_monster.safetensors";
    url = "https://huggingface.co/monster-labs/control_v1p_sdxl_qrcode_monster/resolve/main/diffusion_pytorch_model.safetensors";
    hash = "sha256-EeSbTicvq9pgCUs1vm/T4hXlUSESEJOOOB0nSX/SIVw=";
    installPath = "controlnet";
  })

  # ControlNet (Flux)
  (hf {
    name = "FLUX.1-dev-ControlNet-Union-Pro-2.0-fp8.safetensors";
    url = "https://huggingface.co/ABDALLALSWAITI/FLUX.1-dev-ControlNet-Union-Pro-2.0-fp8/resolve/main/diffusion_pytorch_model.safetensors";
    hash = "sha256-OT/Copi5P/458ts/DSzhHfumLUS3qjwd0zgNShvgTes=";
    installPath = "controlnet";
  })
  (hf {
    name = "FLUX.1-dev-Controlnet-Inpainting-Beta.safetensors";
    url = "https://huggingface.co/alimama-creative/FLUX.1-dev-Controlnet-Inpainting-Beta/resolve/main/diffusion_pytorch_model.safetensors";
    hash = "sha256-ykbF97XeAsrufAafKu2/Yor43vhXgxnOrjvhWI1EhEg=";
    installPath = "controlnet";
  })

  # ControlNet (Illustrious/NoobAI)
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
]
