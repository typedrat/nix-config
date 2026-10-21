{
  config,
  osConfig,
  pkgs,
  lib,
  hlLib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (hlLib) execOnce parseMonitor parseWorkspace;
  toLua = lib.generators.toLua {multiline = false;};
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

      # `hyprctl keyword` is gone under configType = "lua"; rules are applied by
      # evaluating the same hl.* calls the config uses. Like dispatch, eval
      # exits 0 and reports failure only on stdout.
      eval_lua() {
        local out
        out=$(hyprctl eval "$1")
        if [ "$out" != ok ]; then
          printf 'sunshine-headless-start: %s\n' "$out" >&2
          return 1
        fi
      }

      # Off-screen position so the cursor can't wander onto it; 1080p60.
      eval_lua ${lib.escapeShellArg "hl.monitor(${toLua (parseMonitor "${headlessName},1920x1080@60,9999x0,1")})"}

      # Dedicate a `stream` workspace to the headless output and keep it there.
      eval_lua ${lib.escapeShellArg "hl.workspace_rule(${toLua (parseWorkspace "name:stream, monitor:${headlessName}, default:true, persistent:true")})"}

      # Now that the headless exists, start Sunshine (it caches output_name).
      systemctl --user start sunshine.service
    '';
  };
in {
  config = mkIf enabled (mkMerge [
    {
      # Run the headless setup + Sunshine launch once the graphical session is up.
      wayland.windowManager.hyprland.settings.on = [
        (execOnce "${startScript}/bin/sunshine-headless-start")
      ];
    }
    (mkIf impermanenceCfg.home.enable {
      # Sunshine stores web-UI credentials + paired-client state here; persist
      # so they survive reboots under impermanence.
      home.persistence.${persistDir}.directories = [".config/sunshine"];
    })
  ]);
}
