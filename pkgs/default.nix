# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: let
  buildFirefoxXpiAddon = pkgs.callPackage ./lib/buildFirefoxXpiAddon.nix {};
in {
  bypass-paywalls-clean = pkgs.callPackage ./bypass-paywalls-clean.nix {
    inherit buildFirefoxXpiAddon;
  };
  cage-xtmapper = pkgs.callPackage ./cage-xtmapper.nix {};
  fontbase = pkgs.callPackage ./fontbase.nix {};
  lncrawl = pkgs.callPackage ./lncrawl.nix {};
  mpv-jellyfin = pkgs.callPackage ./mpv-jellyfin.nix {
    inherit (pkgs.mpvScripts) buildLua;
  };
  opensiddur-hebrew-fonts = pkgs.callPackage ./opensiddur-hebrew-fonts.nix {};
  pyvizio = pkgs.callPackage ./pyvizio.nix {};
  waydroid-lineage = pkgs.callPackage ./waydroid-lineage.nix {};
  wayland-getevent = pkgs.callPackage ./wayland-getevent.nix {};
  xmage = pkgs.callPackage ./xmage.nix {};
  zen-internet = pkgs.callPackage ./zen-internet.nix {
    inherit buildFirefoxXpiAddon;
  };
}
