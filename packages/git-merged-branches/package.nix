{
  python3Packages,
  writers,
}:
writers.writePython3Bin "git-merged-branches" {
  libraries = with python3Packages; [
    click
    gitpython
    pygithub
    rich
    uv-build
  ];
} (builtins.readFile ./git-merged-branches.py)
