{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types genAttrs optional optionalAttrs;
  cfg = config.rat.gaming.sunshine;

  # On client connect: open Steam Big Picture and move its window onto the
  # `stream` workspace (which the home-manager session pins to the headless
  # output Sunshine captures). We move the window imperatively via hyprctl
  # rather than a Hyprland windowrule, because rules matching class:steam can
  # thrash the compositor. The Big Picture window is class=steam,
  # title="Steam Big Picture Mode".
  connectScript = pkgs.writeShellApplication {
    name = "sunshine-connect";
    runtimeInputs = with pkgs; [hyprland jq steam];
    text = ''
      set -euo pipefail

      # Ensure Steam is running (cold start), then request Big Picture.
      if ! pgrep -x steam >/dev/null 2>&1; then
        steam -silent >/dev/null 2>&1 &
        # Wait for Steam to come up before asking for Big Picture.
        for _ in $(seq 1 30); do
          pgrep -x steam >/dev/null 2>&1 && break
          sleep 1
        done
      fi

      steam steam://open/bigpicture >/dev/null 2>&1 || true

      # Poll for the Big Picture window and move it to the stream workspace.
      for _ in $(seq 1 20); do
        addr="$(hyprctl clients -j \
          | jq -r '.[] | select(.class == "steam" and .title == "Steam Big Picture Mode") | .address' \
          | head -n1)"
        if [ -n "$addr" ]; then
          hyprctl dispatch movetoworkspacesilent "name:stream,address:$addr"
          exit 0
        fi
        sleep 0.5
      done

      echo "sunshine-connect: Big Picture window not found within timeout" >&2
    '';
  };

  # On client disconnect: leave Big Picture (returns the shared Steam instance
  # to its normal desktop state).
  disconnectScript = pkgs.writeShellApplication {
    name = "sunshine-disconnect";
    runtimeInputs = with pkgs; [steam];
    text = ''
      set -euo pipefail
      steam steam://close/bigpicture >/dev/null 2>&1 || true
    '';
  };

  # Sunshine global_prep_cmd value: run on every stream connect/disconnect.
  globalPrepCmd = builtins.toJSON [
    {
      do = "${connectScript}/bin/sunshine-connect";
      undo = "${disconnectScript}/bin/sunshine-disconnect";
      elevated = false;
    }
  ];
in {
  options.rat.gaming.sunshine = {
    enable = mkEnableOption "Sunshine game streaming host";

    users = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["awilliams"];
      description = ''
        Users permitted to use Sunshine. Each listed user is added to the
        `uinput` group so Moonlight clients can inject gamepad, keyboard, and
        mouse input via /dev/uinput.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the LAN firewall ports Sunshine/Moonlight require.";
    };

    encoder = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "nvenc";
      description = ''
        Video encoder Sunshine should use (e.g. "nvenc" for NVIDIA, "vaapi"
        for AMD/Intel). GPU-specific, so set per-host. When `null`, Sunshine
        autodetects.
      '';
    };

    headlessName = mkOption {
      type = types.str;
      default = "sunshine";
      description = ''
        Name of the dedicated headless Hyprland output created for streaming.
        A game/Big Picture runs on this virtual display so the physical
        monitors keep showing your normal work. The home-manager session
        creates `hyprctl output create headless <name>` at login and Sunshine
        captures it via `output_name`.
      '';
    };
  };

  config = mkIf (config.rat.gaming.enable && cfg.enable) {
    # Grant each permitted user uinput access for Moonlight input injection.
    users.users = genAttrs cfg.users (_: {
      extraGroups = ["uinput"];
    });

    services.sunshine = {
      enable = true;
      # Started by the Hyprland session (home-manager exec-once) AFTER the
      # headless output exists, because Sunshine's wlr backend resolves
      # output_name when it starts. autoStart would race the headless.
      autoStart = false;
      capSysAdmin = true; # required for KMS/DRM screen capture on Wayland
      inherit (cfg) openFirewall;

      # Declarative base settings rendered into the (read-only) store config.
      # Web-UI admin credentials live separately in ~/.config/sunshine/
      # sunshine_state.json (persisted via the home-manager module), so making
      # these settings Nix-managed does not interfere with login.
      #
      # output_name is the deterministic headless name (created by the
      # home-manager session), so it can be static here — no runtime rewriting.
      settings =
        {
          sunshine_name = config.networking.hostName;
          # wlroots screen-copy backend: required to capture a Hyprland output.
          capture = "wlr";
          output_name = cfg.headlessName;
          # On connect, open Steam Big Picture on the stream workspace; on
          # disconnect, close it.
          global_prep_cmd = globalPrepCmd;
        }
        // optionalAttrs (cfg.encoder != null) {
          inherit (cfg) encoder;
        };
    };

    # Non-fatal guard: Sunshine still streams video without input injection,
    # but Moonlight gamepad/keyboard/mouse will silently fail.
    warnings = optional (cfg.users == []) ''
      rat.gaming.sunshine is enabled but `users` is empty. No user has been
      added to the `uinput` group, so Moonlight input injection will not work.
      Set `rat.gaming.sunshine.users = [ "<username>" ];`.
    '';
  };
}
