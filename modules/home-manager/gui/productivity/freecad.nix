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
in {
  config = mkIf ((guiCfg.enable or false) && (productivityCfg.enable or false) && (productivityCfg.freecad.enable or false)) {
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
