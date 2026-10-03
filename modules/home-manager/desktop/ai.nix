{
  osConfig,
  inputs,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Enable autoHideMenuBar on the main window to hide the GTK menu bar
  # decoration on Linux (press Alt to reveal).
  opencode-desktop = pkgs.opencode-desktop.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace packages/desktop/src/main/windows.ts \
          --replace-fail $'    height: state.height,\n    show:' $'    height: state.height,\n    autoHideMenuBar: true,\n    show:'
      '';
  });
in {
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/Claude"];
    };

    # A custom feature set: this builds codex-desktop locally rather than
    # pulling the prebuilt default from codex-desktop-linux.cachix.org.
    programs.codexDesktopLinux = {
      enable = true;

      # Agentic desktop control (native Hyprland windowing backend).
      computerUseUi.enable = true;

      # Experimental "drive this desktop from ChatGPT mobile" support. Desktop
      # runs its own `codex app-server --remote-control`, so phones can only
      # reach this machine while the app is open.
      #
      # remoteControl.enable (a systemd-owned app-server) must stay off: it
      # puts Desktop in proxy mode, where `codex app-server proxy` pipes raw
      # JSON-RPC into a control socket that only speaks WebSocket. The server
      # drops the connection, `initialize` never answers, and Desktop sits on
      # launch without ever opening a window.
      remoteMobileControl.enable = true;

      linuxFeatures = [
        "appshots"
        "frameless-titlebar"
        "mcp-helper-reaper"
        "node-repl-reaper"
        "persistent-status-panel"
        "pet-overlay"
      ];
    };

    home.packages = [
      inputs'.claude-desktop-debian.packages.claude-desktop
      opencode-desktop
    ];
  };
}
