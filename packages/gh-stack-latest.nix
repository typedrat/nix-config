{
  gh-stack,
  fetchFromGitHub,
  nix-update-script,
}:
# 0.3.0 is on nixpkgs master but not yet in nixos-unstable; drop this once
# pkgs.gh-stack catches up.
gh-stack.overrideAttrs (finalAttrs: prev: {
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "github";
    repo = "gh-stack";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dENuxVuz68Y7P8WW5C7pzVbfJRxGMGIKQ2AnWrTacOs=";
  };

  vendorHash = "sha256-y+eTfmZTdSkHh943o/XtFrrMWv/lxvWekKUp/JKb0h4=";

  passthru =
    prev.passthru
    // {
      updateScript = nix-update-script {extraArgs = ["--flake"];};

      # The go-modules derivation inherits the installAgentSkills hook but has
      # no pname, so the hook fails there.
      overrideModAttrs = _: _: {
        dontInstallAgentSkills = true;
      };
    };
})
