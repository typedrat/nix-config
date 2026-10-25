{
  waybar,
  fetchFromGitHub,
  modemmanager,
  nix-update-script,
}:
# 0.15.0 sends hyprlang `dispatch workspace N` requests, which Hyprland's Lua
# IPC rejects, so clicking a workspace button does nothing. Master detects the
# Lua protocol and sends `hl.dsp.*` calls instead.
let
  # Must match subprojects/libcava.wrap, which names the directory meson
  # looks for; the build sandbox can't download wraps.
  libcava = rec {
    version = "1.0.0";
    src = fetchFromGitHub {
      owner = "LukashonakV";
      repo = "cava";
      tag = version;
      hash = "sha256-0r5aAmTs+FcmS501tNYKxG9H+Pq6i32BDRBEjWW6M74=";
    };
  };
in
  waybar.overrideAttrs (prev: {
    version = "0.15.0-unstable-2026-10-19";

    src = fetchFromGitHub {
      owner = "Alexays";
      repo = "Waybar";
      rev = "c15ec02ede4343592a59eb5c2ff4443c9c045f7c";
      hash = "sha256-mBDWjeeIuFfDZQuBxHu+EpbJ+GMbbSxpRz0WVM2N+ZI=";
    };

    versionCheckProgramArg = "--version";
    # The binary reports meson.build's version, which master hasn't bumped.
    preVersionCheck = ''
      version=0.15.0
    '';

    postUnpack = ''
      pushd "$sourceRoot"
      cp -R --no-preserve=mode,ownership ${libcava.src} subprojects/cava-${libcava.version}
      patchShebangs .
      popd
    '';

    # Master's `wwan` module links libmm-glib, and nixpkgs builds with every
    # auto feature enabled.
    buildInputs = prev.buildInputs ++ [modemmanager];

    passthru =
      prev.passthru
      // {
        updateScript = nix-update-script {
          extraArgs = ["--flake" "--version=branch"];
        };
      };
  })
