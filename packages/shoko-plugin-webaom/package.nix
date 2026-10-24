{callPackage}:
callPackage ../shoko/plugin.nix {
  source = builtins.fromJSON (builtins.readFile ./source.json);
  updateScript = ./update.sh;
}
