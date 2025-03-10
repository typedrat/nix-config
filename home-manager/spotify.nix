{
  lib,
  pkgs,
  inputs,
  osConfig,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
  catppuccin-ncspot = inputs.catppuccin-ncspot.packages.${pkgs.stdenv.system}.default;

  flavor = osConfig.catppuccin.flavor;
  accent = osConfig.catppuccin.accent;
in {
  programs.spicetify = {
    enable = true;

    theme = spicePkgs.themes.catppuccin;
    colorScheme = flavor;
  };

  programs.ncspot = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "ncspot-wrapped";
      paths = [
        (pkgs.ncspot.override
          {
            ueberzug = pkgs.ueberzugpp;
            withCover = true;
            withShareSelection = true;
          })
      ];
      postBuild = ''
        rm "$out/share/applications/ncspot.desktop"
      '';
    };
    settings =
      (builtins.fromTOML (
        builtins.readFile "${catppuccin-ncspot}/ncspot-${flavor}-${accent}.toml"
      ))
      // {
        "use_nerdfont" = true;
        "notify" = true;
        "library_tabs" = [
          "tracks"
          "albums"
          "artists"
          "playlists"
          "browse"
        ];
        "hide_display_names" = true;
      };
  };
  xdg.desktopEntries.ncspot = lib.mkForce {
    name = "ncspot";
    genericName = "TUI Spotify client";
    icon = "ncspot";
    exec = "alacritty --class ncspot --title ncspot --command ncspot";
    terminal = false;
    categories = ["AudioVideo" "Audio"];
    settings = {
      StartupWMClass = "ncspot";
    };
  };
}
