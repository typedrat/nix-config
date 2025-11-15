{pkgs, ...}: {
  config = {
    environment.systemPackages = with pkgs; [
      ntfs3g
      curl
      git
      nano
      just
      nix-output-monitor
    ];
  };
}
