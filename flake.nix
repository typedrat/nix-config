{
  description = "@typedrat's NixOS configuration.";

  inputs = {
    #region Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-std.url = "github:chessai/nix-std";
    #endregion

    #region `flake-parts`
    flake-parts.url = "github:hercules-ci/flake-parts";

    easy-hosts.url = "github:tgirlcloud/easy-hosts";

    flake-root.url = "github:srid/flake-root";

    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";

    terranix.url = "github:terranix/terranix";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region NixOS Extensions
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region Theming
    apple-emoji = {
      url = "github:samuelngs/apple-emoji-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    typedrat-fonts = {
      url = "git+ssh://git@github.com/typedrat/nix-fonts.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region Hyprland
    hyprland.url = "github:hyprwm/Hyprland";

    hyprlock.url = "github:hyprwm/hyprlock/v0.8.2";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    pyprland.url = "github:hyprland-community/pyprland";

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

    authentik-nix = {
      url = "github:nix-community/authentik-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mlnx-ofed-nixos = {
      url = "github:codgician/mlnx-ofed-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-shoko.url = "github:diniamo/nixpkgs/shokoanime";

    talhelper = {
      url = "github:budimanjojo/talhelper";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #endregion

    #region Extension Repositories
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    #endregion
  };

  outputs = {flake-parts, ...} @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} ({self, ...}: {
      imports = [
        inputs.flake-root.flakeModule
        inputs.home-manager.flakeModules.home-manager
        inputs.pkgs-by-name-for-flake-parts.flakeModule
        inputs.terranix.flakeModule
        inputs.treefmt-nix.flakeModule

        ./systems
      ];

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      flake = {
        lib = import ./lib {
          inherit inputs;
          inherit (inputs.nixpkgs) lib;
        };

        nixosModules = {
          ensure-pcr = {imports = [./modules/extra/nixos/ensure-pcr.nix];};
          port-magic = {imports = [./modules/extra/nixos/port-magic];};
          servarr-multitenant = {imports = [./modules/extra/nixos/servarr-multitenant];};
        };
      };

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        pkgsDirectory = ./pkgs;

        treefmt.config = {
          inherit (config.flake-root) projectRootFile;
          package = pkgs.treefmt;

          programs = {
            alejandra.enable = true;
            deadnix.enable = true;
            statix.enable = true;
          };
        };

        formatter = config.treefmt.build.wrapper;

        terranix = {
          terranixConfigurations = {
            terraform = {
              terraformWrapper = {
                package = pkgs.opentofu;
                extraRuntimeInputs = [pkgs.sops pkgs.openssh];
                prefixText = let
                  target_host = "iserlohn.thisratis.gay";
                  links_to_tunnel = [
                    "lidarr"
                    "prowlarr"
                    "radarr"
                    "radarr-anime"
                    "sonarr"
                    "sonarr-anime"
                  ];

                  mkPortForward = _key: port: "-L ${toString port}:localhost:${toString port}";
                  portForwards = builtins.concatStringsSep " " (
                    builtins.map
                    (key: mkPortForward key (self.nixosConfigurations.iserlohn.config.links.${key}.port or null))
                    links_to_tunnel
                  );
                in ''
                  AWS_ACCESS_KEY_ID=$(sops decrypt ../secrets/default.yaml --extract '["b2"]["keyId"]')
                  AWS_SECRET_ACCESS_KEY=$(sops decrypt ../secrets/default.yaml --extract '["b2"]["applicationKey"]')
                  TF_VAR_passphrase=$(sops decrypt ../secrets/default.yaml --extract '["terraformPassphrase"]')
                  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY TF_VAR_passphrase

                  SSH_CONTROL_PATH=$(mktemp -tu .ssh.sock.XXXXXX)

                  echo "Setting up SSH tunnels to ${target_host}..."
                  ssh -M -S "$SSH_CONTROL_PATH" -fNT ${portForwards} "${target_host}"
                  echo "SSH tunnels established using control socket: $SSH_CONTROL_PATH"

                  function cleanup_ssh_tunnel() {
                    if [ -S "$SSH_CONTROL_PATH" ]; then
                      echo "Closing SSH tunnel control socket..."
                      ssh -S "$SSH_CONTROL_PATH" -O exit "${target_host}" 2>/dev/null || true
                      echo "SSH tunnel terminated."
                    fi
                  }

                  trap cleanup_ssh_tunnel EXIT
                '';
              };

              modules = [
                {
                  _module.args = {
                    inherit (self.nixosConfigurations.iserlohn.config) links;
                  };
                }

                ./terraform
              ];
            };
          };
        };

        packages = builtins.listToAttrs (builtins.map
          (
            key: {
              name = "${key}.tf.json";
              value = config.terranix.terranixConfigurations.${key}.result.terraformConfiguration;
            }
          )
          (builtins.attrNames config.terranix.terranixConfigurations));
      };
    });
}
