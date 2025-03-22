# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  cage-xtmapper = pkgs.callPackage ./cage-xtmapper.nix {};
  mpv-jellyfin = pkgs.callPackage ./mpv-jellyfin.nix {
    buildLua = pkgs.mpvScripts.buildLua;
  };
  opensiddur-hebrew-fonts = pkgs.callPackage ./opensiddur-hebrew-fonts.nix {};
  pyvizio = pkgs.callPackage ./pyvizio.nix {};
  waydroid-lineage = pkgs.callPackage ./waydroid-lineage.nix {};
  wayland-getevent = pkgs.callPackage ./wayland-getevent.nix {};
  xmage = pkgs.callPackage ./xmage.nix {};
}
