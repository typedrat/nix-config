{
  lib,
  fetchFromGitHub,
  unstableGitUpdater,
  buildLua,
  mpv-unwrapped,
}:
buildLua {
  pname = "mpv-jellyfin";
  version = "0-unstable-2025-01-29";

  src = fetchFromGitHub {
    owner = "EmperorPenguin18";
    repo = "mpv-jellyfin";
    rev = "ca19e941da8171d9408e9ba6fadee873f13f1bcb";
    hash = "sha256-tkcx5agoLQ6+U8t89ZHADe0LFttnBnCrhlz4n9ugU6Q=";
  };
  passthru.updateScript = unstableGitUpdater {};

  passthru.extraWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [mpv-unwrapped])
  ];

  passthru.scriptName = "jellyfin";
  scriptPath = "scripts/jellyfin.lua";

  meta = {
    description = "mpv plugin that turns it into a Jellyfin client";
    homepage = "https://github.com/EmperorPenguin18/mpv-jellyfin";
    license = lib.licenses.unlicense;
  };
}
