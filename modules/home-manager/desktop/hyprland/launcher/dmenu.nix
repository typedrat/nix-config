{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
  launcherCfg = hyprlandCfg.launcher or {};
  variant = launcherCfg.variant or "rofi";

  # rat-dmenu: a launcher-agnostic "dmenu". Whatever the active launcher
  # variant, this reads newline-delimited entries on stdin, lets the user pick
  # one, prints the chosen entry to stdout, and exits nonzero if cancelled.
  # This is the single indirection point for "give me a dmenu-like picker" so
  # scripts (and keybinds) don't have to care whether vicinae or rofi is in use.
  #
  # Anything after `--` is forwarded verbatim to the active backend, letting a
  # caller layer on backend-specific styling when it knows which one is in use.
  #
  #   rat-dmenu [-p PROMPT] [-t TITLE] [-- extra backend args]
  mkDmenu = {
    runtimeInputs,
    dispatch,
  }:
    pkgs.writeShellApplication {
      name = "rat-dmenu";
      inherit runtimeInputs;
      text = ''
        prompt=""
        title=""
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -p | --prompt) prompt="$2"; shift 2 ;;
            -t | --title) title="$2"; shift 2 ;;
            --) shift; break ;;
            *) break ;;
          esac
        done

        ${dispatch}
      '';
    };

  dmenuTool =
    if variant == "vicinae"
    then
      mkDmenu {
        runtimeInputs = [config.programs.vicinae.package];
        dispatch = ''
          args=(dmenu)
          [ -n "$title" ] && args+=(--navigation-title "$title")
          [ -n "$prompt" ] && args+=(--placeholder "$prompt")
          exec vicinae "''${args[@]}" "$@"
        '';
      }
    else
      mkDmenu {
        runtimeInputs = [config.programs.rofi.finalPackage];
        dispatch = ''
          args=(-dmenu -i)
          [ -n "$prompt" ] && args+=(-p "$prompt")
          [ -n "$title" ] && args+=(-mesg "$title")
          exec rofi "''${args[@]}" "$@"
        '';
      };

  # Anything after `--` is forwarded verbatim to the active dmenu backend, so
  # we only hand vicinae its template-driven section title (with the live
  # {count} placeholder) when vicinae is the backend actually running. rofi
  # gets nothing extra and keeps its normalized -p/-mesg styling.
  pickerExtras =
    if variant == "vicinae"
    then ''-- --section-title "Minimized ({count})"''
    else "";

  # Picker that lists every window parked on the special:minimized workspace
  # (see hyprbars.nix's minimize button) and pulls the chosen one onto the
  # workspace you're currently looking at. Backend-agnostic via rat-dmenu.
  pullMinimized = pkgs.writeShellApplication {
    name = "pull-minimized-window";
    runtimeInputs = [pkgs.hyprland pkgs.jq pkgs.libnotify dmenuTool];
    text = ''
      # Snapshot clients once so the menu and the address lookup stay consistent
      # even if windows change between listing and selection.
      clients=$(hyprctl clients -j)

      # One "address<TAB>label" row per minimized window, in stable order.
      mapfile -t rows < <(
        jq -r '
          .[]
          | select(.workspace.name == "special:minimized")
          | "\(.address)\t\((.title | select(length > 0)) // .class)  ·  \(.class)"
        ' <<<"$clients"
      )

      if [ "''${#rows[@]}" -eq 0 ]; then
        notify-send -a Hyprland "No minimized windows" "Nothing is parked on the minimized workspace."
        exit 0
      fi

      addrs=()
      labels=()
      for row in "''${rows[@]}"; do
        addrs+=("''${row%%$'\t'*}")
        labels+=("''${row#*$'\t'}")
      done

      choice=$(
        printf '%s\n' "''${labels[@]}" \
          | rat-dmenu -t "Minimized windows" -p "Pull a window to this workspace…" ${pickerExtras}
      ) || choice=""

      [ -z "$choice" ] && exit 0

      addr=""
      for i in "''${!labels[@]}"; do
        if [ "''${labels[$i]}" = "$choice" ]; then
          addr="''${addrs[$i]}"
          break
        fi
      done

      [ -z "$addr" ] && exit 0

      ws=$(hyprctl activeworkspace -j | jq -r '.id')
      hyprctl dispatch movetoworkspace "$ws,address:$addr"
      hyprctl dispatch focuswindow "address:$addr"
    '';
  };
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && hyprlandCfg.enable
      && (variant == "vicinae" || variant == "rofi")
    ) {
      # Reusable on PATH for any other script/keybind that wants a picker.
      home.packages = [dmenuTool];

      wayland.windowManager.hyprland.settings.bind = [
        "$main_mod, m, exec, ${lib.getExe pullMinimized}"
      ];
    };
}
