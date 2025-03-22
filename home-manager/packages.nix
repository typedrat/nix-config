{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # GUI stuff to factor out
    jellyfin-mpv-shim
    jellyfin-media-player
    wev
    slack
    wineWowPackages.stable
    nur.repos.bandithedoge.sgdboop-bin
    gamescope
    bottles
    lutris
    winetricks
    telegram-desktop
    cinny-desktop
    qbittorrent
    inputs.catppuccin.packages.${pkgs.stdenv.system}.whiskers
    (lmstudio.override {
      version = "0.3.13";
      rev = "2";
      hash = "sha256-WgUhfk8FiOIuaqnE1h0+rNxPEQIxedF+D0g1fsMpSQg=";
    })
    remmina
    freerdp3

    # Rust
    inputs.fenix.packages.${pkgs.stdenv.system}.stable.defaultToolchain

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
    frink
    libguestfs-with-appliance
    nix-diff
    nix-tree
    nix-output-monitor
    socat
    gdu
    pv

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
