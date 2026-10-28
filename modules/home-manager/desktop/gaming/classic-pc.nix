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
      # The ROMs and assets land under share/86Box, which 86Box finds through
      # XDG_DATA_DIRS, so a persisted $XDG_DATA_HOME/86Box doesn't shadow them.
      osConfig.rat.gaming.classicPC.package
    ];

    # Replaces the package's own entry so launching from the desktop goes
    # through the capability wrapper, which TAP networking needs.
    xdg.desktopEntries."net.86box.86Box" = {
      name = "86Box";
      genericName = "Classic PC emulator";
      comment = "An emulator for classic IBM PC clones";
      exec = "${osConfig.security.wrapperDir}/86Box";
      icon = "net.86box.86Box";
      categories = ["System" "Emulator"];
      terminal = false;
      type = "Application";
    };

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
