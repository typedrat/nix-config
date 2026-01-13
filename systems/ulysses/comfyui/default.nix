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
    acceleration = "cuda";
    enableSageAttention = true;
    disableApiNodes = true;

    models = allModels;

    customNodes = with pkgs.comfyuiPackages; [
      comfyui-automatic-cfg
      comfyui-gguf
      comfyui-essentials
      comfyui-impact-pack
      comfyui-impact-subpack
      comfyui-kjnodes
      comfyui-pythongosssss-custom-scripts
      comfyui-res4lyf
      comfyui-rgthree

      # Required for krita-ai-diffusion
      comfyui-controlnet-preprocessors
      comfyui-ip-adapter
      comfyui-inpaint
      comfyui-external-tooling

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
