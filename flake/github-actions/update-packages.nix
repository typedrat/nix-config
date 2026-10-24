let
  reviewedPackages = "shoko shoko-webui";

  mkUpdateJob = {
    env,
    branch,
    title,
    labels ? null,
  }: {
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
        inherit env;
        run = "scripts/update-packages.sh";
      }
      {
        name = "Create Pull Request";
        if_ = "always()";
        uses = "peter-evans/create-pull-request@v7";
        with_ =
          {
            token = "\${{ secrets.GH_TOKEN_FOR_UPDATES }}";
            inherit branch title;
            delete-branch = true;
            body = "## Updated packages\n\n\${{ env.UPDATED_PACKAGES }}";
          }
          // (
            if labels == null
            then {}
            else {inherit labels;}
          );
      }
    ];
  };
in {
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
    update = mkUpdateJob {
      env.UPDATE_EXCLUDE = reviewedPackages;
      branch = "update-packages";
      title = "Update packages";
      labels = "automerge";
    };

    # Shoko tracks daily dev builds, and each one can run database migrations
    # that a rollback won't undo, so its bumps wait for review instead of
    # being automerged and auto-deployed.
    update-shoko = mkUpdateJob {
      env.UPDATE_ONLY = reviewedPackages;
      branch = "update-shoko";
      title = "Update Shoko";
    };
  };
}
