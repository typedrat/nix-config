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
        exit 2
      }

      allowed() {
        ${systemctl} --user show --property=AllowedCPUs --value ${slice}
      }

      # --runtime so a reboot always comes back unpinned.
      pin() {
        ${systemctl} --user set-property --runtime ${slice} AllowedCPUs=${cfg.pinnedCpus}
      }
      unpin() {
        ${systemctl} --user set-property --runtime ${slice} AllowedCPUs=
      }

      case "''${1:-status}" in
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
