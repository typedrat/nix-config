{pkgs, ...}: {
  home.packages = with pkgs; [
    (discord.override {
      withOpenASAR = true;
      withVencord = true;
    })

    # kubernetes stuff
    kubectl
    kubernetes-helm
    fluxcd
    cilium-cli
    istioctl
    opentofu

    # archiving tools
    zip
    xz
    unzip

    # utilities
    jq
    jd-diff-patch
    lsd
    frink
    bottom
    libguestfs-with-appliance
    nix-diff
    nix-tree
    socat
    wev

    # networking tools
    mtr
    iperf3
    dnsutils
    nmap
    ipcalc

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    wl-clipboard
    pyvizio

    # monitoring
    strace
    ltrace
    lsof
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    (unstable.fastfetch.overrideAttrs (oldAttrs: {
      buildInputs =
        (oldAttrs.buildInputs or [])
        ++ [
          zfs
        ];
    }))
    hyfetch
  ];
}
