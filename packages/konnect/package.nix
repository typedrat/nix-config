{
  lib,
  inputs,
  stdenv,
  callPackage,
  makeWrapper,
  kicad,
}:
# Built from the upstream flake, so there is no updateScript here — the version
# moves with the `konnect` input in flake.lock.
let
  # Upstream only builds for Linux; the fallback keeps `packages.<darwin>`
  # evaluating, and meta.platforms filters this back out of it.
  upstream =
    inputs.konnect.packages.${stdenv.hostPlatform.system}.konnect
    or inputs.konnect.packages.x86_64-linux.konnect;

  schematic-viewer = callPackage ./viewer.nix {};
in
  upstream.overrideAttrs (prev: {
    nativeBuildInputs = prev.nativeBuildInputs ++ [makeWrapper];

    # PATH: exports, ERC/DRC, and schematic rendering shell out to `kicad-cli`,
    # looked up bare. Suffixed so a KiCAD the user installed themselves still
    # wins — the CLI has to match the KiCAD generating the files it reads.
    #
    # Symlink: `open_schematic_viewer` locates the viewer beside its own
    # executable, and nowhere else worth relying on.
    postInstall =
      (prev.postInstall or "")
      + ''
        wrapProgram $out/bin/konnect \
          --suffix PATH : ${lib.makeBinPath [kicad]}

        ln -s ${lib.getExe schematic-viewer} $out/bin/schematic-viewer
      '';

    passthru = (prev.passthru or {}) // {inherit schematic-viewer;};

    meta =
      prev.meta
      // {
        description = "AI-assisted PCB design for KiCAD 10 over the Model Context Protocol";
        homepage = "https://github.com/mixelpixx/Konnect";
        license = lib.licenses.agpl3Only;
        platforms = lib.platforms.linux;
      };
  })
