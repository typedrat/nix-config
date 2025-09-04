{
  self',
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # archiving tools
    zip
    xz
    unzip

    # utilities
    sops
    age
    ssh-to-age
    github-to-sops
    github-cli
    jq
    jd-diff-patch
    frink
    nix-diff
    nix-prefetch-github
    nix-tree
    cachix
    socat
    gdu
    pv
    imagemagickBig
    tokei
    self'.packages.catbox-cli
    waypipe
    self'.packages.qbittorrent-cli
    llm
    self'.packages.stable-diffusion-cpp

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
    self'.packages.pyvizio
    awscli2
    aws-vault

    # monitoring
    strace
    ltrace
    lsof
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    (fastfetch.overrideAttrs (oldAttrs: {
      buildInputs =
        (oldAttrs.buildInputs or [])
        ++ [
          zfs
        ];
    }))
    hyfetch
  ];
}
