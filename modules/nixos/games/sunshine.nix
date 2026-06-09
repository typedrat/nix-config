{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types genAttrs optional optionalAttrs;
  cfg = config.rat.gaming.sunshine;
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
