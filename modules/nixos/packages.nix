{pkgs, ...}: {
  config = {
    environment.systemPackages = with pkgs; [
      ntfs3g
      curl
      git
      lm_sensors
      nano
      just
      nix-output-monitor
      nvme-cli
    ];
  };
}
