{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "claude-powerline";
  version = "1.9.15";

  src = fetchFromGitHub {
    owner = "Owloops";
    repo = "claude-powerline";
    rev = "v${version}";
    hash = "sha256-EfRpvI3OXGM7WFkeQwwEOkOxjwMmxGW0oH9iBQMg5iQ=";
  };

  npmDepsHash = "sha256-HmoeZsurIQYFA2+DzODV2Y3/u4EjfpZkb5XizYlFDaM=";

  meta = with lib; {
    description = "A vim-style powerline statusline for Claude Code with real-time usage tracking, git integration, and custom themes";
    homepage = "https://github.com/Owloops/claude-powerline";
    license = licenses.mit;
    mainProgram = "claude-powerline";
  };
}
