{
  config,
  osConfig,
  inputs,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  codexDesktop = let
    selection = import "${inputs.codex-desktop-linux}/nix/package-selection.nix" {
      cfg = config.programs.codexDesktopLinux // {package = null;};
      inherit lib;
      flakePackages = inputs'.codex-desktop-linux.packages;
    };
  in
    selection.package;

  # The CLI inside the configured Desktop build. The remote-control service
  # runs this same binary, so Desktop and the service share a protocol version.
  bundledCodex = "${codexDesktop}/opt/codex-desktop/resources/codex";

  codexWsProxy = pkgs.writers.writePython3Bin "codex-app-server-ws-proxy" {
    libraries = [pkgs.python3Packages.websockets];
  } (builtins.readFile ./app-server-ws-proxy.py);

  # Desktop's CLI: `app-server proxy` goes through the WebSocket bridge, since
  # the stock proxy can't talk to the control socket; everything else is the
  # bundled CLI untouched.
  codexDesktopCli = pkgs.writeShellApplication {
    name = "codex";
    text = ''
      # Desktop invokes `codex [-c key=value]... app-server proxy [--sock PATH]`.
      args=("$@")
      for ((i = 0; i + 1 < ''${#args[@]}; i++)); do
        if [[ ''${args[i]} == app-server && ''${args[i + 1]} == proxy ]]; then
          sock="''${CODEX_HOME:-$HOME/.codex}/app-server-control/app-server-control.sock"
          for ((j = i + 2; j < ''${#args[@]}; j++)); do
            case ''${args[j]} in
              --sock) sock=''${args[j + 1]}; j=$((j + 1)) ;;
              --sock=*) sock=''${args[j]#--sock=} ;;
            esac
          done
          exec ${lib.getExe codexWsProxy} "$sock"
        fi
      done
      exec ${bundledCodex} "$@"
    '';
  };
in {
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.chat.enable) {
    # A custom feature set: this builds codex-desktop locally rather than
    # pulling the prebuilt default from codex-desktop-linux.cachix.org.
    programs.codexDesktopLinux = {
      enable = true;
      package = codexDesktop;

      # Agentic desktop control (native Hyprland windowing backend).
      computerUseUi.enable = true;

      # Experimental "drive this desktop from ChatGPT mobile" support, with
      # the app-server owned by a systemd user service so phones can reach
      # this machine even while Desktop is closed. Desktop then reaches the
      # service through `codex app-server proxy`, which cliPackage reroutes.
      remoteMobileControl.enable = true;
      remoteControl.enable = true;
      cliPackage = codexDesktopCli;

      linuxFeatures = [
        "appshots"
        "frameless-titlebar"
        "mcp-helper-reaper"
        "node-repl-reaper"
        "persistent-status-panel"
        "pet-overlay"
      ];
    };
  };
}
