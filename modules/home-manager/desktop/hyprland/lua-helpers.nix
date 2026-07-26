{lib, ...}: let
  inherit (lib.generators) mkLuaInline;

  # Render a Nix string as a Lua string literal (handles quoting/escaping).
  luaStr = s: builtins.toJSON s;

  # Coerce a numeric-looking token to a Lua number, else leave it a string.
  # fromJSON yields an int for "1"/"-5" and a float for "1.0".
  toNum = s:
    if builtins.match "-?[0-9]+(\\.[0-9]+)?" s != null
    then builtins.fromJSON s
    else s;

  # Strip surrounding spaces from a comma-split token.
  trim = s: let
    m = builtins.match " *(.*[^ ]|) *" s;
  in
    if m == null
    then s
    else builtins.head m;

  # Dispatchers: each returns an inert `hl.dsp.*` table for `hl.bind`.
  dsp = {
    exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${luaStr cmd})";
    close = mkLuaInline "hl.dsp.window.close()";
    forceKill = mkLuaInline "hl.dsp.window.kill()";
    toggleFloating = mkLuaInline ''hl.dsp.window.float({ action = "toggle" })'';
    fullscreen = mkLuaInline "hl.dsp.window.fullscreen()";
    drag = mkLuaInline "hl.dsp.window.drag()";
    focusWorkspace = ws: mkLuaInline "hl.dsp.focus({ workspace = ${luaStr ws} })";
    global = name: mkLuaInline "hl.dsp.global(${luaStr name})";
  };

  # `hl.bind(keys, dispatcher)` and the flagged variant `hl.bind(keys, dispatcher, opts)`.
  # `keys` uses the `+`-joined form, e.g. "SUPER + SHIFT + left".
  bind = keys: dispatcher: {_args = [keys dispatcher];};
  bindOpts = keys: dispatcher: opts: {_args = [keys dispatcher opts];};

  # exec-once replacement: one `hl.on("hyprland.start", function() … end)` per command.
  execOnce = cmd: {_args = ["hyprland.start" (mkLuaInline "function() hl.exec_cmd(${luaStr cmd}) end")];};

  # Parse a hyprlang monitor string ("DP-1,3840x2160@120,0x1080,1.0,vrr,1") into
  # the table `hl.monitor` expects. First four fields are positional; any trailing
  # tokens are key/value pairs (e.g. vrr,1).
  parseMonitor = str: let
    parts = map trim (lib.splitString "," str);
    len = builtins.length parts;
    positional =
      {output = builtins.elemAt parts 0;}
      // lib.optionalAttrs (len > 1) {mode = builtins.elemAt parts 1;}
      // lib.optionalAttrs (len > 2) {position = builtins.elemAt parts 2;}
      // lib.optionalAttrs (len > 3) {scale = toNum (builtins.elemAt parts 3);};
    pairsToAttrs = l:
      if l == []
      then {}
      else {${builtins.elemAt l 0} = toNum (builtins.elemAt l 1);} // pairsToAttrs (lib.drop 2 l);
  in
    positional // pairsToAttrs (lib.drop 4 parts);

  # hyprlang keyword → Lua workspace-rule key.
  wsKeyMap = {
    gapsout = "gaps_out";
    gapsin = "gaps_in";
  };

  # Parse a hyprlang workspace string ("1, monitor:DP-1, persistent=true" or
  # "w[tv1], gapsout:0, gapsin:0") into the table `hl.workspace_rule` expects.
  parseWorkspace = str: let
    parts = map trim (lib.splitString "," str);
    ws = builtins.head parts;
    mkAttr = tok: let
      m = builtins.match "([^:=]+)[:=](.*)" tok;
      key = builtins.elemAt m 0;
      raw = builtins.elemAt m 1;
      k = wsKeyMap.${key} or key;
      v =
        if raw == "true"
        then true
        else if raw == "false"
        then false
        else toNum raw;
    in
      if m == null
      then {${tok} = true;}
      else {${k} = v;};
  in
    {workspace = ws;} // lib.foldl' (a: b: a // b) {} (map mkAttr (builtins.tail parts));
in {
  _module.args.hlLib = {
    inherit
      dsp
      bind
      bindOpts
      execOnce
      parseMonitor
      parseWorkspace
      mkLuaInline
      luaStr
      ;
  };
}
