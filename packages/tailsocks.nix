{
  lib,
  buildGoLatestModule,
  fetchFromGitHub,
  nix-update-script,
}:
# go.mod requires a newer toolchain than the default buildGoModule's.
buildGoLatestModule rec {
  pname = "tailsocks";
  version = "1.6.4";

  src = fetchFromGitHub {
    owner = "ItalyPaleAle";
    repo = "tailsocks";
    rev = "v${version}";
    hash = "sha256-M5R4DCcvGWnSIZJ7gRqKp+QvNihEXidTb9TxsuGPH24=";
  };

  vendorHash = "sha256-2k0Pi6vFA3fbKxuJj+eesEkehw1u/w/tW0OxraON6KQ=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/italypaleale/tailsocks/buildinfo.AppVersion=${version}"
    "-X github.com/italypaleale/tailsocks/buildinfo.Production=1"
  ];

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = with lib; {
    description = "Route traffic through a Tailscale exit node using a local SOCKS5 or HTTP proxy";
    homepage = "https://github.com/ItalyPaleAle/tailsocks";
    license = licenses.mit;
    mainProgram = "tailsocks";
  };
}
