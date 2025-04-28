{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "rtorrent-exporter";
  version = "1.4.7";

  src = fetchFromGitHub {
    owner = "aauren";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-jXGil0PMZxoZDwIwDF+zIfv8IqR0PpynMMdXiWBpr/0=";
  };

  vendorHash = "sha256-8ms2q1ay7ejYf5HocFcCngCGmS/1v9P9RTavOMo3cmM=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/aauren/rtorrent-exporter/cmd.Version=${version}"
  ];

  env.CGO_ENABLED = 0;

  doCheck = true;

  meta = with lib; {
    description = "Prometheus exporter for rTorrent metrics using XMLRPC";
    homepage = "https://github.com/aauren/rtorrent-exporter";
    license = licenses.mit;
  };
}
