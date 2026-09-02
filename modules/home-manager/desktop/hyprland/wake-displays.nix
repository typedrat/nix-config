{pkgs, ...}: {
  # Hyprland records DPMS state but never observes it. A panel switched off at
  # its own power button keeps HPD asserted, so the connector stays "connected"
  # and nothing updates that record; setDPMS then returns early because the
  # requested state already matches, leaving no way to force the modeset that
  # would light the panel again. Going off first puts the record back in sync,
  # and costs nothing when the display really is off, since that too matches
  # and returns without committing. The pause covers a sleeping DP link, which
  # rejects an enable sent immediately after a disable.
  #
  # The dispatchers have to be spelled as Lua: under configType = "lua",
  # `hyprctl dispatch` evaluates its argument as a Lua expression, so the bare
  # `dpms off` form fails to parse. hyprctl exits 0 either way and reports the
  # failure only on stdout, so a mis-spelled dispatch is silent.
  _module.args.wakeDisplays = pkgs.writeShellScriptBin "wake-displays" ''
    dispatch() {
      local out
      out=$(hyprctl dispatch "$1")
      if [ "$out" != ok ]; then
        printf 'wake-displays: %s\n' "$out" >&2
        return 1
      fi
    }

    dispatch 'hl.dsp.dpms({action = "off"})'
    sleep 1
    dispatch 'hl.dsp.dpms({action = "on"})'
  '';
}
