{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  programs.spicetify = {
    enable = true;
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
    settings = {
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
