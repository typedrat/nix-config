# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
    ./editor-audition.nix
    ./firefox.nix
    ./packages.nix
    ./vscode.nix
    ./zsh.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
      inputs.nur.overlays.default
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
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

  programs.alacritty = {
    enable = true;
  };

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
      "osd-bar" = false;
      "border" = false;
      "video-sync" = "display-resample";
    };
  };

  programs.ncspot = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "ncspot-wrapped";
      paths = [
        (pkgs.ncspot.override
          {
            ueberzug = pkgs.ueberzugpp;
            withCover = true;
            withShareSelection = true;
          })
      ];
      postBuild = ''
        rm "$out/share/applications/ncspot.desktop"
      '';
    };
    settings = {
      "use_nerdfont" = true;
      "notify" = true;
      "library_tabs" = [
        "tracks"
        "albums"
        "artists"
        "playlists"
        "browse"
      ];
      "hide_display_names" = true;
    };
  };
  xdg.desktopEntries.ncspot = lib.mkForce {
    name = "ncspot";
    genericName = "TUI Spotify client";
    icon = "ncspot";
    exec = "alacritty --class ncspot --title ncspot --command ncspot";
    terminal = false;
    categories = ["AudioVideo" "Audio"];
    settings = {
      StartupWMClass = "ncspot";
    };
  };

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
