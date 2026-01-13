{hf, ...}: [
  (hf {
    name = "flux_vae.safetensors";
    url = "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors";
    hash = "sha256-r8jignLNFds5GbrNtpGM6cHtIulssSxNXtD7qCNSnjg=";
    installPath = "vae";
  })
  (hf {
    name = "sdxl_vae.safetensors";
    url = "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors";
    hash = "sha256-Y67suQ/3vBwRU5WWLT6ANXE4W2GTg3e8cImzboHpLi4=";
    installPath = "vae";
  })
]
