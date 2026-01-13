{
  hf,
  civitai,
  models,
  ...
}: [
  (hf {
    name = "4x_NMKD-Superscale-SP_178000_G.pth";
    url = "https://huggingface.co/gemasai/4x_NMKD-Superscale-SP_178000_G/resolve/main/4x_NMKD-Superscale-SP_178000_G.pth";
    hash = "sha256-HRsAeP5xRG4EadjU31npa6qA2DzaYA1oI31lWDCCG8w=";
    installPath = "upscale_models";
  })
  models.omnisr-x2-div2k-upscaler
  models.omnisr-x3-div2k-upscaler
  models.omnisr-x4-div2k-upscaler
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
  (civitai {
    name = "4x_remacri.safetensors";
    air = "urn:air:other:upscaler:civitai:147759@164821";
    sha256 = "sha256-rD5sxbV0DDCOfx9ITacDCuW9DB0zQzz/zvxC4DcEoDY=";
    installPath = "upscale_models";
  })
]
