{
  config,
  osConfig,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  fenix = inputs'.fenix.packages;

  # Stable Rust toolchain with cross-compilation targets.
  rustStable = fenix.combine [
    fenix.stable.defaultToolchain
    fenix.targets.x86_64-unknown-linux-gnu.stable.rust-std
    fenix.targets.x86_64-unknown-linux-musl.stable.rust-std
    fenix.targets.aarch64-unknown-linux-gnu.stable.rust-std
    fenix.targets.aarch64-unknown-linux-musl.stable.rust-std
    fenix.targets.wasm32-unknown-unknown.stable.rust-std
  ];

  # Nightly Rust toolchain with the same targets plus extra nightly-only
  # components (rust-src, miri, cranelift codegen backend).
  rustNightly = fenix.combine [
    (fenix.complete.withComponents [
      "cargo"
      "clippy"
      "rust-src"
      "rustc"
      "rustfmt"
      "miri"
      "rustc-codegen-cranelift-preview"
    ])
    fenix.targets.x86_64-unknown-linux-gnu.latest.rust-std
    fenix.targets.x86_64-unknown-linux-musl.latest.rust-std
    fenix.targets.aarch64-unknown-linux-gnu.latest.rust-std
    fenix.targets.aarch64-unknown-linux-musl.latest.rust-std
    fenix.targets.wasm32-unknown-unknown.latest.rust-std
  ];

  # rustup-style `+channel` shim. Without a `+channel` argument the command is
  # dispatched to the stable toolchain; `+nightly` / `+stable` select explicitly.
  # Only the user-facing entry points are shimmed; internal helpers (rustc-dev,
  # llvm-tools, etc.) stay resolvable via each toolchain's own bin directory
  # when needed.
  rustShimBins = [
    "cargo"
    "rustc"
    "clippy-driver"
    "cargo-clippy"
    "rustfmt"
    "cargo-fmt"
    "cargo-miri"
    "rust-gdb"
    "rust-gdbgui"
    "rust-lldb"
    "rustdoc"
  ];

  rustChannelShim = pkgs.stdenvNoCC.mkDerivation {
    pname = "rust-channel-shim";
    version = "1.0.0";

    # No source: the script body is generated entirely in buildPhase from the
    # `rustShimBins` list and the absolute store paths of the two toolchains.
    dontUnpack = true;

    passthru = {inherit rustStable rustNightly;};

    buildPhase = ''
      runHook preBuild

      mkdir -p bin
      for cmd in ${lib.escapeShellArgs rustShimBins}; do
        cat > "bin/$cmd" <<EOF
      #!${pkgs.bash}/bin/bash
      # Dispatch to stable or nightly Rust. Selection precedence:
      #   1. Leading +channel argument (e.g. \`cargo +nightly build\`)
      #   2. RUSTUP_TOOLCHAIN environment variable
      #   3. Default to stable
      #
      # When a +channel argument is given, RUSTUP_TOOLCHAIN is exported before
      # exec so subprocesses (cargo-fuzz, cargo-flamegraph, build scripts that
      # reshell \`cargo\`, etc.) inherit the selection instead of silently
      # falling back to stable. RUSTUP_TOOLCHAIN is the canonical rustup
      # variable, so tools that already understand rustup conventions pick it
      # up for free.
      stable=${rustStable}/bin/$cmd
      nightly=${rustNightly}/bin/$cmd
      if [ \$# -gt 0 ]; then
        case "\$1" in
          +nightly) shift; export RUSTUP_TOOLCHAIN=nightly; exec "\$nightly" "\$@" ;;
          +stable)  shift; export RUSTUP_TOOLCHAIN=stable;  exec "\$stable"  "\$@" ;;
          +*)
            echo "rust-channel-shim: unknown channel '\$1' (supported: +stable, +nightly)" >&2
            exit 1
            ;;
        esac
      fi
      case "\''${RUSTUP_TOOLCHAIN:-}" in
        ""|stable)  exec "\$stable"  "\$@" ;;
        nightly)    exec "\$nightly" "\$@" ;;
        *)
          echo "rust-channel-shim: RUSTUP_TOOLCHAIN='\$RUSTUP_TOOLCHAIN' is not supported (only 'stable' or 'nightly')" >&2
          exit 1
          ;;
      esac
      EOF
        # Heredoc body is indented for readability; strip that indent in the
        # generated script so the shebang lands at column 0.
        ${pkgs.gnused}/bin/sed -i 's/^      //' "bin/$cmd"
        chmod +x "bin/$cmd"
      done

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r bin "$out/bin"
      runHook postInstall
    '';

    meta = with lib; {
      description = "rustup-style +channel dispatcher for stable/nightly fenix toolchains";
      platforms = platforms.unix;
    };
  };
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/cargo"
        ".local/share/rustup"
        ".local/share/bun"
        ".config/npm"
        ".config/ipython"
        ".local/share/pnpm"
        ".local/state/pnpm"
        ".cache/ms-playwright"
        ".cache/uv"
        ".local/share/uv"
      ];
    };
    home.packages = with pkgs; [
      # Rust: stable by default, `cargo +nightly`/`rustc +nightly` for nightly.
      # `lib.hiPrio` makes the shim win collisions against the stable toolchain
      # for the shimmed binaries (cargo, rustc, clippy-driver, ...). The stable
      # toolchain stays in PATH so non-shimmed entry points (rust-analyzer
      # helpers, etc.) remain resolvable. The nightly toolchain is referenced
      # only by absolute store path from inside the shim, keeping it out of
      # PATH while still preserving it as a GC root.
      (lib.hiPrio rustChannelShim)
      rustStable

      # cargo-fuzz from nixpkgs, wrapped so the sanitizer-instrumented fuzz
      # harness it builds finds libstdc++/libgcc_s at runtime. See the
      # `cargo-fuzz-nixos` package definition for the gnarly details —
      # short version: the built fuzz binary uses a store-path glibc loader
      # (bypassing nix-ld) and has no RPATH covering C++ runtimes, so
      # LD_LIBRARY_PATH is the only knob that still works. The wrapper
      # exposes a binary named `cargo-fuzz` on PATH so `cargo fuzz <...>`
      # still resolves it via the standard cargo-subcommand mechanism.
      cargo-fuzz-nixos

      # Python with common data science packages
      (python3.withPackages (
        ps:
          with ps; [
            ipython
            matplotlib
            numpy
            pandas
            polars
            pynput
            scipy
            seaborn
            sympy
          ]
      ))

      # JavaScript/Node.js
      bun
      nodejs

      # Java
      jdk
      maven

      # Lean theorem prover
      elan
    ];
  };
}
