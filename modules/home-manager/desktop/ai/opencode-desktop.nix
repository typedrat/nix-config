{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  # Enable autoHideMenuBar on the main window to hide the GTK menu bar
  # decoration on Linux (press Alt to reveal).
  opencode-desktop = pkgs.opencode-desktop.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace packages/desktop/src/main/windows/index.ts \
          --replace-fail $'        height: state.height,\n        show:' $'        height: state.height,\n        autoHideMenuBar: true,\n        show:'
      '';
  });
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.packages = [opencode-desktop];
  };
}
