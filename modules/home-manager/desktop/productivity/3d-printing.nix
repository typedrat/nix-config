{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # WebKitGTK's DMA-BUF renderer kills the whole app with a Wayland protocol
  # error (71) on the NVIDIA driver as soon as the embedded web view opens.
  orca-slicer = pkgs.symlinkJoin {
    name = "orca-slicer-wrapped";
    paths = [pkgs.orca-slicer];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/orca-slicer --set WEBKIT_DISABLE_DMABUF_RENDERER 1
    '';
    inherit (pkgs.orca-slicer) meta;
  };
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/OrcaSlicer" ".local/share/orca-slicer"];
    };

    home.packages = [
      orca-slicer
    ];
  };
}
