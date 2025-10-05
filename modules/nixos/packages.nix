{pkgs, ...}: {
  config = {
    environment.systemPackages = with pkgs; [
      ntfs3g
      curl
      git
      nano
      just
      (nix-output-monitor.overrideAttrs (oldAttrs: {
        patches =
          oldAttrs.patches or []
          ++ [
            (
              fetchpatch
              {
                url = "https://patch-diff.githubusercontent.com/raw/maralorn/nix-output-monitor/pull/203.patch";
                sha256 = "sha256-OOB9oCu41POCMNxG3LVQ5HbV7Dd0gkR9CZSiIwhUpqU=";
              }
            )
          ];
      }))
    ];
  };
}
