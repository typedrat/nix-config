{callPackage}:
callPackage ../shoko/plugin.nix {
  source = builtins.fromJSON (builtins.readFile ./source.json);
  # AniList registers its icon a second time as the AniList metadata source's.
  imageAliases."anilist-icon" = "icon";
  updateScript = ./update.sh;
}
