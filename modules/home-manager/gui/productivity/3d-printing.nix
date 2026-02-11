{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  orca-slicer-wrapped = pkgs.symlinkJoin {
    name = "orca-slicer-wrapped";
    paths = [pkgs.orca-slicer];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      # workaround from NixOS/nixpkgs#468456
      wrapProgram $out/bin/orca-slicer \
      --prefix __GLX_VENDOR_LIBRARY_NAME : mesa \
      --prefix __EGL_VENDOR_LIBRARY_FILENAMES : ${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json \
      --prefix MESA_LOADER_DRIVER_OVERRIDE : zink \
      --prefix GALLIUM_DRIVER : zink \
      --prefix LIBGL_KOPPER_DRI2 : 1 \
    '';
  };
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
    home.packages = [
      orca-slicer-wrapped
    ];
  };
}
