{
  config,
  self',
  inputs',
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # GUI stuff to factor out
    self'.packages.xmage
    jellyfin-mpv-shim
    jellyfin-media-player
    wev
    waypipe
    slack
    wineWowPackages.stable
    gamescope
    bottles
    lutris
    winetricks
    telegram-desktop
    cinny-desktop
    qbittorrent
    inputs'.catppuccin.packages.whiskers
    cherry-studio
    gimp
    inkscape
    qalculate-qt

    # Rust
    inputs'.fenix.packages.stable.defaultToolchain

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
    sops
    jq
    jd-diff-patch
    frink
    libguestfs-with-appliance
    nix-diff
    nix-tree
    socat
    gdu
    pv
    imagemagickBig
    tokei
    self'.packages.lncrawl

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

  programs.bat.enable = true;
  programs.zsh.shellAliases.cat = "bat";

  programs.bottom.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    colors = "auto";
    icons = "auto";
  };

  programs.fd = {
    enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    fileWidgetCommand = "${lib.getExe config.programs.fd.package} --type f";

    defaultOptions = [
      ''--preview \"${lib.getExe config.programs.bat.package} --color=always --style=numbers --line-range=:500 {}\"''
    ];
  };

  programs.jq.enable = true;

  programs.lazygit.enable = true;

  programs.ripgrep.enable = true;

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
