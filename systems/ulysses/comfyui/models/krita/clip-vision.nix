{hf, ...}: [
  (hf {
    name = "clip-vision_vit-h.safetensors";
    url = "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors";
    hash = "sha256-bKlmfaHKngsPdeRrsDD34BH0T4bL+41aNlkPzXUHsDA=";
    installPath = "clip_vision";
  })
  (hf {
    name = "clip-vision_vit-g.safetensors";
    url = "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors";
    hash = "sha256-ZXcj4J9Gp8OVffZRYBAp9msXSK+xK0GYFjMPFu1F1k0=";
    installPath = "clip_vision";
  })
  (hf {
    name = "sigclip_vision_patch14_384.safetensors";
    url = "https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors";
    hash = "sha256-H+5QHeq6xy8O0XYQMH1xMePp0eg40DY6o8K5em4D+zM=";
    installPath = "clip_vision";
  })
]
