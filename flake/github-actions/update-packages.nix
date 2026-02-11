{
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
              if nix run nixpkgs#nix-update -- --flake "$pkg" --use-update-script --write-commit-message ".commit-message-$pkg"; then
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
}
