{
  name = "Update flake.lock";

  # No push trigger: this workflow's own PR is automerged, so a push trigger
  # would make every merge start the next update round immediately.
  on = {
    workflowDispatch = {};
    schedule = [
      {cron = "0 20 * * *";}
    ];
  };

  concurrency = {
    group = "nix-updates";
    cancelInProgress = false;
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
        {
          uses = "DeterminateSystems/determinate-nix-action@v3";
          # The default github.token is repo-scoped and 404s on private flake
          # inputs (typedrat/wallpapers); the PAT lands in nix.conf access-tokens.
          with_ = {
            github-token = "\${{ secrets.GH_TOKEN_FOR_UPDATES }}";
          };
        }
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
}
