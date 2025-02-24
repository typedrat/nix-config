{pkgs, ...}: {
  home.packages = with pkgs; [
    fastfetch
    hyfetch
    vesktop
    spotify
    jellyfin-mpv-shim

    # archiving tools
    zip
    xz
    unzip

    # utilities
    jq
    jd-diff-patch
    lsd

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
