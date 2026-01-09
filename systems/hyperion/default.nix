{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.config.rocmSupport = true;

  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "hyperion";
  networking.hostId = "0a2e777f";

  rat = {
    boot.loader = "lanzaboote";

    games = {
      enable = true;
      animeGameLaunchers.enable = true;
      steam.enable = true;
    };

    gui = {
      enable = true;
      hyprland = {
        monitors = [
          "DP-2,3840x2160@60.0,0x1080,1.0"
          "HDMI-A-1,3840x2160@60.0,960x0,2.0"
        ];
        workspaces = [
          "1, monitor:DP-2, persistent=true"
          "2, monitor:DP-2, persistent=true"
          "3, monitor:DP-2, persistent=true"
          "4, monitor:DP-2, persistent=true"
          "5, monitor:DP-2, persistent=true"
          "6, monitor:DP-2, persistent=true"
          "name:tv, monitor:HDMI-A-1, persistent=true"
        ];
      };
    };

    theming.fonts.enableGoogleFonts = false;
    hardware.openrgb.enable = true;
    hardware.usbmuxd.enable = true;
    java.enable = true;
    nix-ld.enable = true;
    polkit.unprivilegedPowerManagement = true;
    security.sudo.extendedTimeout.enable = true;
    virtualisation.docker.enable = true;

    zfs = {
      enable = true;
      rootPool = "zpool";
      rootDataset = "root";
    };

    # User configuration (system-specific overrides)
    users.awilliams = {
      enable = true;
      gui = {
        enable = true;
        hyprland.launcher = "vicinae";
        terminal.ghostty.enable = true;

        games.retroarch = {
          enable = true;
          cores = libretro:
            with libretro; [
              atari800
              beetle-lynx
              beetle-ngp
              beetle-pce
              beetle-pcfx
              beetle-psx-hw
              beetle-saturn
              beetle-supergrafx
              beetle-vb
              blastem
              bluemsx
              bsnes-hd
              dolphin
              fbneo
              flycast
              freeintv
              fuse
              genesis-plus-gx
              hatari
              melonds
              mesen
              mgba
              np2kai
              opera
              pcsx2
              ppsspp
              puae
              sameboy
              vice-xvic
              vice-xcbm2
              vice-x64sc
              vice-x128
              vice-xpet
              same_cdi
              stella
            ];
        };
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
