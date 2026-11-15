{
  config,
  inputs,
  lib,
  ...
}: let
  interface = "enp101s0np0";
  numOfVFs = 1;

  # The input applies its sockaddr_unsized kernel_bind() patch to every 6.18
  # from .57 on, but 6.18.61 reverted that backport and the patch now breaks
  # the build. The assert trips once upstream narrows its range.
  mlnx-nvme = config.boot.kernelPackages.mlnx-nvme.overrideAttrs (prev: let
    lines = lib.splitString "\n" prev.postPatch;
    isBindPatch = lib.hasInfix "kernel-bind-sockaddr-unsized.patch";
  in {
    postPatch = assert lib.any isBindPatch lines;
      lib.concatStringsSep "\n" (lib.filter (l: !isBindPatch l) lines);
  });
in {
  imports = [
    inputs.mlnx-ofed-nixos.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.mlnx-ofed-nixos.overlays.default
  ];

  hardware.mlnx-ofed = {
    enable = true;
    nvme = {
      enable = true;
      package = mlnx-nvme;
    };
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
      dev=/sys/class/net/${interface}/device

      # The VFs exist only to be passed through to guests. Left to itself the
      # host probes a driver for each one, which brings it up as a netdev under
      # a driver-generated random MAC; DHCP then leases it an address on the
      # PF's own subnet. Since arp_ignore is 0 the host answers ARP for the PF's
      # address out of the VF as well, and a peer that caches that reply sends
      # to a MAC the embedded switch holds no filter for. Broadcast still floods
      # through, so ARP resolves and everything else silently disappears.
      #
      # autoprobe only governs VFs created after it is written, and is only
      # writable while numvfs is 0 — hence tearing down before setting it.
      # Skipped once it already reads 0 so restarting this does not yank a VF
      # out from under a running guest.
      if [ "$(cat "$dev/sriov_drivers_autoprobe")" != 0 ]; then
        echo 0 > "$dev/sriov_numvfs"
        echo 0 > "$dev/sriov_drivers_autoprobe"
      fi

      echo '${toString numOfVFs}' > "$dev/sriov_numvfs" || echo 'Failed to write sriov_numvfs for ${interface}'
    '';
  };
}
