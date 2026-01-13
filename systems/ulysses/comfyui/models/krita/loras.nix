{
  hf,
  models,
  ...
}: [
  models.hyper-sdxl-8steps-cfg-lora
  (hf {
    name = "ip-adapter-faceid-plusv2_sdxl_lora.safetensors";
    url = "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors";
    hash = "sha256-8ktLstrWY4oJwA8VHN6EmRuvN0QJOFvLq1PBhxowy3s=";
    installPath = "loras";
  })
  (hf {
    name = "FLUX.1-Turbo-Alpha.safetensors";
    url = "https://huggingface.co/alimama-creative/FLUX.1-Turbo-Alpha/resolve/main/diffusion_pytorch_model.safetensors";
    hash = "sha256-d/dSOl6cPabPxzDGsHRhEp+lKZfqBhaOntUxIiiqC/8=";
    installPath = "loras";
  })
]
