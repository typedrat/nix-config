{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "cclogviewer";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "Brads3290";
    repo = "cclogviewer";
    rev = "v${version}";
    hash = "sha256-aN8IDvHOuMfeG4G8CCzMwYbBao3STOkug04iyzjr5bA=";
  };

  vendorHash = "sha256-pIOUR8TI9tXHKAubCewtl4BmaqZMaLMhhrR5IM7GmRQ=";

  ldflags = ["-s" "-w"];

  subPackages = ["cmd/cclogviewer"];

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Convert Claude Code JSONL log files into interactive HTML";
    homepage = "https://github.com/Brads3290/cclogviewer";
    license = licenses.mit;
    mainProgram = "cclogviewer";
  };
}
