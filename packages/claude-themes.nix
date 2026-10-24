{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-themes";
  version = "0-unstable-2026-10-22";

  src = fetchFromGitHub {
    owner = "matcra587";
    repo = "claude-themes";
    rev = "d9de2d4e12ba27dde79979552e002566bf9194f1";
    hash = "sha256-xktgRCmmLBqXKVmGPBHWEQ09h0Gohr7ePaxR82HeUkM=";
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
