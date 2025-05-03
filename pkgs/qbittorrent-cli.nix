{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "qbittorrent-cli";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "ludviglundgren";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-7EoclncZwWSteSigSEIHW9TOUf3azGSMMFCTGXRXeCI=";
  };

  vendorHash = "sha256-sJE4u5CCoD+jr3iGB/jz7or1bl+3nPtLNSUhM1jT1kk=";

  ldflags = ["-s" "-w"];

  meta = with lib; {
    description = "CLI to manage qBittorrent";
    homepage = "https://github.com/ludviglundgren/qbittorrent-cli";
    license = licenses.mit;
    mainProgram = "qbt";
  };
}
