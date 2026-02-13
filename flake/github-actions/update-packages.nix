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
            packages=$(nix eval .#packages.x86_64-linux --apply 'pkgs: builtins.filter (n: (pkgs.''${n}.passthru.updateScript or null) != null) (builtins.attrNames pkgs)' --json | jq -r '.[]')
            updated_packages=""
            failed_packages=""

            # Packages with custom update scripts that must be run directly
            # (nix-update can't handle packages built via external flake inputs)
            custom_update_packages="bypass-paywalls-clean ttv-lol-pro"

            for pkg in $packages; do
              echo "Updating $pkg..."

              is_custom=false
              for custom_pkg in $custom_update_packages; do
                if [ "$pkg" = "$custom_pkg" ]; then
                  is_custom=true
                  break
                fi
              done

              commit_msg=".commit-message-$pkg"

              if [ "$is_custom" = true ]; then
                # Run the package's update.sh script directly
                pkg_dir=$(find packages -maxdepth 2 -name "update.sh" -path "*/$pkg/*" -exec dirname {} \;)
                if [ -n "$pkg_dir" ] && [ -x "$pkg_dir/update.sh" ]; then
                  echo "Running custom update script for $pkg..."
                  if ! COMMIT_MESSAGE_FILE="$commit_msg" "$pkg_dir/update.sh"; then
                    echo "::error::Failed to update $pkg"
                    failed_packages="$failed_packages- $pkg\n"
                    rm -f "$commit_msg"
                    git checkout -- .
                    git clean -fd
                    continue
                  fi
                else
                  echo "::error::No update.sh found for $pkg"
                  failed_packages="$failed_packages- $pkg\n"
                  continue
                fi
              else
                if ! nix run nixpkgs#nix-update -- --flake "$pkg" --use-update-script --write-commit-message "$commit_msg"; then
                  echo "::error::Failed to update $pkg"
                  failed_packages="$failed_packages- $pkg\n"
                  rm -f "$commit_msg"
                  git checkout -- .
                  git clean -fd
                  continue
                fi
              fi

              # Commit if there are changes
              if [ -f "$commit_msg" ]; then
                nix fmt
                commit_msg_content=$(cat "$commit_msg")
                rm "$commit_msg"
                git add -A
                git commit \
                  --author="github-actions[bot] <github-actions[bot]@users.noreply.github.com>" \
                  -m "$commit_msg_content"
                updated_packages="$updated_packages- $pkg\n"
              fi
            done

            if [ -n "$updated_packages" ]; then
              echo "UPDATED_PACKAGES<<EOF" >> "$GITHUB_ENV"
              echo -e "$updated_packages" >> "$GITHUB_ENV"
              echo "EOF" >> "$GITHUB_ENV"
            else
              echo "UPDATED_PACKAGES=_No packages were updated._" >> "$GITHUB_ENV"
            fi

            if [ -n "$failed_packages" ]; then
              echo ""
              echo "The following packages failed to update:"
              echo -e "$failed_packages"
              exit 1
            fi
          '';
        }
        {
          name = "Create Pull Request";
          if_ = "always()";
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
