{
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
}
