{
  config,
  inputs,
  lib,
  ...
}: {
  options.rat.nix-config.enable = lib.mkEnableOption "opinionated Nix configuration" // {default = true;};

  config = lib.mkIf config.rat.nix-config.enable {
    nixpkgs = {
      overlays = [
        inputs.vscode-extensions.overlays.default
        (final: prev: {
          skyscraper = prev.skyscraper.overrideAttrs (oldAttrs: {
            nativeBuildInputs =
              (oldAttrs.nativeBuildInputs or [])
              ++ [
                final.makeWrapper
              ];

            postInstall =
              (oldAttrs.postInstall or "")
              + ''
                # Install mdb2sqlite.sh script from source
                install -Dm755 supplementary/scraperdata/mdb2sqlite.sh $out/bin/mdb2sqlite

                # Wrap the script to provide mdbtools and sqlite in PATH
                wrapProgram $out/bin/mdb2sqlite \
                  --prefix PATH : ${final.lib.makeBinPath [final.mdbtools final.sqlite]}
              '';
          });
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
        github-api-key = {
          key = "miseGithubToken";
        };
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
      };
    };
  };
}
