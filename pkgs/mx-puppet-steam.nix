{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_18,
  pkg-config,
  libjpeg,
  pixman,
  cairo,
  pango,
  postgresql,
}:
buildNpmPackage (_finalAttrs: {
  pname = "mx-puppet-steam";
  version = "unstable-11ce294";

  src = fetchFromGitHub {
    owner = "icewind1991";
    repo = "mx-puppet-steam";
    rev = "11ce29418f4ddf0da67e7e6c34a09826892a70e8";
    hash = "sha256-ARAB3xdMKbYEC0eCmrh3GL5AQ9TpeZnR86hnWRLiB6Q=";
  };

  nodejs = nodejs_18;

  npmDepsHash = "sha256-nIpQZDgYd1KtDH2GrfY6jggRGl91L1qyTB6idMmXpEg=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libjpeg
    pixman
    cairo
    pango
    postgresql
  ];

  meta = {
    description = "Matrix <-> Steam puppeting bridge based on mx-puppet-bridge";
    homepage = "https://github.com/icewind1991/mx-puppet-steam";
    license = lib.licenses.asl20;
  };
})
