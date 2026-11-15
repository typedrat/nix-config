{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    # Runs the tweakcc-fixed configurator against the config.json that
    # claude-code-patched builds from, with the same prompt overrides and an
    # unmodified Claude Code of the same version. Anything the configurator
    # changes outside config.json is discarded on exit.
    apps.tweakcc = let
      inherit (self'.packages) claude-code-patched tweakcc-fixed;
      claude-code = claude-code-patched.unpatched;
      inherit (claude-code-patched) promptOverridesSrc;
    in {
      type = "app";
      meta.description = "Edit claude-code-patched's tweakcc config with the tweakcc-fixed configurator";
      program = lib.getExe (pkgs.writeShellApplication {
        name = "tweakcc-configure";
        runtimeInputs = [pkgs.coreutils pkgs.git pkgs.jq pkgs.zstd];
        text = ''
          # An optional leading path picks another config; the rest go to tweakcc.
          if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
            config="$1"
            shift
          else
            config="$(git rev-parse --show-toplevel)/packages/claude-code-patched/config.json"
          fi
          if [ ! -w "$config" ]; then
            echo "tweakcc-configure: $config is not a writable file" >&2
            exit 1
          fi

          work="$(mktemp -d)"
          trap 'rm -rf "$work"' EXIT
          mkdir -p "$work/bin" "$work/tweakcc"

          # The raw upstream binary rather than nixpkgs' output: that one is a
          # wrapper script around an autoPatchelf'd ELF, which tweakcc's ELF
          # parser crashes on. A writable copy also means an Apply from the
          # configurator patches this throwaway file, not the store. It runs
          # through nix-ld.
          zstd -dq ${claude-code.src} -o "$work/bin/claude"
          chmod 0755 "$work/bin/claude"

          # tweakcc saves by renaming a temp file over the original, which
          # would replace a symlink, so edit a copy and write it back.
          cp "$config" "$work/tweakcc/config.json"
          chmod u+w "$work/tweakcc/config.json"
          cp -RL ${promptOverridesSrc}/system-prompts-lcc "$work/tweakcc/system-prompts"
          cp -RL ${promptOverridesSrc}/system-reminders "$work/tweakcc/system-reminders"
          chmod -R u+w "$work/tweakcc"

          export TWEAKCC_CONFIG_DIR="$work/tweakcc"
          export TWEAKCC_CC_INSTALLATION_PATH="$work/bin/claude"
          export PATH="$work/bin:$PATH"

          status=0
          ${lib.getExe tweakcc-fixed} "$@" || status=$?

          # The build discards these anyway; keeping them out of the tracked
          # file avoids diffs that point into a deleted temp dir.
          jq '.ccInstallationPath = null | del(.ccInstallationDir) | .changesApplied = false' \
            "$work/tweakcc/config.json" > "$work/config.json"
          if cmp -s "$work/config.json" "$config"; then
            echo "tweakcc-configure: $config unchanged" >&2
          else
            cp "$work/config.json" "$config"
            echo "tweakcc-configure: updated $config" >&2
          fi
          exit "$status"
        '';
      });
    };
  };
}
