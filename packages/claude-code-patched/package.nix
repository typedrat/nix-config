{
  lib,
  claude-code,
  tweakcc-fixed,
  jq,
  # User-supplied tweakcc config; tracked alongside this package so prompt
  # tweaks are reproducible across hosts.
  tweakccConfig ? ./config.json,
}: let
  # Pinned in tweakcc-fixed's passthru so its update script bumps the
  # overrides and the patcher together.
  inherit (tweakcc-fixed) promptOverrides;
in
  # Override claude-code itself rather than wrapping its output, so the
  # binary is patched in place. We hook `preFixup` to run tweakcc-fixed
  # *between* installPhase (which puts the original Bun binary at
  # $out/bin/.claude-wrapped) and autoPatchelfHook in fixupPhase: LIEF
  # can't parse the autoPatchelf'd ELF because the added LOAD segment
  # for the longer Nix-store interpreter path confuses its program-
  # header walk and segfaults during native-binary extraction.
  claude-code.overrideAttrs (prev: {
    pname = "claude-code-patched";

    nativeBuildInputs = prev.nativeBuildInputs ++ [tweakcc-fixed jq];

    preFixup =
      (prev.preFixup or "")
      + ''
        # Stage tweakcc's expected HOME / config layout in the sandbox.
        export TWEAKCC_CONFIG_DIR="$TMPDIR/tweakcc"
        export HOME="$TMPDIR/home"
        mkdir -p "$TWEAKCC_CONFIG_DIR" "$HOME"

        install -m 0644 ${tweakccConfig} "$TWEAKCC_CONFIG_DIR/config.json"
        # tweakcc seeds defaults into system-prompts/ and system-reminders/
        # on first --apply, so they must be writable — symlinks back to
        # the immutable prompt-overrides source are insufficient.
        cp -RL ${promptOverrides}/system-prompts-opus-5 "$TWEAKCC_CONFIG_DIR/system-prompts"
        cp -RL ${promptOverrides}/system-reminders "$TWEAKCC_CONFIG_DIR/system-reminders"
        chmod -R u+w "$TWEAKCC_CONFIG_DIR/system-prompts" "$TWEAKCC_CONFIG_DIR/system-reminders"

        # Upstream ships this override as a verbatim copy of CC's own string
        # rather than the empty body the sibling delegation overrides use, so
        # the restriction survives the patch. Truncating to the header leaves
        # an empty body, which blanks it.
        sed -i '/^-->$/q' \
          "$TWEAKCC_CONFIG_DIR/system-prompts/system-prompt-opus5-reduced-delegation.md"

        # Scrub the captured config's installation pointer and applied
        # flag so tweakcc targets the binary in *this* derivation and
        # actually re-runs the patches.
        jq 'del(.ccInstallationPath, .ccInstallationDir) | .changesApplied = false' \
          "$TWEAKCC_CONFIG_DIR/config.json" > "$TWEAKCC_CONFIG_DIR/config.json.new"
        mv "$TWEAKCC_CONFIG_DIR/config.json.new" "$TWEAKCC_CONFIG_DIR/config.json"

        # wrapProgram already moved the original binary to .claude-wrapped
        # in installPhase. Patch that one — the outer `claude` is the
        # makeBinaryWrapper shim and gets autoPatchelf'd separately.
        export TWEAKCC_CC_INSTALLATION_PATH="$out/bin/.claude-wrapped"
        ${lib.getExe tweakcc-fixed} --apply
      '';

    # tweakcc's own post-repack startup check is disabled (it runs before
    # autoPatchelf, see tweakcc-fixed.nix). Re-assert that the patched binary
    # actually boots here instead, after autoPatchelf has fixed the ELF
    # interpreter — this is the phase where `claude --version` can really run.
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      echo "Verifying patched claude-code boots..."
      version="$($out/bin/claude --version)"
      echo "$version"
      case "$version" in
        *"Claude Code"*) ;;
        *) echo "claude --version did not report a Claude Code version" >&2; exit 1 ;;
      esac

      runHook postInstallCheck
    '';

    # Drop the inherited updateScript: it resolves claude-code's definition to
    # a path inside patched nixpkgs, which isn't part of this flake, so
    # nix-update can't rewrite it. Bumping this package means bumping the
    # nixpkgs patch by hand; tweakcc-fixed's update script handles the
    # patcher and prompt overrides.
    passthru =
      builtins.removeAttrs (prev.passthru or {}) ["updateScript"]
      // {
        unpatched = claude-code;
        promptOverridesSrc = promptOverrides;
      };

    meta =
      prev.meta
      // {
        description = "Claude Code with skrabe/lobotomized-claude-code system-prompt overrides applied via tweakcc-fixed";
        longDescription = ''
          Overrides nixpkgs' claude-code so the system-prompt and
          system-reminder overrides from
          https://github.com/skrabe/lobotomized-claude-code are applied
          via tweakcc-fixed during the build, before autoPatchelfHook
          rewrites the ELF interpreter (running the patch after
          autoPatchelf crashes LIEF on the rewritten program headers).
          The user's ~/.tweakcc/config.json is captured in this repo at
          packages/claude-code-patched/config.json so the result is
          reproducible across hosts.
        '';
      };
  })
