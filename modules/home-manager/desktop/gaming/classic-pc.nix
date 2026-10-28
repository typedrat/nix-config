{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  gamingCfg = guiCfg.gaming or {};
  classicPCCfg = gamingCfg.classicPC or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  tankRoot =
    if impermanenceCfg.tank.enable
    then impermanenceCfg.tankDir
    else persistDir;
in {
  config = modules.mkIf (guiCfg.enable && classicPCCfg.enable) {
    home.packages = [
      # The ROM set lands in share/86Box/roms, which 86Box finds through
      # XDG_DATA_DIRS, so a persisted $XDG_DATA_HOME/86Box doesn't shadow it.
      (pkgs._86box.override {
        unfreeEnableDiscord = true;
        unfreeEnableRoms = true;
      })
    ];

    home.persistence = modules.mkIf impermanenceCfg.home.enable (modules.mkMerge [
      {
        # 86box_global.cfg and the VM manager's settings
        ${persistDir}.directories = [".config/86Box"];
      }
      {
        # "Virtual Machines", whose hard disk images get large
        ${tankRoot}.directories = [".local/share/86Box"];
      }
    ]);
  };
}
