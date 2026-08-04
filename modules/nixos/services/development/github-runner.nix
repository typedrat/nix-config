{
  config,
  inputs',
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
              nixfmt
              inputs'.determinate.packages.default
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

    # Workflows authenticate to FlakeHub through determinate-nixd, and a machine
    # has exactly one credential slot: the job's OIDC token lands in
    # /nix/var/determinate and displaces both the host's token and the
    # auth_state.json it would refresh from. That token is good for five
    # minutes, so once a job has run, every build on this host gets a 401 from
    # the cache until someone logs in again by hand.
    #
    # The runners are ephemeral and exit after a single job, so restoring the
    # host's own credential on stop costs one login per job. `+` runs it as root
    # rather than as the runner user, which keeps the long-lived token out of
    # reach of the very workflows that make this necessary, and `-` stops a
    # failed refresh from dragging the runner unit into a failed state with it.
    (modules.mkIf cfg.enable {
      sops.secrets.flakehub_token.mode = "0400";

      systemd.services =
        lib.mapAttrs' (
          name: _runnerCfg:
            lib.nameValuePair "github-runner-${name}" {
              serviceConfig.ExecStopPost = [
                "-+${lib.getExe' inputs'.determinate.packages.default "determinate-nixd"} auth login token --token-file ${config.sops.secrets.flakehub_token.path}"
              ];
            }
        )
        cfg.runners;
    })
  ];
}
