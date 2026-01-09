{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-facter-modules.nixosModules.facter
    ./disko-config.nix
  ];

  # TODO: Generate facter report on target system with:
  #   nix run github:numtide/nixos-facter -- -o /tmp/facter.json
  # Then copy it to this directory:
  #   cp /tmp/facter.json systems/ulysses/facter.json
  facter.reportPath = ./facter.json;

  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "ulysses";
  networking.hostId = "7e104ef9";

  # TODO: Set the correct device path in disko-config.nix
  # disko.devices.disk.main.device = "/dev/disk/by-id/YOUR_DEVICE_ID";

  rat = {
    boot.loader = "lanzaboote";

    gui = {
      enable = true;
      hyprland = {
        # TODO: Configure monitors for your setup
        # Use `hyprctl monitors` to find monitor names and resolutions
        monitors = [
          # "DP-1,1920x1080@60.0,0x0,1.0"
        ];
        workspaces = [
          # "1, monitor:DP-1, persistent=true"
        ];
      };
    };

    theming.fonts.enableGoogleFonts = false;
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
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
