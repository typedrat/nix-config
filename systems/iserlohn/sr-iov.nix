{inputs, ...}: let
  interface = "enp101s0np0";
  numOfVFs = 1;
in {
  imports = [
    inputs.mlnx-ofed-nixos.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.mlnx-ofed-nixos.overlays.default
  ];

  hardware.mlnx-ofed = {
    enable = true;
    fwctl.enable = true;
    nvme.enable = true;
    nfsrdma.enable = true;
    kernel-mft.enable = true;
  };

  systemd.services."sriov-enable-${interface}" = {
    description = "Enable SR-IOV";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      echo '${toString numOfVFs}' > /sys/class/net/${interface}/device/sriov_numvfs || echo 'Failed to write sriov_numvfs for ${interface}'
    '';
  };
}
