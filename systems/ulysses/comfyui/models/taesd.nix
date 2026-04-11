{ hf, ... }:
[
  # SD 1.x / 2.x
  (hf {
    name = "taesd_decoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesd_decoder.pth";
    hash = "sha256-Aoczd8P0ZZzZ+a2y9xjctDS6THu6OvPue7lcvavi088=";
    installPath = "vae_approx";
  })
  (hf {
    name = "taesd_encoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesd_encoder.pth";
    hash = "sha256-FbxhKPCsUcZz00JyFgguv6YkAv/Il2OvdO3+JZsy1J0=";
    installPath = "vae_approx";
  })

  # SDXL
  (hf {
    name = "taesdxl_decoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesdxl_decoder.pth";
    hash = "sha256-o5Vrinp2PyUcc1eq1jddrNttlxEhxz6XowafwzqU/h4=";
    installPath = "vae_approx";
  })
  (hf {
    name = "taesdxl_encoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesdxl_encoder.pth";
    hash = "sha256-pWSN4ImrprZB5QXA8TKy3H/3CrYHDDG+XmJOgH5xHF4=";
    installPath = "vae_approx";
  })

  # SD3
  (hf {
    name = "taesd3_decoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesd3_decoder.pth";
    hash = "sha256-F4+7kMjDurT+XjDcujuF2L0smiA/cSOcOjIjcgwxC1g=";
    installPath = "vae_approx";
  })
  (hf {
    name = "taesd3_encoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesd3_encoder.pth";
    hash = "sha256-uP76ZLkqhn32c8fyL7LLxq4UQHDiLnoLOvDyHeL0P5I=";
    installPath = "vae_approx";
  })

  # FLUX.1
  (hf {
    name = "taef1_decoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taef1_decoder.pth";
    hash = "sha256-vq6G8u6vDOqITcj/5jn7KX2sjJhEQbtTQg8H12d4UQQ=";
    installPath = "vae_approx";
  })
  (hf {
    name = "taef1_encoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taef1_encoder.pth";
    hash = "sha256-HRrTRUauoO3ZncLblBHYcDGfQoztUGXGRkWCwXwHBTY=";
    installPath = "vae_approx";
  })

  # FLUX.2
  (hf {
    name = "taef2_decoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taef2_decoder.pth";
    hash = "sha256-CkSjHhrlnrnb+TWdJJQv0+9ZKBYsGADZeijGHVG+CrU=";
    installPath = "vae_approx";
  })
  (hf {
    name = "taef2_encoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taef2_encoder.pth";
    hash = "sha256-EKThAh6J11UerxYTUtqNvQsaqDhyriixUMHfHOLxR7Y=";
    installPath = "vae_approx";
  })

  # Wan 2.1
  (hf {
    name = "taew2_1.pth";
    url = "https://github.com/madebyollin/taehv/raw/main/taew2_1.pth";
    hash = "sha256-0mFR52zcLJQkvvmI3odLM9mlPzDvMGDNVWxCnEaceX4=";
    installPath = "vae_approx";
  })

  # Wan 2.2
  (hf {
    name = "taew2_2.pth";
    url = "https://github.com/madebyollin/taehv/raw/main/taew2_2.pth";
    hash = "sha256-0FPiFspQ4ruDe7zXm4XwNmvqAOWTgCVXI4Knc7dMVZo=";
    installPath = "vae_approx";
  })

  # LTX-2
  (hf {
    name = "taeltx_2.pth";
    url = "https://github.com/madebyollin/taehv/raw/main/taeltx_2.pth";
    hash = "sha256-AiawIHfPaTKbksV5GhHUHNI29QTRcSfKojrHAnDvF8E=";
    installPath = "vae_approx";
  })

  # LTX-2.3
  (hf {
    name = "taeltx2_3.pth";
    url = "https://github.com/madebyollin/taehv/raw/main/taeltx2_3.pth";
    hash = "sha256-8Bru38rCC5x6wszYJWcg7sVjgBXopEotD0p4h9Y76Vg=";
    installPath = "vae_approx";
  })

  # Sana
  (hf {
    name = "taesana_decoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesana_decoder.pth";
    hash = "sha256-Prczq5GN1YQPpuYwlkLttJNZvRx2JNnliE+SQ4qgfDY=";
    installPath = "vae_approx";
  })
  (hf {
    name = "taesana_encoder.pth";
    url = "https://github.com/madebyollin/taesd/raw/main/taesana_encoder.pth";
    hash = "sha256-hY9OTMKT+I769YEH9BVLlguc7Qy12cBQ2tEfkmthjB8=";
    installPath = "vae_approx";
  })
]
