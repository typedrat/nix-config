{inputs, ...}: {
  imports = [
    inputs.files.flakeModules.default
    inputs.github-actions-nix.flakeModules.default
  ];

  perSystem = {
    config,
    lib,
    ...
  }: {
    githubActions = {
      enable = true;

      workflows = {
        build = {
          name = "Build NixOS Systems";

          on = {
            push.branches = ["master"];
            pullRequest.branches = ["master"];
            workflowDispatch = {};
          };

          concurrency = {
            group = "\${{ github.workflow }}-\${{ github.ref }}";
            cancelInProgress = true;
          };

          jobs = {
            build = {
              name = "Build \${{ matrix.host }}";
              runsOn = "nixos";

              permissions = {
                id-token = "write";
                contents = "read";
              };

              strategy = {
                failFast = false;
                matrix = {
                  host = ["iserlohn" "ulysses"];
                };
              };

              steps = [
                {uses = "actions/checkout@v4";}
                {uses = "DeterminateSystems/determinate-nix-action@v3";}
                {uses = "DeterminateSystems/flakehub-cache-action@main";}
                {uses = "DeterminateSystems/flake-checker-action@main";}
                {
                  name = "Build \${{ matrix.host }}";
                  run = "nix build .#nixosConfigurations.\${{ matrix.host }}.config.system.build.toplevel";
                }
              ];
            };

            build-summary = {
              name = "Build Summary";
              runsOn = "ubuntu-latest";
              needs = "build";
              if_ = "always()";

              steps = [
                {
                  name = "Check build results";
                  run = ''
                    if [[ "''${{ needs.build.result }}" == "success" ]]; then
                      echo "All systems built successfully!"
                    else
                      echo "Some systems failed to build"
                      exit 1
                    fi
                  '';
                }
              ];
            };
          };
        };

        update-flake-lock = {
          name = "Update flake.lock";

          on = {
            workflowDispatch = {};
            schedule = [
              {cron = "0 6 * * *";}
            ];
          };

          jobs = {
            lockfile = {
              runsOn = "ubuntu-latest";

              permissions = {
                id-token = "write";
                contents = "read";
                pull-requests = "write";
              };

              steps = [
                {uses = "actions/checkout@v4";}
                {uses = "DeterminateSystems/determinate-nix-action@v3";}
                {uses = "DeterminateSystems/flakehub-cache-action@main";}
                {
                  uses = "DeterminateSystems/update-flake-lock@main";
                  with_ = {
                    token = "\${{ secrets.GH_TOKEN_FOR_UPDATES }}";
                    pr-labels = "automerge";
                  };
                }
              ];
            };
          };
        };
      };
    };

    # Sync generated workflows to .github/workflows/
    files.files =
      lib.mapAttrsToList (name: drv: {
        path_ = ".github/workflows/${name}";
        inherit drv;
      })
      config.githubActions.workflowFiles;

    # Expose the files writer as an app
    apps.write-files = {
      type = "app";
      program = lib.getExe config.files.writer.drv;
      meta.description = "Write generated files to the repository";
    };
  };
}
