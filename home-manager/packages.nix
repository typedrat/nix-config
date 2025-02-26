{pkgs, ...}: {
  home.packages = with pkgs; [
    vesktop

    # kubernetes stuff
    kubectl
    helm
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

    # networking tools
    mtr
    iperf3
    dnsutils
    nmap
    ipcalc

    # misc
    fastfetch
    hyfetch
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
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
  ];
}
