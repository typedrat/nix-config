{
  lib,
  inputs,
  stdenv,
  rustPlatform,
  pkg-config,
  wrapGAppsHook3,
  glib-networking,
  webkitgtk_4_1,
}: let
  upstream =
    inputs.konnect.packages.${stdenv.hostPlatform.system}.konnect
    or inputs.konnect.packages.x86_64-linux.konnect;
in
  rustPlatform.buildRustPackage {
    pname = "konnect-schematic-viewer";
    inherit (upstream) version src;

    # A Tauri app kept out of the cargo workspace — and out of the flake's
    # package — so it builds from the same tree against its own lock file. It
    # still needs the whole tree unpacked for the `konnect-schematic-editor`
    # path dependency, hence the subdir rather than a narrower src.
    buildAndTestSubdir = "crates/schematic-viewer";
    cargoRoot = "crates/schematic-viewer";
    cargoLock.lockFile = "${upstream.src}/crates/schematic-viewer/Cargo.lock";

    # Every schematic write takes a lock file under the platform local-data dir,
    # which resolves to $HOME/.local/share — unwritable as the sandbox's
    # /homeless-shelter, so the snapshot and sheet-walk tests fail on it.
    preCheck = ''
      export HOME=$(mktemp -d)
    '';

    nativeBuildInputs = [
      pkg-config
      wrapGAppsHook3
    ];

    # webkitgtk carries the GTK3 stack; glib-networking is what lets the webview
    # resolve anything over TLS.
    buildInputs = [
      glib-networking
      webkitgtk_4_1
    ];

    meta = {
      description = "Live-refreshing schematic viewer for Konnect";
      homepage = "https://github.com/mixelpixx/Konnect";
      license = lib.licenses.agpl3Only;
      mainProgram = "schematic-viewer";
      platforms = lib.platforms.linux;
    };
  }
