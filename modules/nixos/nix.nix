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

        (_final: _prev: {
          nix = inputs'.nix.packages.default;
        })

        # Disable openldap tests on i686 to fix build (https://github.com/NixOS/nixpkgs/issues/513245)
        (_final: prev: {
          openldap = prev.openldap.overrideAttrs {
            doCheck = !prev.stdenv.hostPlatform.isi686;
          };
        })

        # Remove unsupported environment warning popup
        (_final: prev: {
          bottles = prev.bottles.override {
            removeWarningPopup = true;
          };
        })

        # Disable flaky concurrency test in python-mpv that intermittently fails
        # with MPV_ERROR_NOMEM (-12) under the build sandbox.
        (_final: prev: {
          pythonPackagesExtensions =
            prev.pythonPackagesExtensions
            ++ [
              (_pyFinal: pyPrev: {
                mpv = pyPrev.mpv.overrideAttrs (oldAttrs: {
                  disabledTests = (oldAttrs.disabledTests or []) ++ ["test_wait_for_property_concurrency"];
                });
              })
            ];
        })

        # nodejs 20 (bundled by github-runner for the Actions Node 20 runtime)
        # fails its check phase on this host: test-fs-readdir-ucs2 creates a file
        # with an invalid UCS-2 byte sequence as its name, but iserlohn's ZFS
        # datasets use utf8only=on, so the kernel rejects the open() with EILSEQ.
        # The test only treats EINVAL as "filesystem doesn't support UCS-2 -> skip".
        # Upstream declined to fix this (NixOS maintainer typedrat's report,
        # https://github.com/nodejs/node/issues/57209, closed as not planned), so
        # patch the test to also skip on EILSEQ.
        #
        # The check phase runs in nodejs-slim_20 (the real build); nodejs_20 is
        # just a symlinkJoin wrapper over it, so we must patch the slim derivation
        # and rebuild the wrapper from the patched slim.
        (_final: prev: let
          nodejs-slim_20 = prev.nodejs-slim_20.overrideAttrs (oldAttrs: {
            postPatch =
              (oldAttrs.postPatch or "")
              + ''
                substituteInPlace test/parallel/test-fs-readdir-ucs2.js \
                  --replace-fail \
                    "if (e.code === 'EINVAL')" \
                    "if (e.code === 'EINVAL' || e.code === 'EILSEQ')"
              '';
          });
        in {
          inherit nodejs-slim_20;
          # nodejs_20 = callPackage symlink.nix { nodejs-slim = nodejs-slim_20; },
          # so rebuild the symlinkJoin wrapper against the patched slim derivation.
          nodejs_20 = prev.nodejs_20.override {nodejs-slim = nodejs-slim_20;};
        })
      ];

      config = {
        allowUnfree = true;

        permittedInsecurePackages = [
          "olm-3.2.16"
          # github-runner bundles nodejs_20 for the Actions Node 20 runtime;
          # nodejs 20 is EOL but still required by GitHub Actions itself.
          "nodejs-20.20.2"
          "nodejs-slim-20.20.2"
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
