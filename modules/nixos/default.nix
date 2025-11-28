{
  imports = [
    ../../cachix.nix

    ./boot
    ./games
    ./gui
    ./hardware
    ./security
    ./services
    ./theming
    ./virtualisation
    ./alien.nix
    ./appimage.nix
    ./impermanence.nix
    ./java.nix
    ./nix.nix
    ./packages.nix
    ./polkit.nix
    ./sops.nix
    ./ssh.nix
    ./users.nix
    ./zfs.nix
  ];

  config = {
    time.timeZone = "America/Los_Angeles";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
    ];

    programs.zsh.enable = true;
    environment.pathsToLink = ["/share/zsh"];
  };
}
