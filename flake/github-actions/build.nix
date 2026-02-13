{
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
        {
          uses = "wimpysworld/nothing-but-nix@main";
          if_ = "runner.os == 'Linux' && runner.environment == 'github-hosted'";
        }
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
          if_ = "success() && github.ref == 'refs/heads/master'";
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
}
