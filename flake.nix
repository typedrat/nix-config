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

    # manually apply NixOS/nixpkgs#490985 to fix Traefik configuration
    nixpkgs-patch-490985 = {
      url = "https://github.com/NixOS/nixpkgs/pull/490985.diff";
      flake = false;
    };

    # pkl: 0.29.1 -> 0.31.0 (NixOS/nixpkgs#494791)
    nixpkgs-patch-494791 = {
      url = "https://github.com/NixOS/nixpkgs/pull/494791.diff";
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

    files.url = "github:mightyiam/files";

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
    # Pinned before renderer refactor (a585801+) which broke both the .pc
    # include paths and the plugin API. Must be after b88813c7 (EventBus
    # refactor) which hyprland-plugins b85a56b depends on.
    # hyprwm/hyprland-plugins#627
    hyprland.url = "github:hyprwm/Hyprland/8685fd7b";

    hyprlock.url = "github:hyprwm/hyprlock";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
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

    attic = {
      url = "https://flakehub.com/f/zhaofengli/attic/*";
      # `attic` doesn't build against current Nix, so we have to use an old `nixpkgs` for it.
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    authentik-nix = {
      url = "github:nix-community/authentik-nix";
    };

    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    jellarr = {
      url = "github:venkyr77/jellarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mlnx-ofed-nixos = {
      url = "github:codgician/mlnx-ofed-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nanopkgs = {
      url = "git+https://git.theless.one/nanoyaki/nanopkgs.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixified-ai = {
      url = "https://flakehub.com/f/nixified-ai/flake/*";
    };

    style-search = {
      url = "github:typedrat/style-search";
      inputs.nixpkgs.follows = "nixpkgs";
      # https://github.com/nix-community/bun2nix/pull/81
      inputs.bun2nix.url = "github:krauterbaquette/bun2nix/fix-cache-entry";
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
