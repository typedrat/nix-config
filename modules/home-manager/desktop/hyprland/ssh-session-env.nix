{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
in {
  config = modules.mkIf (guiCfg.enable && hyprlandCfg.enable) {
    # SSH and tty logins start outside the compositor's environment, so hyprctl
    # and Wayland clients have nothing to connect to. Adopt the newest running
    # instance when the shell has no session of its own.
    programs.zsh.initContent = ''
      if [[ -z $HYPRLAND_INSTANCE_SIGNATURE && -n $XDG_RUNTIME_DIR ]]; then
        () {
          emulate -L zsh
          local lock pid wl f xpid
          local -a kids

          # hyprland.lock holds the compositor pid and its wayland socket.
          # (Nom) walks instances newest first and stays quiet when there are
          # none; a crashed session leaves its directory behind, so the pid is
          # what decides whether an instance is real.
          for lock in $XDG_RUNTIME_DIR/hypr/*/hyprland.lock(Nom); do
            { read -r pid && read -r wl; } < $lock || continue
            kill -0 $pid 2>/dev/null || continue

            export HYPRLAND_INSTANCE_SIGNATURE=''${lock:h:t}
            [[ -n $wl ]] && export WAYLAND_DISPLAY=$wl

            # Xwayland is forked by the compositor and takes its display as
            # argv[1]; the child list hangs off whichever thread forked it.
            kids=()
            for f in /proc/$pid/task/*/children(N); do kids+=(''${=$(<$f)}); done
            for xpid in $kids; do
              [[ -r /proc/$xpid/comm && "$(</proc/$xpid/comm)" == Xwayland ]] || continue
              export DISPLAY=''${''${(0)"$(</proc/$xpid/cmdline)"}[2]}
              break
            done

            break
          done
        }
      fi
    '';
  };
}
