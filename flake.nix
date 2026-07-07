{
  description = "@typedrat's NixOS configuration.";

  inputs = {
    #region Core
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    nix.follows = "determinate/nix";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    disko = {
      url = "https://flakehub.com/f/nix-community/disko/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-std.url = "github:chessai/nix-std";

    #endregion

    #region nixpkgs patches
    # Add patches by creating inputs prefixed with "nixpkgs-patch-"

    # claude-code: 2.1.197 -> 2.1.198 (NixOS/nixpkgs#537680)
    nixpkgs-patch-537680 = {
      url = "https://github.com/NixOS/nixpkgs/pull/537680.diff";
      flake = false;
    };

    # claude-code: 2.1.198 -> 2.1.199 (NixOS/nixpkgs#538039)
    nixpkgs-patch-538039 = {
      url = "https://github.com/NixOS/nixpkgs/pull/538039.diff";
      flake = false;
    };

    # claude-code: 2.1.199 -> 2.1.201 (NixOS/nixpkgs#538449)
    nixpkgs-patch-538449 = {
      url = "https://github.com/NixOS/nixpkgs/pull/538449.diff";
      flake = false;
    };

    #endregion

    #region home-manager patches
    # Add patches by creating inputs prefixed with "home-manager-patch-"

    #endregion

    #region `flake-parts`
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/*";

    flake-parts.url = "https://flakehub.com/f/hercules-ci/flake-parts/*";

    flake-root.url = "https://flakehub.com/f/srid/flake-root/*";

    files.url = "github:mightyiam/files/3039848";

    github-actions-nix.url = "https://flakehub.com/f/synapdeck/github-actions-nix/*";

    terranix.url = "github:terranix/terranix";

    treefmt-nix = {
      url = "https://flakehub.com/f/numtide/treefmt-nix/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region NixOS Extensions
    lanzaboote = {
      url = "https://flakehub.com/f/nix-community/lanzaboote/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote-rust-overlay = {
      url = "https://flakehub.com/f/oxalica/rust-overlay/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "https://flakehub.com/f/nix-community/impermanence/*";

    flakehub-deploy = {
      url = "https://flakehub.com/f/typedrat/flakehub-deploy/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region Theming
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bentu404-cursors = {
      url = "github:typedrat/bentu404-cursors";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
    };

    catppuccin-element = {
      url = "github:catppuccin/element";
      flake = false;
    };

    catppuccin-imhex = {
      url = "github:catppuccin/imhex";
      flake = false;
    };

    catppuccin-process-compose = {
      url = "github:catppuccin/process-compose";
      flake = false;
    };

    catppuccin-shoko-webui = {
      url = "github:typedrat/catppuccin-shoko-webui";
      flake = false;
    };

    catppuccin-tauon-music-box = {
      url = "github:typedrat/catppuccin-tauon-music-box";
      flake = false;
    };

    catppuccin-zen = {
      url = "github:catppuccin/zen-browser";
      flake = false;
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    typedrat-fonts = {
      url = "https://flakehub.com/f/typedrat/nix-fonts/*";
    };
    #endregion

    #region Hyprland
    hyprland.url = "github:hyprwm/Hyprland";

    hyprlock.url = "github:hyprwm/hyprlock";

    hyprland-plugins = {
      # TEMP: hyprwm/hyprland-plugins#685 (hyprbars and hyprfocus: chase Hyprland)
      url = "github:LionHeartP/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    pyprland = {
      url = "github:hyprland-community/pyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wayland-pipewire-idle-inhibit = {
      url = "github:rafaelrc7/wayland-pipewire-idle-inhibit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region Software Outside of Nixpkgs
    anime-game-launcher = {
      url = "github:ezKEa/aagl-gtk-on-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop-debian = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    authentik-nix = {
      url = "github:nix-community/authentik-nix";
    };

    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Handy: free, offline, extensible speech-to-text. Ships its own flake with
    # a package, a NixOS module (programs.handy: /dev/uinput udev rule for
    # rdev's global-hotkey grab) and an HM module (services.handy: autostart).
    #
    # Pinned to koloved's flatpak_wayland branch (cjpais/Handy#1560), which adds
    # the xdg-desktop-portal GlobalShortcuts backend ("portal") for native
    # Wayland global hotkeys. Repoint to github:cjpais/Handy once it merges.
    handy = {
      url = "github:koloved/Handy/flatpak_wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jellarr = {
      url = "github:venkyr77/jellarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mediatek-mt7927-dkms = {
      url = "github:jetm/mediatek-mt7927-dkms";
      flake = false;
    };

    mlnx-ofed-nixos = {
      url = "github:codgician/mlnx-ofed-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nanopkgs = {
      url = "git+https://git.theless.one/nanoyaki/nanopkgs.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No `nixpkgs.follows`: this pins its own nixpkgs so that the prebuilt
    # output already published to FlakeHub keeps matching what we consume,
    # instead of drifting (and forcing a local rebuild) every time our own
    # nixpkgs input moves.
    orca-slicer-nanashi = {
      url = "https://flakehub.com/f/typedrat/orca-slicer-nanashi-nix/*";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixified-ai = {
      url = "https://flakehub.com/f/nixified-ai/flake/*";
    };

    # Pinned: later revs have a duplicate `home.file` key in the HM module
    peon-ping = {
      url = "github:PeonPing/peon-ping/7a16f0b1da9dc73b5ada2393ba36482a89b42913";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    style-search = {
      url = "github:typedrat/style-search";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region Extension Repositories
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #endregion
  };

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [./flake];

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
}
