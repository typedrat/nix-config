{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  # https://github.com/NixOS/nixpkgs/issues/468456
  orca-slicer-wrapped = pkgs.symlinkJoin {
    name = "orca-slicer-wrapped";
    paths = [pkgs.orca-slicer];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/orca-slicer \
        --prefix MESA_LOADER_DRIVER_OVERRIDE : zink \
        --prefix __EGL_VENDOR_LIBRARY_FILENAMES : ${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
    '';
  };
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
    home.packages = [
      orca-slicer-wrapped
    ];
  };
}
