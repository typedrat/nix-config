{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.home) username;
  sunshineCfg = osConfig.rat.gaming.sunshine or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
  headlessName = sunshineCfg.headlessName or "sunshine";

  enabled =
    (sunshineCfg.enable or false)
    && builtins.elem username (sunshineCfg.users or []);

  # Create the dedicated headless streaming output at session start, pin a
  # `stream` workspace to it (so it never absorbs normal windows), then start
  # Sunshine. Sunshine resolves output_name when it starts, so it must launch
  # only after the headless exists — hence services.sunshine.autoStart = false
  # and this explicit start.
  startScript = pkgs.writeShellApplication {
    name = "sunshine-headless-start";
    runtimeInputs = with pkgs; [hyprland jq systemd];
    text = ''
      set -euo pipefail

      NAME=${lib.escapeShellArg headlessName}

      # Remove any stale headless outputs from a previous session, then create
      # ours with a deterministic name.
      while read -r m; do
        [ -n "$m" ] && hyprctl output remove "$m" || true
      done < <(hyprctl monitors -j | jq -r '.[] | select(.name == "'"$NAME"'") | .name')

      hyprctl output create headless "$NAME"
      sleep 0.5

      # Off-screen position so the cursor can't wander onto it; 1080p60.
      hyprctl keyword monitor "$NAME,1920x1080@60,9999x0,1"

      # Dedicate a `stream` workspace to the headless output and keep it there.
      hyprctl keyword workspace "name:stream, monitor:$NAME, default:true, persistent:true"

      # Now that the headless exists, start Sunshine (it caches output_name).
      systemctl --user start sunshine.service
    '';
  };
in {
  config = mkIf enabled (mkMerge [
    {
      # Run the headless setup + Sunshine launch once the graphical session is up.
      wayland.windowManager.hyprland.settings.exec-once = [
        "${startScript}/bin/sunshine-headless-start"
      ];
    }
    (mkIf impermanenceCfg.home.enable {
      # Sunshine stores web-UI credentials + paired-client state here; persist
      # so they survive reboots under impermanence.
      home.persistence.${persistDir}.directories = [".config/sunshine"];
    })
  ]);
}
