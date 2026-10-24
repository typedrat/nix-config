{callPackage}:
callPackage ../shoko/plugin.nix {
  source = builtins.fromJSON (builtins.readFile ./source.json);
  # TMDB registers its icon a second time as the TMDB metadata source's.
  imageAliases."tmdb-icon" = "icon";
  updateScript = ./update.sh;
}
