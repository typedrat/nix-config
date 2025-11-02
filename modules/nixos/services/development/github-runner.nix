{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.github-runner;
in {
  options.rat.services.github-runner = {
    enable = options.mkEnableOption "GitHub Actions self-hosted runners";

    runners = options.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          url = options.mkOption {
            type = types.str;
            description = "GitHub repository or organization URL";
            example = "https://github.com/owner/repo";
          };

          extraLabels = options.mkOption {
            type = types.listOf types.str;
            default = ["nixos"];
            description = "Extra labels to assign to the runner";
          };

          extraPackages = options.mkOption {
            type = types.listOf types.package;
            default = [];
            description = "Extra packages to make available to the runner";
          };

          ephemeral = options.mkOption {
            type = types.bool;
            default = true;
            description = "Whether the runner should be ephemeral (self-remove after each job)";
          };
        };
      });
      default = {};
      description = "GitHub runners configuration";
      example = {
        my-repo-runner = {
          url = "https://github.com/owner/repo";
          extraLabels = ["nixos" "self-hosted"];
        };
      };
    };

    package = options.mkOption {
      type = types.package;
      default = pkgs.github-runner;
      description = "The GitHub runner package to use";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      # SOPS secrets configuration
      sops.secrets = lib.mkMerge (lib.mapAttrsToList (name: _runnerCfg: {
          "github_runner_tokens/${name}" = {
            sopsFile = ../../../../secrets/github-actions.yaml;
            owner = "github-runner";
            group = "github-runner";
            mode = "0400";
          };
        })
        cfg.runners);

      # Create users and groups
      users.users.github-runner = lib.mkIf (cfg.runners != {}) {
        isSystemUser = true;
        group = "github-runner";
        extraGroups = ["docker"];
        home = "/var/lib/github-runners";
        createHome = true;
        description = "GitHub Actions Runner user";
      };

      users.groups.github-runner = lib.mkIf (cfg.runners != {}) {};

      # Configure GitHub runner services
      services.github-runners =
        lib.mapAttrs (name: runnerCfg: {
          enable = true;
          inherit (runnerCfg) url;
          tokenFile = config.sops.secrets."github_runner_tokens/${name}".path;
          inherit name;
          replace = true;
          inherit (runnerCfg) extraLabels;
          extraPackages = with pkgs;
            [
              # Common packages for GitHub Actions
              git
              curl
              wget
              jq
              docker
              docker-compose
              nodejs
              python3
              # Nix tooling
              nix
              nixfmt-classic
              # Add user-specified packages
              openssh
            ]
            ++ runnerCfg.extraPackages;
          workDir = "/var/lib/github-runners/${name}";
          user = "github-runner";
          group = "github-runner";
          inherit (runnerCfg) ephemeral;
          inherit (cfg) package;
        })
        cfg.runners;

      # Ensure Docker is available if runners need it
      virtualisation.docker = lib.mkIf (cfg.runners != {}) {
        enable = lib.mkDefault true;
      };

      # Create working directories
      systemd.tmpfiles.rules =
        lib.mapAttrsToList (
          name: _runnerCfg: "d /var/lib/github-runners/${name} 0755 github-runner github-runner -"
        )
        cfg.runners;
    })
  ];
}
