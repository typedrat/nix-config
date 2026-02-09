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
                contents = "write";
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
                  id = "build";
                  name = "Build \${{ matrix.host }}";
                  run = "nix build .#nixosConfigurations.\${{ matrix.host }}.config.system.build.toplevel";
                }
                {
                  name = "Fix hash mismatches";
                  if_ = "failure() && steps.build.outcome == 'failure' && github.event_name == 'pull_request'";
                  run = ''
                    git stash --include-untracked
                    git fetch --depth=1 origin "$GITHUB_HEAD_REF"
                    git checkout -B "$GITHUB_HEAD_REF" "''${{ github.event.pull_request.head.sha }}"

                    determinate-nixd fix hashes --auto-apply

                    if ! git diff --quiet; then
                      git config user.name "github-actions[bot]"
                      git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
                      git add --update --ignore-removal .
                      git commit -m "Automatically fix Nix hashes"
                      git push origin "$GITHUB_HEAD_REF"
                    fi

                    git checkout -
                    git stash pop || true
                  '';
                }
                {
                  name = "Publish to FlakeHub";
                  if_ = "success() && github.ref == 'refs/heads/master' && matrix.host == 'iserlohn'";
                  uses = "DeterminateSystems/flakehub-push@main";
                  with_ = {
                    visibility = "private";
                    rolling = true;
                    include-output-paths = true;
                  };
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

        update-packages = {
          name = "Update packages";

          on = {
            workflowDispatch = {};
            # Run 1 hour after flake.lock update (0 6 * * *) to use fresh nixpkgs
            schedule = [
              {cron = "0 7 * * *";}
            ];
          };

          jobs = {
            update = {
              runsOn = "ubuntu-latest";

              permissions = {
                id-token = "write";
                contents = "write";
                pull-requests = "write";
              };

              steps = [
                {uses = "actions/checkout@v4";}
                {uses = "DeterminateSystems/determinate-nix-action@v3";}
                {uses = "DeterminateSystems/flakehub-cache-action@main";}
                {
                  name = "Configure git";
                  run = ''
                    git config user.name "github-actions[bot]"
                    git config user.email "github-actions[bot]@users.noreply.github.com"
                  '';
                }
                {
                  name = "Update packages";
                  run = ''
                    packages=$(nix eval .#packages.x86_64-linux --apply 'pkgs: builtins.filter (n: n != "terraform") (builtins.attrNames pkgs)' --json | jq -r '.[]')
                    updated_packages=""

                    for pkg in $packages; do
                      echo "Updating $pkg..."
                      if nix run nixpkgs#nix-update -- --flake "$pkg" --write-commit-message ".commit-message-$pkg"; then
                        if [ -f ".commit-message-$pkg" ]; then
                          nix fmt
                          git add -A
                          git commit \
                            --author="github-actions[bot] <github-actions[bot]@users.noreply.github.com>" \
                            --file=".commit-message-$pkg"
                          rm ".commit-message-$pkg"
                          updated_packages="$updated_packages- $pkg\n"
                        fi
                      else
                        echo "Failed to update $pkg, continuing..."
                      fi
                    done

                    if [ -n "$updated_packages" ]; then
                      echo "UPDATED_PACKAGES<<EOF" >> "$GITHUB_ENV"
                      echo -e "$updated_packages" >> "$GITHUB_ENV"
                      echo "EOF" >> "$GITHUB_ENV"
                    else
                      echo "UPDATED_PACKAGES=_No packages were updated._" >> "$GITHUB_ENV"
                    fi
                  '';
                }
                {
                  name = "Create Pull Request";
                  uses = "peter-evans/create-pull-request@v7";
                  with_ = {
                    token = "\${{ secrets.GH_TOKEN_FOR_UPDATES }}";
                    branch = "update-packages";
                    delete-branch = true;
                    title = "Update packages";
                    body = "## Updated packages\n\n\${{ env.UPDATED_PACKAGES }}";
                    labels = "automerge";
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
