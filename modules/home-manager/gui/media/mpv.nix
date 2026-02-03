{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  # Anime4K shader path - shaders are in package root with Anime4K_ prefix
  inherit (pkgs) anime4k;

  # Shader profiles for different quality modes (UL = Ultra Large, max quality for high-end GPUs)
  # See: https://github.com/bloc97/Anime4K/blob/master/GLSL_Instructions.md
  shaderProfiles = {
    # Mode A - Optimized for most anime
    modeA = builtins.concatStringsSep ":" [
      "${anime4k}/Anime4K_Clamp_Highlights.glsl"
      "${anime4k}/Anime4K_Restore_CNN_UL.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_UL.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x2.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x4.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl"
    ];

    # Mode B - Better for some anime with thinner lines
    modeB = builtins.concatStringsSep ":" [
      "${anime4k}/Anime4K_Clamp_Highlights.glsl"
      "${anime4k}/Anime4K_Restore_CNN_Soft_UL.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_UL.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x2.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x4.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl"
    ];

    # Mode C - For older anime with softer lines
    modeC = builtins.concatStringsSep ":" [
      "${anime4k}/Anime4K_Clamp_Highlights.glsl"
      "${anime4k}/Anime4K_Upscale_Denoise_CNN_x2_UL.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x2.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x4.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl"
    ];

    # Mode A+A - Higher quality (more GPU intensive)
    modeAA = builtins.concatStringsSep ":" [
      "${anime4k}/Anime4K_Clamp_Highlights.glsl"
      "${anime4k}/Anime4K_Restore_CNN_UL.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_UL.glsl"
      "${anime4k}/Anime4K_Restore_CNN_VL.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x2.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x4.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl"
    ];

    # Mode B+B - Higher quality variant of Mode B
    modeBB = builtins.concatStringsSep ":" [
      "${anime4k}/Anime4K_Clamp_Highlights.glsl"
      "${anime4k}/Anime4K_Restore_CNN_Soft_UL.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_UL.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x2.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x4.glsl"
      "${anime4k}/Anime4K_Restore_CNN_Soft_VL.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl"
    ];

    # Mode C+A - Higher quality variant of Mode C
    modeCA = builtins.concatStringsSep ":" [
      "${anime4k}/Anime4K_Clamp_Highlights.glsl"
      "${anime4k}/Anime4K_Upscale_Denoise_CNN_x2_UL.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x2.glsl"
      "${anime4k}/Anime4K_AutoDownscalePre_x4.glsl"
      "${anime4k}/Anime4K_Restore_CNN_VL.glsl"
      "${anime4k}/Anime4K_Upscale_CNN_x2_VL.glsl"
    ];
  };
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.media.enable) {
    programs.mpv = {
      enable = true;

      package = pkgs.mpv.override {
        mpv-unwrapped = pkgs.mpv-unwrapped.override {
          vapoursynthSupport = true;
        };
        scripts = with pkgs.mpvScripts; [
          mpris
          mpv-discord
          sponsorblock
          thumbfast
          uosc
        ];
      };

      config = {
        osd-bar = false;
        border = false;
        video-sync = "display-resample";
      };

      bindings = {
        # Anime4K shader profiles
        # CTRL+1: Mode A (optimized for most anime)
        "CTRL+1" = ''change-list glsl-shaders set "${shaderProfiles.modeA}"; show-text "Anime4K: Mode A"'';
        # CTRL+2: Mode B (for anime with thinner lines)
        "CTRL+2" = ''change-list glsl-shaders set "${shaderProfiles.modeB}"; show-text "Anime4K: Mode B"'';
        # CTRL+3: Mode C (for older anime)
        "CTRL+3" = ''change-list glsl-shaders set "${shaderProfiles.modeC}"; show-text "Anime4K: Mode C"'';
        # CTRL+4: Mode A+A (higher quality)
        "CTRL+4" = ''change-list glsl-shaders set "${shaderProfiles.modeAA}"; show-text "Anime4K: Mode A+A"'';
        # CTRL+5: Mode B+B (higher quality)
        "CTRL+5" = ''change-list glsl-shaders set "${shaderProfiles.modeBB}"; show-text "Anime4K: Mode B+B"'';
        # CTRL+6: Mode C+A (higher quality)
        "CTRL+6" = ''change-list glsl-shaders set "${shaderProfiles.modeCA}"; show-text "Anime4K: Mode C+A"'';
        # CTRL+0: Clear shaders
        "CTRL+0" = ''change-list glsl-shaders clr ""; show-text "Shaders cleared"'';
      };
    };
  };
}
