{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Enable autoHideMenuBar on the main window to hide the GTK menu bar
  # decoration on Linux (press Alt to reveal). Upstream PR:
  # https://github.com/anomalyco/opencode/pull/17243
  opencode-desktop = pkgs.opencode-desktop.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace packages/desktop/src/main/windows.ts \
          --replace-fail $'    height: state.height,\n    show:' $'    height: state.height,\n    autoHideMenuBar: true,\n    show:'
      '';
  });
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/Claude"];
    };

    home.packages = [
      # inputs'.claude-desktop-debian.packages.claude-desktop
      opencode-desktop
    ];
  };
}
