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
in {
  config = mkIf (guiCfg.enable && productivityCfg.enable && productivityCfg.freecad.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/FreeCAD" ".local/share/FreeCAD"];
    };

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
