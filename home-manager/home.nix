# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  pkgs,
  osConfig,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    ./firefox
    ./discord
    ./hyprland
    ./theming
    ./wezterm
    ./ai.nix
    ./docker.nix
    ./packages.nix
    ./process-compose.nix
    ./productivity.nix
    ./rclone.nix
    ./sops.nix
    ./spotify.nix
    ./webdev.nix
    ./windows-vm.nix
    ./zed.nix
    ./zsh.nix
  ];

  # Trim old Nix generations to free up space.
  nix.gc = {
    automatic = true;
    persistent = true;
    frequency = "daily";
    options = "--delete-older-than 7d";
  };

  home = {
    username = "awilliams";
    homeDirectory = "/home/awilliams";
  };

  systemd.user.sessionVariables = {
    TZ = osConfig.time.timeZone;
    VIZIO_IP = "viziocastdisplay.lan";
    VIZIO_AUTH = "Zmge7tbkiz";
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

    extraConfig = {
      init = {
        defaultBranch = "master";
      };

      push = {
        autoSetupRemote = true;
      };
    };
  };
  services.ssh-agent.enable = true;

  programs.alacritty.enable = true;

  programs.tmux = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.mangohud.enable = true;

  programs.mpv = {
    enable = true;

    package = pkgs.mpv-unwrapped.wrapper {
      mpv = pkgs.mpv-unwrapped.override {
        vapoursynthSupport = true;
      };

      scripts = with pkgs.mpvScripts; [
        mpris
        mpv-discord
        sponsorblock
        thumbfast
        uosc
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

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.05";
}
