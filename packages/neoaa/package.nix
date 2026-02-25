{
  lib,
  stdenv,
  fetchFromGitHub,
  zlib,
  openssl,
}:
stdenv.mkDerivation {
  pname = "neoaa";
  version = "0-unstable-2025-06-09";

  src = fetchFromGitHub {
    owner = "0xilis";
    repo = "neoaa";
    rev = "d1c2e00a1c60f23afd84a59fccd14c1c2a8f03fa";
    hash = "sha256-HaGnlir7ko/TT1Yd6SZBMiYb/E/nky7eoNTYtSryP24=";
    fetchSubmodules = true;
  };

  buildInputs = [zlib openssl];

  # All nested Makefiles hardcode CC=clang; override to use stdenv cc
  preBuild = ''
    makeFlagsArray+=(CC=$CC)
    export MAKEFLAGS="CC=$CC"
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/usr/bin/neoaa $out/bin/neoaa
    runHook postInstall
  '';

  meta = {
    description = "Open-source Apple Archive CLI tool for Linux and macOS";
    homepage = "https://github.com/0xilis/neoaa";
    license = lib.licenses.mit;
    mainProgram = "neoaa";
    platforms = lib.platforms.unix;
  };
}
