# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{pkgs, inputs, outputs, ...}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ./firefox.nix
    ./hyprland.nix
    ./packages.nix
    ./spotify.nix
    ./zed.nix
    ./zsh.nix
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      inputs.nur.overlays.default
    ];

    config = {
      allowUnfree = true;
    };
  };

  home = {
    username = "awilliams";
    homeDirectory = "/home/awilliams";

    sessionVariables = {
      VIZIO_IP = "viziocastdisplay.lan";
      VIZIO_AUTH = "Zmge7tbkiz";
    };
  };

  fonts.fontconfig = {
    enable = true;

    defaultFonts = {
      monospace = [
        "JuliaMono"
        "Symbols Nerd Font"
      ];
    };
  };

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "Alexis Williams";
    userEmail = "alexis@typedr.at";
  };

  programs.alacritty.enable = true;

  programs.tmux = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.mpv = {
    enable = true;

    package = pkgs.mpv-unwrapped.wrapper {
      mpv = pkgs.mpv-unwrapped.override {
        vapoursynthSupport = true;
      };

      scripts = with pkgs.mpvScripts; [
        uosc
        thumbfast
        pkgs.mpv-jellyfin
      ];
      youtubeSupport = true;
    };

    config = {
      osd-bar = false;
      border = false;
      video-sync = "display-resample";
    };
  };

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.wezterm = {
    enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
