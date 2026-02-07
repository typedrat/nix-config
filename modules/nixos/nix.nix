{
  config,
  inputs,
  inputs',
  lib,
  ...
}: {
  options.rat.nix-config.enable = lib.mkEnableOption "opinionated Nix configuration" // {default = true;};

  config = lib.mkIf config.rat.nix-config.enable {
    nixpkgs = {
      overlays = [
        inputs.vscode-extensions.overlays.default

        (_final: prev: {
          nix-update = prev.nix-update.override {
            nix = inputs'.nix.packages.default;
          };
        })
      ];

      config = {
        allowUnfree = true;

        permittedInsecurePackages = [
          "olm-3.2.16"
        ];
      };
    };

    nix = {
      settings = {
        experimental-features = "nix-command flakes";
        trusted-users = ["awilliams"];
        netrc-file = config.sops.templates.netrc.path;
      };

      # Trim old Nix generations to free up space.
      gc = {
        automatic = true;
        persistent = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };

      extraOptions = ''
        !include ${config.sops.templates.nix-access-tokens.path}
      '';
    };

    sops = {
      secrets = {
        civitaiApiToken = {};
        github-api-key = {
          key = "miseGithubToken";
        };
        hfToken = {};
        "attic/cacheToken" = {
          sopsFile = ../../secrets/attic.yaml;
          key = "cacheToken";
        };
      };

      templates = {
        nix-access-tokens = {
          content =
            "access-tokens = "
            + (lib.strings.concatMapAttrsStringSep " " (name: value: "${name}=${value}") {
              "github.com" = config.sops.placeholder.github-api-key;
            });
          mode = "0444";
        };

        netrc = {
          content = ''
            machine ${config.rat.services.attic.subdomain}.${config.rat.services.domainName}
            password ${config.sops.placeholder."attic/cacheToken"}
          '';
          mode = "0440";
        };

        nix-daemon-env = {
          content = ''
            CIVITAI_API_TOKEN=${config.sops.placeholder.civitaiApiToken}
            HF_TOKEN=${config.sops.placeholder.hfToken}
          '';
          mode = "0400";
        };
      };
    };

    systemd.services.nix-daemon.serviceConfig.EnvironmentFile = config.sops.templates.nix-daemon-env.path;
  };
}
