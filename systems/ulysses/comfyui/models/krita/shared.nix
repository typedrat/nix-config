{hf, ...}: [
  # Upscalers
  (hf {
    name = "4x_NMKD-Superscale-SP_178000_G.pth";
    url = "https://huggingface.co/gemasai/4x_NMKD-Superscale-SP_178000_G/resolve/main/4x_NMKD-Superscale-SP_178000_G.pth";
    hash = "sha256-HRsAeP5xRG4EadjU31npa6qA2DzaYA1oI31lWDCCG8w=";
    installPath = "upscale_models";
  })
  (hf {
    name = "OmniSR_X2_DIV2K.safetensors";
    url = "https://huggingface.co/Acly/Omni-SR/resolve/main/OmniSR_X2_DIV2K.safetensors";
    hash = "sha256-eUCPwjIDvxYfqpV8SmAsxAUh7SI1py2Xa9nTdeZkRhE=";
    installPath = "upscale_models";
  })
  (hf {
    name = "OmniSR_X3_DIV2K.safetensors";
    url = "https://huggingface.co/Acly/Omni-SR/resolve/main/OmniSR_X3_DIV2K.safetensors";
    hash = "sha256-T7C2j8MU95jS3c8fPSJTBFuj2VnYua4nDFqZufhi7hI=";
    installPath = "upscale_models";
  })
  (hf {
    name = "OmniSR_X4_DIV2K.safetensors";
    url = "https://huggingface.co/Acly/Omni-SR/resolve/main/OmniSR_X4_DIV2K.safetensors";
    hash = "sha256-3/JeTtOSy1y+U02SDikgY6BVXfkoHFTF7DIUkKKlmDI=";
    installPath = "upscale_models";
  })
  (hf {
    name = "HAT_SRx4_ImageNet-pretrain.pth";
    url = "https://huggingface.co/Acly/hat/resolve/main/HAT_SRx4_ImageNet-pretrain.pth";
    hash = "sha256-TuBTxCRhGHhG3A6Tqlq9NFkcByWo4ESlkADpLuIV6DM=";
    installPath = "upscale_models";
  })
  (hf {
    name = "Real_HAT_GAN_sharper.pth";
    url = "https://huggingface.co/Acly/hat/resolve/main/Real_HAT_GAN_sharper.pth";
    hash = "sha256-WAC2cTYAbrjKs7TtfI1ztqGVuxjmzHCbZ0+aoGnAAnE=";
    installPath = "upscale_models";
  })

  # Inpaint
  (hf {
    name = "MAT_Places512_G_fp16.safetensors";
    url = "https://huggingface.co/Acly/MAT/resolve/main/MAT_Places512_G_fp16.safetensors";
    hash = "sha256-MJ3Wzm4EA03EtrFce9KkhE0VjgPrKhOeDsprNm5AwN4=";
    installPath = "inpaint";
  })
]
