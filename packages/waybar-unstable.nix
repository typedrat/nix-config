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
  # Must match the revision in subprojects/libcava.wrap; the build sandbox
  # can't download wraps, so the source goes where the wrap's `directory`
  # points.
  libcavaRev = "8d6e963db9cd29c2b3b5a5df1e46bb65c410f9cc";
  libcava = fetchFromGitHub {
    owner = "LukashonakV";
    repo = "cava";
    rev = libcavaRev;
    hash = "sha256-tWY3D3sEVFDHJjO/enCu0lEobM1CF4vupavOHgIslnA=";
  };
in
  waybar.overrideAttrs (prev: {
    version = "0.16.0-unstable-2026-11-10";

    src = fetchFromGitHub {
      owner = "Alexays";
      repo = "Waybar";
      rev = "2318da41bdce5ebb99c6f9115acc27d28f1bdc7b";
      hash = "sha256-adIBnBcBakfBXm3L+yfDynO+mPuar89VgeQvACasGvg=";
    };

    versionCheckProgramArg = "--version";
    # The binary reports meson.build's version, without the unstable suffix.
    preVersionCheck = ''
      version=0.16.0
    '';

    postUnpack = ''
      pushd "$sourceRoot"
      cp -R --no-preserve=mode,ownership ${libcava} subprojects/cava-${libcavaRev}
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
