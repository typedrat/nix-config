{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
    home.packages = with pkgs; [
      (freecad.customize {
        pythons = [
          (ps:
            with ps; [
              networkx
            ])
        ];

        # https://github.com/NixOS/nixpkgs/issues/468456
        makeWrapperFlags = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [calculix-ccx gmsh netgen])
          "--prefix"
          "MESA_LOADER_DRIVER_OVERRIDE"
          ":"
          "zink"
          "--prefix"
          "__EGL_VENDOR_LIBRARY_FILENAMES"
          ":"
          "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
        ];
      })
      calculix-ccx
      gmsh
      netgen
    ];
  };
}
