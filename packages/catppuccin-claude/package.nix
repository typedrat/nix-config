{
  lib,
  stdenvNoCC,
  lessc,
  lightFlavor ? "latte",
  darkFlavor ? "mocha",
  accent ? "mauve",
}:
# claude.user.less and lib.less are vendored verbatim from catppuccin/userstyles
# (styles/claude/catppuccin.user.less and lib/std/v1.less), so there is no
# updateScript; refresh them by hand. electron.less holds the rules for Claude
# Desktop's own windows, which the userstyle has no reason to carry.
stdenvNoCC.mkDerivation {
  pname = "catppuccin-claude";
  version = "0-unstable-2026-10-19";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./claude.user.less
      ./lib.less
      ./electron.less
    ];
  };

  nativeBuildInputs = [lessc];

  dontConfigure = true;

  # Chromium has no @-moz-document, and the mixins electron.less calls are
  # defined inside that block, so unwrap it: drop the opening line and the
  # first column-0 brace after it, which closes it.
  buildPhase = ''
    runHook preBuild

    substituteInPlace claude.user.less --replace-fail \
      '@import "https://userstyles.catppuccin.com/lib/std/v1.less";' \
      '@import "lib.less";'

    awk '
      state == 0 && /^@-moz-document / { state = 1; next }
      state == 1 && /^}$/ { state = 2; next }
      { print }
      END { if (state != 2) exit 1 }
    ' claude.user.less > claude.less
    echo '@import "electron.less";' >> claude.less

    lessc \
      --global-var=lightFlavor=${lightFlavor} \
      --global-var=darkFlavor=${darkFlavor} \
      --global-var=accentColor=${accent} \
      claude.less catppuccin.css

    if grep -qE '@(-moz-document|import)' catppuccin.css; then
      echo "catppuccin-claude: unresolved at-rule in compiled CSS" >&2
      exit 1
    fi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 catppuccin.css $out/catppuccin.css
    runHook postInstall
  '';

  meta = {
    description = "Catppuccin for claude.ai and Claude Desktop, as plain CSS";
    homepage = "https://github.com/catppuccin/userstyles/tree/main/styles/claude";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
