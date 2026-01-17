{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.comfyui;
  impermanenceCfg = config.rat.impermanence;
in {
  imports = [
    inputs.nixified-ai.nixosModules.comfyui
  ];

  options.rat.services.comfyui = {
    enable = options.mkEnableOption "ComfyUI";

    autoStart = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically start ComfyUI at boot. If false, the service is configured but must be started manually.";
    };

    subdomain = options.mkOption {
      type = types.str;
      default = "comfyui";
      description = "The subdomain for ComfyUI.";
    };

    acceleration = options.mkOption {
      type = types.nullOr (types.enum [false "cuda" "rocm"]);
      default = null;
      description = ''
        GPU acceleration mode.
        - null: auto-detect
        - false: CPU only
        - "cuda": NVIDIA GPU
        - "rocm": AMD GPU
      '';
    };

    rocmOverrideGfx = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Override ROCm GPU detection. Useful for unsupported AMD GPUs.
        Example: "10.3.0" for gfx1030 (RX 6800/6900 series).
      '';
    };

    enableManager = options.mkOption {
      type = types.bool;
      default = false;
      description = "Enable the ComfyUI Manager for installing custom nodes and models.";
    };

    disableApiNodes = options.mkOption {
      type = types.bool;
      default = false;
      description = "Disable API nodes to prevent external API access.";
    };

    enableSageAttention = options.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable SageAttention for faster attention computation.
        Requires CUDA acceleration. Automatically includes the kijai-wan-video-wrapper custom node.
      '';
    };

    models = options.mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Model definitions to fetch and provision.";
      example = lib.literalExpression ''
        [
          {
            name = "v1-5-pruned-emaonly.safetensors";
            type = "checkpoints";
            url = "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors";
            sha256 = "...";
          }
        ]
      '';
    };

    customNodes = options.mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Custom nodes to install.";
    };

    extraFlags = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional CLI arguments passed to ComfyUI.";
    };

    environmentVariables = options.mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional environment variables for the ComfyUI service.";
    };

    openFirewall = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for the ComfyUI port.";
    };

    authentik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to require Authentik authentication.";
    };
  };

  config = let
    managerFlags = lib.optional cfg.enableManager "--enable-manager";
    apiNodeFlags = lib.optional cfg.disableApiNodes "--disable-api-nodes";
    sageAttentionFlags = lib.optional cfg.enableSageAttention "--use-sage-attention";
    baseDirFlags = ["--base-directory" config.services.comfyui.home];
    allExtraFlags =
      managerFlags
      ++ apiNodeFlags
      ++ sageAttentionFlags
      ++ baseDirFlags
      ++ cfg.extraFlags;

    sageAttentionNodes = lib.optional cfg.enableSageAttention pkgs.comfyuiPackages.comfyui-kijai-wan-video-wrapper;
    allCustomNodes = sageAttentionNodes ++ cfg.customNodes;
  in
    modules.mkMerge [
      (modules.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.enableSageAttention -> cfg.acceleration == "cuda";
            message = "rat.services.comfyui.enableSageAttention requires acceleration to be set to \"cuda\"";
          }
        ];

        services.comfyui = {
          enable = true;
          host = "127.0.0.1";
          inherit (config.links.comfyui) port;
          inherit (cfg) acceleration rocmOverrideGfx;
          inherit (cfg) models;
          inherit (cfg) environmentVariables openFirewall;
          extraFlags = allExtraFlags;
          customNodes = allCustomNodes;
        };

        # Create model directories with setgid bit so files inherit group ownership
        systemd.tmpfiles.rules = let
          inherit (config.services.comfyui) home;
          modelDirs = [
            "audio_encoders"
            "checkpoints"
            "classifiers"
            "clip_gguf"
            "clip_vision"
            "controlnet"
            "diffusers"
            "diffusion_models"
            "embeddings"
            "gligen"
            "hypernetworks"
            "inpaint"
            "intrinsic_loras"
            "ipadapter"
            "kjnodes_fonts"
            "latent_upscale_models"
            "loras"
            "luts"
            "mmaudio"
            "model_patches"
            "nlf"
            "onnx"
            "photomaker"
            "sams"
            "style_models"
            "text_encoders"
            "ultralytics"
            "ultralytics_bbox"
            "ultralytics_segm"
            "unet_gguf"
            "upscale_models"
            "vae"
            "vae_approx"
            "wav2vec2"
          ];
        in
          [
            "d ${home}/custom_nodes 2770 comfyui comfyui -"
            "d ${home}/input 2770 comfyui comfyui -"
            "d ${home}/models 2770 comfyui comfyui -"
            "d ${home}/output 2770 comfyui comfyui -"
          ]
          ++ map (dir: "d ${home}/models/${dir} 2770 comfyui comfyui -") modelDirs;

        links.comfyui = {
          protocol = "http";
          port = 8188;
        };

        rat.services.traefik.routes.comfyui = {
          enable = true;
          inherit (cfg) subdomain;
          serviceUrl = config.links.comfyui.url;
          inherit (cfg) authentik;
        };
      })
      (modules.mkIf (cfg.enable && !cfg.autoStart) {
        systemd.services.comfyui.wantedBy = lib.mkForce [];
      })
      (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
        services.comfyui = {
          user = "comfyui";
          group = "comfyui";
        };

        users.users.comfyui = {
          isSystemUser = true;
          group = "comfyui";
          inherit (config.services.comfyui) home;
        };

        users.groups.comfyui = {};

        systemd.services.comfyui.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "comfyui";
          Group = "comfyui";
        };

        environment.persistence.${impermanenceCfg.persistDir} = {
          directories = [
            {
              directory = config.services.comfyui.home;
              user = "comfyui";
              group = "comfyui";
            }
          ];
        };
      })
    ];
}
