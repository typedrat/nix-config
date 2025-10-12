{
  self',
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # archiving tools
    unzip
    xz
    zip

    # utilities
    age
    cachix
    ffmpeg-full
    frink
    gdu
    github-cli
    github-to-sops
    imagemagickBig
    jd-diff-patch
    jq
    llm
    nix-diff
    nix-prefetch-github
    nix-tree
    pv
    self'.packages.catbox-cli
    self'.packages.qbittorrent-cli
    self'.packages.stable-diffusion-cpp
    socat
    sops
    ssh-to-age
    tokei
    waypipe

    # networking tools
    dnsutils
    ipcalc
    iperf3
    mtr
    nmap

    # misc
    aws-vault
    # For some reason, NixOS/nixpkgs#450333 is taking *forever* to hit `nixos-unstable`, so I'm just disabling it for now.
    # awscli2
    cowsay
    file
    gawk
    gnused
    gnutar
    self'.packages.pyvizio
    tree
    which
    wl-clipboard
    zstd

    # monitoring
    ethtool
    lm_sensors
    lsof
    ltrace
    pciutils
    strace
    sysstat
    usbutils

    # fetch
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
