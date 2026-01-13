{
  hf,
  models,
  ...
}: [
  models.ip-adapter-sdxl-vit-h-ipadapter
  (hf {
    name = "ip-adapter-faceid-plusv2_sdxl.bin";
    url = "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin";
    hash = "sha256-xpRdgrVDcAzDzLuY02O4N+nFligWB4V8dLcTqHba9fs=";
    installPath = "ipadapter";
  })
  (hf {
    name = "noobIPAMARK1_mark1.safetensors";
    url = "https://huggingface.co/r3gm/noob-ipa/resolve/main/model_G/noobIPAMARK1_mark1.safetensors";
    hash = "sha256-XNtqAL4bEleXRbW+0Me4PwhpBz2Khk+ozVCpNWYBkZo=";
    installPath = "ipadapter";
  })
]
