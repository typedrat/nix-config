{
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs) fetchResource fetchair;
  inherit (pkgs.nixified-ai) models;

  # Helper to create model derivation with comfyui install path
  hf = {
    name,
    url,
    hash,
    installPath,
  }:
    fetchResource {
      inherit name url hash;
      passthru.comfyui.installPaths = [installPath];
    };

  # Helper for CivitAI models using AIR URN
  civitai = {
    name,
    air,
    sha256,
    installPath,
  }:
    fetchair {
      inherit name air sha256;
      passthru.comfyui.installPaths = [installPath];
    };

  # Recursively collect all .nix files from ./models/ subdirectories
  collectModels = dir: let
    contents = builtins.readDir dir;
    nixFiles = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) contents;
    subDirs = lib.filterAttrs (_n: v: v == "directory") contents;
    modelLists =
      lib.mapAttrsToList (
        name: _:
          import (dir + "/${name}") {inherit hf civitai models;}
      )
      nixFiles;
    subDirModels =
      lib.mapAttrsToList (
        name: _:
          collectModels (dir + "/${name}")
      )
      subDirs;
  in
    lib.flatten (modelLists ++ subDirModels);

  allModels = collectModels ./models;
in {
  rat.services.comfyui = {
    enable = true;
    autoStart = false;

    acceleration = "cuda";
    enableSageAttention = false;
    disableApiNodes = true;
    extraFlags = [
      "--preview-method"
      "taesd"
    ];

    models = allModels;

    customNodes = with pkgs.comfyuiPackages; [
      comfyui-automatic-cfg
      comfyui-essentials
      comfyui-impact-pack
      comfyui-impact-subpack
      comfyui-pythongosssss-custom-scripts
      comfyui-res4lyf
      comfyui-rgthree

      # Overridden for LTX-2 support
      (pkgs.comfyuiLib.mkComfyUICustomNode {
        pname = "comfyui-gguf";
        version = "unstable-2026-01-12";
        src = pkgs.fetchFromGitHub {
          owner = "city96";
          repo = "ComfyUI-GGUF";
          rev = "6ea2651e7df66d7585f6ffee804b20e92fb38b8a";
          hash = "sha256-/ZwecgxTTMo9J1whdEJci8lEkOy/yP+UmjbpOAA3BvU=";
        };
      })
      (pkgs.comfyuiLib.mkComfyUICustomNode {
        pname = "comfyui-kjnodes";
        version = "unstable-2026-01-24";
        src = pkgs.fetchFromGitHub {
          owner = "kijai";
          repo = "ComfyUI-KJNodes";
          rev = "f91daf93293ab7fb28836159595a5b088c86313a";
          hash = "sha256-V0bw/osQAfc2i3AMnt7vypTA6+paJ/rdvVxfE9nXe6Y=";
        };
      })
      (pkgs.comfyuiLib.mkComfyUICustomNode {
        pname = "comfyui-ltxvideo";
        version = "unstable-2026-01-15";
        src = pkgs.fetchFromGitHub {
          owner = "Lightricks";
          repo = "ComfyUI-LTXVideo";
          rev = "cd5d371518afb07d6b3641be8012f644f25269fc";
          hash = "sha256-VR7NRuTsSDC0MTHAArBkWtTmdb2ZEIOjz/ikxhy4msY=";
        };
      })

      # Required for krita-ai-diffusion
      comfyui-controlnet-preprocessors
      comfyui-ip-adapter
      comfyui-inpaint
      comfyui-external-tooling

      (pkgs.comfyuiLib.mkComfyUICustomNode {
        pname = "comfyui-inpaint-cropandstitch";
        version = "unstable-2026-01-16";
        src = pkgs.fetchFromGitHub {
          owner = "lquesada";
          repo = "ComfyUI-Inpaint-CropAndStitch";
          rev = "3551c8c361746f8d48bcdd45aa39c3db19d9939a";
          hash = "sha256-W+j+Z1VG/RMVg3N2XxM1MIt5kxHVMEy3pyX0W5NJqPk=";
        };
      })

      (pkgs.comfyuiLib.mkComfyUICustomNode {
        pname = "comfyui-prompt-control";
        version = "unstable-2025-01-06";
        propagatedBuildInputs = with pkgs.python3Packages; [lark];
        src = pkgs.fetchFromGitHub {
          owner = "asagi4";
          repo = "comfyui-prompt-control";
          rev = "a0ab709f50c973eaec8d85675cc8042b07427000";
          hash = "sha256-YM+F5Ac4/2FM/YMESCXRcucDPhqBa4wxC0+e2PZ/e98=";
        };
        dontBuild = true;
      })
      (pkgs.comfyuiLib.mkComfyUICustomNode {
        pname = "comfyui-ppm";
        version = "unstable-2025-01-04";
        src = pkgs.fetchFromGitHub {
          owner = "pamparamm";
          repo = "ComfyUI-ppm";
          rev = "b06bf846bcfcad52a5ab9b08da94cce73808676b";
          hash = "sha256-vAAmMizw7Q8phmJYSa9o7t0hlNNBDgtyhswueqHcXz4=";
        };
      })
    ];
  };
}
