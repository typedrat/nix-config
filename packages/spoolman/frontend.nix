{
  buildNpmPackage,
  callPackage,
  fetchurl,
}: let
  common = callPackage ./common.nix {};

  # project.inlang/settings.json loads these over the network at build time, and
  # the sandbox has none -- paraglide then silently compiles an empty message
  # catalogue and vite only warns, so the build succeeds and every translated
  # string blows up at runtime. Vendored and pointed at locally instead.
  #
  # settings.json asks for floating tags (`@4`, `@2`, `@latest`), which break
  # these fixed-output hashes the moment upstream publishes. Each URL pins the
  # exact version its tag resolved to; the substitutions below still have to
  # match settings.json's floating URLs verbatim.
  inlangModules = {
    "plugin-message-format" = fetchurl {
      url = "https://cdn.jsdelivr.net/npm/@inlang/plugin-message-format@4.4.4/dist/index.js";
      hash = "sha256-siz2DrKLPIw84ftjAGEaBVLxLQ2ZXTfE3SyW462AxkU=";
    };
    "plugin-m-function-matcher" = fetchurl {
      url = "https://cdn.jsdelivr.net/npm/@inlang/plugin-m-function-matcher@2.2.13/dist/index.js";
      hash = "sha256-hYYvYwV5O1a/2a/lNosJbmP7Kuqzi3eZwFFRe+NJnAs=";
    };
    "plugin-i18next" = fetchurl {
      url = "https://cdn.jsdelivr.net/npm/@inlang/plugin-i18next@6.2.6/dist/index.js";
      hash = "sha256-M0aMIHfS2AZb3zpAykuUrslGgYB0CRrLTx2dOdRrvwg=";
    };
  };
in
  buildNpmPackage {
    pname = "spoolman-frontend";

    inherit (common) version;

    src = "${common.src}/client_v2";

    npmDepsHash = "sha256-DYUwz3rOdnah3EUBM7dciCdEsRlZG9ijoHiPWLIdRuc=";

    VITE_APIURL = "/api/v1";

    postPatch = ''
      # Module paths in settings.json resolve against the project root, not
      # against project.inlang/.
      mkdir -p modules
      cp ${inlangModules."plugin-message-format"} modules/plugin-message-format.js
      cp ${inlangModules."plugin-m-function-matcher"} modules/plugin-m-function-matcher.js
      cp ${inlangModules."plugin-i18next"} modules/plugin-i18next.js
      # The inlang SDK rewrites the project directory as it loads it, and store
      # copies arrive read-only.
      chmod -R u+w modules project.inlang

      substituteInPlace project.inlang/settings.json \
        --replace-fail 'https://cdn.jsdelivr.net/npm/@inlang/plugin-message-format@4/dist/index.js' './modules/plugin-message-format.js' \
        --replace-fail 'https://cdn.jsdelivr.net/npm/@inlang/plugin-m-function-matcher@2/dist/index.js' './modules/plugin-m-function-matcher.js' \
        --replace-fail 'https://cdn.jsdelivr.net/npm/@inlang/plugin-i18next@latest/dist/index.js' './modules/plugin-i18next.js'
    '';

    # If paraglide cannot load its plugins it compiles an empty catalogue, and
    # vite downgrades every unresolved message to a warning -- so the build
    # succeeds while shipping a UI whose every translated string is undefined
    # at runtime.
    postBuild = ''
      messages=$(ls src/lib/paraglide/messages | wc -l)
      if [ "$messages" -lt 100 ]; then
        echo "paraglide emitted only $messages message modules; the catalogue did not compile" >&2
        exit 1
      fi
      echo "paraglide compiled $messages message modules"
    '';

    # adapter-static writes to build/, not vite's usual dist/.
    installPhase = "cp -r build $out";

    meta =
      common.meta
      // {
        description = "Spoolman frontend";
      };
  }
