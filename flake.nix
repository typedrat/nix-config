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

    # opencode: 1.4.19 -> 1.14.20 (NixOS/nixpkgs#512466)
    nixpkgs-patch-512466 = {
      url = "https://github.com/NixOS/nixpkgs/pull/512466.diff";
      flake = false;
    };

    # opencode: 1.4.20 -> 1.14.24 (NixOS/nixpkgs#513165)
    nixpkgs-patch-513165 = {
      url = "https://github.com/NixOS/nixpkgs/pull/513165.diff";
      flake = false;
    };

    # discord: fetch distros at build time to fix discord-development 0.0.235+ install (NixOS/nixpkgs#507728)
    # NOTE: numeric prefix forces apply-order; #506089 (Krisp) is rebased on top of this PR.
    nixpkgs-patch-discord-01-507728 = {
      url = "https://github.com/NixOS/nixpkgs/pull/507728.diff";
      flake = false;
    };

    # discord: add Krisp patcher to bypass signature check for noise cancellation (NixOS/nixpkgs#506089)
    # NOTE: depends on #507728's source refactor; must apply after it.
    nixpkgs-patch-discord-02-506089 = {
      url = "https://github.com/NixOS/nixpkgs/pull/506089.diff";
      flake = false;
    };

    # vencord: 1.14.7 -> 1.14.10 — required for compatibility with current Discord
    # client (1.14.7's webpack patches break silently against newer Discord builds).
    # Already merged on master as 3d730cb1ecb6 but not yet in our pinned channel.
    nixpkgs-patch-vencord-1-14-10 = {
      url = "https://github.com/NixOS/nixpkgs/commit/3d730cb1ecb627c085a7b585d7e644239965797e.diff";
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
    #
    # NOTE: hyprland-plugins is ALSO pinned. Without it, the daily
    # update-flake-lock workflow advances plugins past the pinned Hyprland
    # rev, which produces a build that runs but aborts at runtime in
    # local__configValuePopulate when hyprbars calls addConfigValueV2
    # (chase-hyprland commit dbe22194 targets post-#13817 Hyprland API,
    # not 8685fd7b). Lift both pins together when ready to move forward.
    hyprland.url = "github:hyprwm/Hyprland/8685fd7b";

    hyprlock.url = "github:hyprwm/hyprlock";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins/b85a56b953";
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
