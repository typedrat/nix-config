{lib, ...}: {
  # This config tracks nixpkgs unstable (via FlakeHub `0.1`) together with
  # home-manager's master branch (`inputs.home-manager.follows = "nixpkgs"`),
  # so both always share the same package set. During the development window
  # before a release, home-manager's master bumps its release string (e.g.
  # 26.11) ahead of nixpkgs unstable's `lib.trivial.release` (e.g. 26.05),
  # which trips home-manager's release-mismatch warning even though the two
  # are perfectly compatible. Disable the cosmetic check.
  home.enableNixpkgsReleaseCheck = lib.mkDefault false;
}
