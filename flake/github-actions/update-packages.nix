{
  name = "Update packages";

  # No push trigger: this workflow's own PR is automerged, so a push trigger
  # would make every merge start the next update round immediately.
  on = {
    workflowDispatch = {};
    # Run 1 hour after flake.lock update (0 20 * * *) to use fresh nixpkgs
    schedule = [
      {cron = "0 21 * * *";}
    ];
  };

  concurrency = {
    group = "nix-updates";
    cancelInProgress = false;
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

            # `nix-update --use-update-script` runs the script inside
            # `mkShell { inputsFrom = [pkg]; }`, which builds every build input
            # first. When the script is nix-update-script that shell is pure
            # overhead, and for packages with uncached heavy inputs (build123d
            # pulls in cadquery-ocp-novtk) it outlives the runner. Record those
            # scripts' arguments so nix-update can be called directly instead.
            nix eval .#packages.x86_64-linux --json --apply '
              pkgs: let
                scriptOf = n: let s = pkgs.''${n}.passthru.updateScript or null; in if s == null then null else s.command or s;
                isNixUpdate = c: builtins.isList c && baseNameOf (toString (builtins.head c)) == "nix-update";
              in
                builtins.listToAttrs (map (n: {
                  name = n;
                  value = builtins.tail (map toString (scriptOf n));
                }) (builtins.filter (n: isNixUpdate (scriptOf n)) (builtins.attrNames pkgs)))
            ' > "$RUNNER_TEMP/nix-update-args.json"

            updated_packages=""
            failed_packages=""

            # Packages with custom update scripts that must be run directly
            # (nix-update can't handle packages built via external flake inputs
            # or with extra pinned sources beyond src)
            custom_update_packages="bypass-paywalls-clean ttv-lol-pro tweakcc-fixed"

            for pkg in $packages; do
              echo "Updating $pkg..."

              is_custom=false
              for custom_pkg in $custom_update_packages; do
                if [ "$pkg" = "$custom_pkg" ]; then
                  is_custom=true
                  break
                fi
              done

              # Attribute paths can contain slashes (peon-ping-packs/bender);
              # those would be read as directories that don't exist.
              commit_msg=".commit-message-''${pkg//\//-}"

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
                if jq -e --arg p "$pkg" 'has($p)' "$RUNNER_TEMP/nix-update-args.json" >/dev/null; then
                  mapfile -t update_args < <(jq -r --arg p "$pkg" '.[$p][]' "$RUNNER_TEMP/nix-update-args.json")
                else
                  update_args=(--use-update-script)
                fi
                if ! nix run nixpkgs#nix-update -- --flake "$pkg" "''${update_args[@]}" --write-commit-message "$commit_msg"; then
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
