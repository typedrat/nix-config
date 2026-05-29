{
  lib,
  symlinkJoin,
  makeWrapper,
  cargo-fuzz,
  stdenv,
}:
# Wrap nixpkgs' cargo-fuzz so the fuzz target binaries it builds can find
# common C/C++ runtime libraries at execution time.
#
# Why this is needed on NixOS:
#
# cargo-fuzz drives `cargo build` against the nightly toolchain to produce a
# sanitizer-instrumented harness, then exec's that harness directly. The
# harness ELF inherits two properties from rustc's link configuration that
# combine badly on a stock NixOS host:
#
#   1. Its program interpreter is rustc's store-path glibc loader
#      (e.g. /nix/store/<hash>-glibc-2.42-…/lib/ld-linux-x86-64.so.2),
#      NOT the FHS path /lib64/ld-linux-x86-64.so.2 that nix-ld intercepts.
#      That means nix-ld is bypassed entirely for fuzz binaries, and any
#      tweaks to /etc/nix-ld/lib have no effect here.
#
#   2. Its RPATH/RUNPATH points only at the toolchain's own lib/ directory,
#      which holds librustc_driver and friends but NOT libstdc++, libgcc_s,
#      libz, or any of the other C/C++ runtimes that bindgen-driven crates
#      and libFuzzer integration routinely pull in.
#
# The store-path loader still honors LD_LIBRARY_PATH (that's a loader
# feature, not a nix-ld one), so the cheapest correct fix is to launch
# cargo-fuzz with libstdc++ + libgcc_s already on LD_LIBRARY_PATH. Children
# of cargo-fuzz (including the fuzz harness it exec's) inherit the env, so
# the harness picks the libs up at runtime.
#
# Scope is intentionally narrow:
#   - We only inject the libraries that virtually every Rust fuzz target
#     ends up needing. Project-specific deps (libcuda, libssl, libxml2, …)
#     still belong in a per-project devshell.
#   - The wrap is on `cargo-fuzz` itself, not on `cargo` or `rustc`, so
#     regular `cargo build` / `cargo test` invocations are unaffected and
#     can't accidentally pick up libstdc++ from this wrapper to mask a
#     missing `buildInputs` entry.
let
  # libstdc++.so.6 + libgcc_s.so.1 live here on glibc stdenv.
  runtimeLibs = [stdenv.cc.cc.lib];
in
  symlinkJoin {
    name = "cargo-fuzz-${cargo-fuzz.version}-wrapped";

    paths = [cargo-fuzz];

    nativeBuildInputs = [makeWrapper];

    postBuild = ''
      # Remove the symlinked binary so we can replace it with a wrapper that
      # injects LD_LIBRARY_PATH. The original binary is still reachable via
      # the cargo-fuzz store path that symlinkJoin pulled in.
      rm "$out/bin/cargo-fuzz"
      makeWrapper "${lib.getExe cargo-fuzz}" "$out/bin/cargo-fuzz" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"
    '';

    passthru = {
      inherit (cargo-fuzz) version;
      unwrapped = cargo-fuzz;
    };

    meta =
      cargo-fuzz.meta
      // {
        description = "${cargo-fuzz.meta.description} (wrapped with LD_LIBRARY_PATH for NixOS host execution)";
        mainProgram = "cargo-fuzz";
      };
  }
