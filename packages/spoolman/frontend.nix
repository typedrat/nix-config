{
  buildNpmPackage,
  callPackage,
}: let
  common = callPackage ./common.nix {};
in
  buildNpmPackage {
    pname = "spoolman-frontend";

    inherit (common) version;

    src = "${common.src}/client_v2";

    npmDepsHash = "sha256-DYUwz3rOdnah3EUBM7dciCdEsRlZG9ijoHiPWLIdRuc=";

    VITE_APIURL = "/api/v1";

    # adapter-static writes to build/, not vite's usual dist/.
    installPhase = "cp -r build $out";

    meta =
      common.meta
      // {
        description = "Spoolman frontend";
      };
  }
