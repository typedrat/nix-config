{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types genAttrs optional;
  cfg = config.rat.gaming.sunshine;

  # On-demand Hyprland headless output management. The headless output name
  # (HEADLESS-N) is not known until after creation, so this logic lives in a
  # script rather than inline hyprctl one-liners. Drives the prep-cmd hooks.
  #
  # Subcommands:
  #   create        - create+size headless output, move stream workspace to it
  #   destroy       - move stream workspace back, remove headless output
  #   create-steam  - create, then switch the existing Steam into Big Picture
  #   destroy-steam - exit Big Picture, then destroy
  #
  # Sunshine sets SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS in the prep-cmd environment.
  virtualDisplay = pkgs.writeShellApplication {
    name = "sunshine-virtual-display";
    runtimeInputs = with pkgs; [hyprland jq steam];
    text = ''
      set -euo pipefail

      STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/sunshine-virtual-display"
      mkdir -p "$STATE_DIR"
      NAME_FILE="$STATE_DIR/headless-name"

      WIDTH="''${SUNSHINE_CLIENT_WIDTH:-1920}"
      HEIGHT="''${SUNSHINE_CLIENT_HEIGHT:-1080}"
      FPS="''${SUNSHINE_CLIENT_FPS:-60}"

      STREAM_WS="stream"

      create_output() {
        # Snapshot existing headless outputs, create one, diff to find its name.
        before="$(hyprctl monitors -j | jq -r '.[].name' | grep '^HEADLESS-' || true)"
        hyprctl output create headless
        sleep 0.5
        after="$(hyprctl monitors -j | jq -r '.[].name' | grep '^HEADLESS-' || true)"
        name="$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) | head -n1)"
        if [ -z "$name" ]; then
          echo "sunshine-virtual-display: failed to determine new headless output name" >&2
          exit 1
        fi
        echo "$name" > "$NAME_FILE"

        # Size the headless output to the client's requested geometry.
        hyprctl keyword monitor "$name,''${WIDTH}x''${HEIGHT}@''${FPS},auto,1.0"

        # Move the dedicated streaming workspace onto the headless output and focus it.
        hyprctl dispatch moveworkspacetomonitor "$STREAM_WS" "$name"
        hyprctl dispatch workspace "$STREAM_WS"
      }

      destroy_output() {
        # Move the streaming workspace back to the primary monitor, then remove.
        primary="$(hyprctl monitors -j | jq -r '.[] | select(.name | startswith("HEADLESS-") | not) | .name' | head -n1)"
        if [ -n "$primary" ]; then
          hyprctl dispatch moveworkspacetomonitor "$STREAM_WS" "$primary" || true
        fi
        if [ -f "$NAME_FILE" ]; then
          name="$(cat "$NAME_FILE")"
          hyprctl output remove "$name" || true
          rm -f "$NAME_FILE"
        fi
      }

      case "''${1:-}" in
        create)
          create_output
          ;;
        destroy)
          destroy_output
          ;;
        create-steam)
          create_output
          steam steam://open/bigpicture >/dev/null 2>&1 || true
          ;;
        destroy-steam)
          steam steam://close/bigpicture >/dev/null 2>&1 || true
          sleep 0.5
          destroy_output
          ;;
        *)
          echo "usage: sunshine-virtual-display {create|destroy|create-steam|destroy-steam}" >&2
          exit 1
          ;;
      esac
    '';
  };
in {
  options.rat.gaming.sunshine = {
    enable = mkEnableOption "Sunshine game streaming host";

    users = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["awilliams"];
      description = ''
        Users permitted to use Sunshine. Each listed user is added to the
        `uinput` group (so Moonlight clients can inject gamepad, keyboard, and
        mouse input via /dev/uinput) and the `sunshine` group (so they can read
        the credentials_file).
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the LAN firewall ports Sunshine/Moonlight require.";
    };
  };

  config = mkIf (config.rat.gaming.enable && cfg.enable) {
    # Dedicated group for credential-file access (distinct from uinput, even
    # though the user set overlaps today — credential access != input access).
    users.groups.sunshine = {};

    # Grant each permitted user uinput access (input injection) and sunshine
    # group membership (credentials_file read).
    users.users = genAttrs cfg.users (_: {
      extraGroups = ["uinput" "sunshine"];
    });

    # SOPS-decrypted hashed credential JSON, group-readable, in /run (tmpfs).
    # Path defaults to /run/secrets/sunshine/credentials.
    sops.secrets."sunshine/credentials" = {
      sopsFile = ../../../secrets/sunshine.yaml;
      mode = "0440";
      group = "sunshine";
    };

    # Non-fatal guard: Sunshine still streams video without input injection,
    # but Moonlight gamepad/keyboard/mouse will silently fail.
    warnings = optional (cfg.users == []) ''
      rat.gaming.sunshine is enabled but `users` is empty. No user has been
      added to the `uinput`/`sunshine` groups, so Moonlight input injection
      and credential-file access will not work. Set
      `rat.gaming.sunshine.users = [ "<username>" ];`.
    '';
  };
}
