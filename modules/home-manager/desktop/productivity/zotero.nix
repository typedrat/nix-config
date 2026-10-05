{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  productivityCfg = guiCfg.productivity or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && productivityCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".zotero"];
    };

    # Zotero 10 needs Firefox ESR 140, which nixpkgs dropped, and fails to
    # build against ESR 153 (NixOS/nixpkgs#568692). Restore once
    # NixOS/nixpkgs#569006 is merged and cached:
    #   home.packages = [pkgs.zotero];
  };
}
