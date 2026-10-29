{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-themes";
  version = "0-unstable-2026-10-28";

  src = fetchFromGitHub {
    owner = "matcra587";
    repo = "claude-themes";
    rev = "8c3b74f7ec1b3d55cdafc0b18c3d84c21f242745";
    hash = "sha256-AW3brhuC0aI7LWfLXFcS9E+QTqS/IWFQqL2/briJtaM=";
  };

  dontConfigure = true;
  dontBuild = true;

  # One Claude Code plugin per theme family, e.g. $out/catppuccin.
  installPhase = ''
    runHook preInstall
    cp -R plugins $out
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake" "--version=branch"];
  };

  meta = {
    description = "Colour themes for Claude Code, packaged as plugins";
    homepage = "https://github.com/matcra587/claude-themes";
    # Each plugin's manifest declares MIT; the repository has no top-level licence.
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
