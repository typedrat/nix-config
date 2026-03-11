{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  productivityCfg = guiCfg.productivity or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # FreeCAD doesn't build with boost 1.89+; pin to 1.87
  freecad' = pkgs.freecad.override {
    python3Packages =
      pkgs.python3Packages
      // {
        boost = pkgs.python3Packages.toPythonModule (pkgs.boost187.override {
          inherit (pkgs.python3Packages) python numpy;
          enablePython = true;
        });
      };
  };
in {
  config = mkIf (guiCfg.enable && productivityCfg.enable && productivityCfg.freecad.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/FreeCAD" ".local/share/FreeCAD"];
    };

    home.packages = with pkgs; [
      (freecad'.customize {
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
