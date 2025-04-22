# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./aagl.nix
    ./alien.nix
    ./bluetooth.nix
    ./docker.nix
    ./greetd.nix
    ./hardware-configuration.nix
    ./hyprland.nix
    ./kwallet.nix
    ./lanzaboote.nix
    ./plymouth.nix
    ./ssh.nix
    ./steam.nix
    ./theming.nix
    ./virt-manager.nix
    ./waydroid.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      inputs.nix-vscode-extensions.overlays.default
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;

      permittedInsecurePackages = [
        "olm-3.2.16"
      ];
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;

      trusted-users = ["awilliams"];
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

    # Trim old Nix generations to free up space.
    gc = {
      automatic = true;
      persistent = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.timeout = 1;
  boot.loader.efi.canTouchEfiVariables = true;

  # use xanmod with ZFS
  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.extraModulePackages = [
    config.boot.kernelPackages.${pkgs.zfs.kernelModuleAttribute}
  ];

  hardware.xpadneo.enable = true;

  networking.hostName = "hyperion";
  networking.hostId = "0a2e777f";

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ja_JP.UTF-8/UTF-8"
  ];

  users = {
    users = {
      awilliams = {
        uid = 1000;
        isNormalUser = true;
        extraGroups = ["docker" "games" "wheel"];
        shell = pkgs.zsh;
      };
    };

    groups = {
      games = {
        gid = 420;
        name = "games";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    just
    ntfs3g
    nix-output-monitor
  ];
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
  };
  boot.kernelModules = ["i2c-dev"];

  programs.zsh.enable = true;
  environment.pathsToLink = ["/share/zsh"];

  security.sudo.extraConfig = ''
    Defaults        timestamp_timeout=30
  '';

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
