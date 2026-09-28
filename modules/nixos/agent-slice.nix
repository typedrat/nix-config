# Runs coding agents, and everything they spawn, in agents.slice under each
# user's systemd manager, so `agent-pin on` can fence them onto a subset of
# cores while something latency-sensitive (a game) keeps the rest.
#
# Work the agents hand off to a system service is outside the slice and not
# pinned: `nix build` runs in nix-daemon, and containers run under dockerd.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.rat.agentSlice;
  slice = "agents.slice";
  systemctl = "${config.systemd.package}/bin/systemctl";

  # Absolute paths rather than runtimeInputs: this execs the agent, and a
  # prepended PATH would leak into every tool the agent runs.
  launcher = pkgs.writeShellScript "agent-slice-run" ''
    # Agents started by another agent are already in the slice.
    if ${pkgs.gnugrep}/bin/grep -q '/${lib.escapeRegex slice}/' /proc/self/cgroup; then
      exec "$@"
    fi

    # No user manager to ask, e.g. a shell entered through su.
    if [[ ! -S "''${XDG_RUNTIME_DIR:-/run/user/$UID}/bus" ]]; then
      exec "$@"
    fi

    exec ${config.systemd.package}/bin/systemd-run --user --scope --quiet --collect \
      --slice=${slice} --description="''${1##*/}" -- "$@"
  '';

  agentPin = pkgs.writeShellApplication {
    name = "agent-pin";
    text = ''
      usage() {
        echo "usage: agent-pin [on|off|toggle|status]" >&2
        echo "       agent-pin run <command> [args...]" >&2
        exit 2
      }

      allowed() {
        ${systemctl} --user show --property=AllowedCPUs --value ${slice}
      }

      # --runtime so a reboot always comes back unpinned. The weights cover what
      # pinning cannot: disk bandwidth is shared regardless of which CCD asks.
      pin() {
        ${systemctl} --user set-property --runtime ${slice} \
          AllowedCPUs=${cfg.pinnedCpus} CPUWeight=20 IOWeight=20
      }
      unpin() {
        ${systemctl} --user set-property --runtime ${slice} \
          AllowedCPUs= CPUWeight= IOWeight=
      }

      # Each `run` leaves a pidfile here while its command is alive, so
      # overlapping runs only unpin when the last one exits.
      holders="''${XDG_RUNTIME_DIR:-/run/user/$UID}/agent-pin"

      # Counts live holders and deletes the rest. A holder only goes stale if
      # its release service never ran, so a stale file means a leftover pin
      # from a run rather than one set by hand.
      prune_holders() {
        local f
        live=0 stale=0
        for f in "$holders"/*.pid; do
          [[ -e "$f" ]] || continue
          if kill -0 "$(${pkgs.coreutils}/bin/basename "$f" .pid)" 2>/dev/null; then
            live=$((live + 1))
          else
            rm -f "$f"
            stale=$((stale + 1))
          fi
        done
      }

      # A pin already on when the first holder arrives was set by hand, and is
      # left on after the last holder leaves.
      acquire() {
        (
          ${pkgs.util-linux}/bin/flock 9
          prune_holders
          if ((live == 0 && stale == 0)); then
            if [[ -n "$(allowed)" ]]; then
              touch "$holders/manual"
            else
              rm -f "$holders/manual"
              pin
            fi
          elif ((live == 0)) && [[ -z "$(allowed)" ]]; then
            pin
          fi
          touch "$holders/$1.pid"
        ) 9>"$holders/lock"
      }

      release() {
        (
          ${pkgs.util-linux}/bin/flock 9
          rm -f "$holders/$1.pid"
          prune_holders
          if ((live == 0)); then
            if [[ -e "$holders/manual" ]]; then
              rm -f "$holders/manual"
            else
              unpin
            fi
          fi
        ) 9>"$holders/lock"
      }

      # Pinning is best-effort: a launch option that fails would keep the game
      # from starting at all.
      run() {
        [[ $# -gt 0 ]] || usage
        if mkdir -p "$holders" && acquire $$ >/dev/null; then
          # The release waits in its own user service instead of a child
          # process: Steam's reaper kills every descendant when a game stops,
          # and exec leaves nothing of this script behind to clean up.
          ${config.systemd.package}/bin/systemd-run --user --quiet --collect \
            --unit="agent-pin-release-$$" \
            "$(${pkgs.coreutils}/bin/readlink -f "$0")" _release $$ ||
            release $$ >/dev/null || true
        else
          echo "agent-pin: could not pin ${slice}" >&2
        fi
        exec "$@"
      }

      case "''${1:-status}" in
        run)
          shift
          run "$@"
          ;;
        _release)
          ${pkgs.coreutils}/bin/tail --pid="$2" -f /dev/null
          release "$2" >/dev/null
          exit
          ;;
        on) pin ;;
        off) unpin ;;
        toggle) if [[ -n "$(allowed)" ]]; then unpin; else pin; fi ;;
        status) ;;
        *) usage ;;
      esac

      current=$(allowed)
      if [[ -n "$current" ]]; then
        echo "${slice}: pinned to CPUs $current"
      else
        echo "${slice}: unpinned"
      fi
      ${systemctl} --user show --property=CPUWeight --property=IOWeight ${slice}
    '';
  };
in {
  options.rat.agentSlice = {
    enable = mkEnableOption "a dedicated systemd user slice for coding agents";

    pinnedCpus = mkOption {
      type = types.str;
      example = "8-15,24-31";
      description = "CPU list that `agent-pin on` confines ${slice} to.";
    };

    wrap = mkOption {
      type = types.functionTo types.package;
      readOnly = true;
      description = ''
        Wraps a package so its main program launches inside ${slice}.
        Returns the package unchanged when the slice is disabled.
      '';
      default = pkg:
        if !cfg.enable
        then pkg
        else let
          exe = pkg.meta.mainProgram;
        in
          pkgs.symlinkJoin {
            name = "${pkg.name}-agent-slice";
            paths = [pkg];
            nativeBuildInputs = [pkgs.makeWrapper];
            postBuild = ''
              rm "$out/bin/${exe}"
              makeWrapper ${launcher} "$out/bin/${exe}" --add-flags ${lib.getExe pkg}
            '';
            inherit (pkg) meta;
            passthru = pkg.passthru or {};
          };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.slices.agents.description = "Coding agents";

    # AllowedCPUs on a user unit needs the cpuset controller delegated to the
    # user manager, which systemd leaves out by default. user@ is never
    # restarted on switch, so this takes effect at the next login.
    systemd.services."user@".serviceConfig.Delegate = "cpu cpuset io memory pids";

    environment.systemPackages = [agentPin];
  };
}
