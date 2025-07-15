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

        makeWrapperFlags = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [calculix-ccx gmsh netgen])
        ];
      })
      calculix-ccx
      gmsh
      netgen
    ];
  };
}
