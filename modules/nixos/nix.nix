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

        # TODO: Remove after https://github.com/NixOS/nixpkgs/issues/449414 is closed
        (final: prev: {
          ltrace = prev.ltrace.overrideAttrs (oldAttrs: {
            doCheck = false;
          });
        })

        # TODO: Remove after CMake 4 compatibility is fixed upstream (NixOS/nixpkgs#450523)
        (final: prev: {
          imgbrd-grabber = prev.imgbrd-grabber.overrideAttrs (oldAttrs: {
            patches =
              (oldAttrs.patches or [])
              ++ [
                (builtins.toFile "imgbrd-grabber-cmake4-compat.patch" ''
                  diff --git a/CMakeLists.txt b/CMakeLists.txt
                  index 1111111..2222222 100644
                  --- a/CMakeLists.txt
                  +++ b/CMakeLists.txt
                  @@ -1,4 +1,4 @@
                  -cmake_minimum_required(VERSION 3.2)
                  +cmake_minimum_required(VERSION 3.10)

                   project(Grabber)

                  diff --git a/lib/vendor/lexbor/CMakeLists.txt b/lib/vendor/lexbor/CMakeLists.txt
                  index 1111111..2222222 100644
                  --- a/lib/vendor/lexbor/CMakeLists.txt
                  +++ b/lib/vendor/lexbor/CMakeLists.txt
                  @@ -1,4 +1,4 @@
                  -cmake_minimum_required(VERSION 2.8.12)
                  +cmake_minimum_required(VERSION 3.10)

                   project(lexbor C)

                '')
              ];
          });
        })
      ];

      config = {
        allowUnfree = true;

        permittedInsecurePackages = [
          "olm-3.2.16"
          # Required for Jellyfin -- see NixOS/nixpkgs#437865 and jellyfin/jellyfin-media-player#282
          "qtwebengine-5.15.19"
        ];
      };
    };

    nix = let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in {
      settings = {
        experimental-features = "nix-command flakes";
        trusted-users = ["awilliams"];
        netrc-file = config.sops.templates.netrc.path;
      };
      # Opinionated: disable channels
      channel.enable = false;

      # Opinionated: make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

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
          mode = "0440";
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
