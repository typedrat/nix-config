{
  lib,
  buildGoLatestModule,
  fetchFromGitHub,
  nix-update-script,
}:
# go.mod requires a newer toolchain than the default buildGoModule's.
buildGoLatestModule rec {
  pname = "tailsocks";
  version = "1.6.5";

  src = fetchFromGitHub {
    owner = "ItalyPaleAle";
    repo = "tailsocks";
    rev = "v${version}";
    hash = "sha256-BQLYdpct1XrF3gbgL8Y94S7RYkVWARR0AMImbAjh27o=";
  };

  vendorHash = "sha256-nrnCP+lZMUOjKRRENTbwuLiLsEpaiKzPctW+1qbB93k=";

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
