# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # example = pkgs.callPackage ./example { };
  mpv-jellyfin = pkgs.callPackage ./mpv-jellyfin.nix {
    buildLua = pkgs.mpvScripts.buildLua;
  };
  opensiddur-hebrew-fonts = pkgs.callPackage ./opensiddur-hebrew-fonts.nix {};
  pyvizio = pkgs.callPackage ./pyvizio.nix {};
  rofi-games = pkgs.callPackage ./rofi-games/package.nix {};
  waydroid-lineage = pkgs.callPackage ./waydroid-lineage.nix {};
  xmage = pkgs.callPackage ./xmage.nix {};
}
