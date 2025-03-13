{pkgs, ...}: {
  home.packages = with pkgs; [
    fuse-overlayfs
    passt
    dive
    lazydocker
  ];
}
