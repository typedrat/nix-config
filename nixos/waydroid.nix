{pkgs, ...}: {
  virtualisation.waydroid.enable = true;

  environment.systemPackages = with pkgs; [
    nur.repos.ataraxiasjel.waydroid-script
    waydroid-helper
    python3Packages.pyclip
  ];

  # environment.etc."waydroid-extra/images/system.img".source = "${pkgs.waydroid-lineage}/system.img";
  # environment.etc."waydroid-extra/images/vendor.img".source = "${pkgs.waydroid-lineage}/vendor.img";
}
