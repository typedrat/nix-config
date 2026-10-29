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
  # can't download wraps. A git wrap with no `directory` key is looked up
  # under the wrap's own name.
  libcava = fetchFromGitHub {
    owner = "LukashonakV";
    repo = "cava";
    rev = "8d6e963db9cd29c2b3b5a5df1e46bb65c410f9cc";
    hash = "sha256-tWY3D3sEVFDHJjO/enCu0lEobM1CF4vupavOHgIslnA=";
  };
in
  waybar.overrideAttrs (prev: {
    version = "0.15.0-unstable-2026-10-28";

    src = fetchFromGitHub {
      owner = "Alexays";
      repo = "Waybar";
      rev = "f6f73c81818b0a6753c1efb68e0fae2149eac028";
      hash = "sha256-CZR26099bnlOWgLpMOPwdpmocSAGetbepjkP661qml4=";
    };

    versionCheckProgramArg = "--version";
    # The binary reports meson.build's version, which master hasn't bumped.
    preVersionCheck = ''
      version=0.15.0
    '';

    postUnpack = ''
      pushd "$sourceRoot"
      cp -R --no-preserve=mode,ownership ${libcava} subprojects/libcava
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
