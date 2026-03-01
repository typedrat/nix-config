{
  name = "Track upstream issues";

  on = {
    push.branches = ["master"];
    workflowDispatch = {};
    schedule = [
      {cron = "0 */3 * * *";}
    ];
  };

  jobs = {
    track = {
      runsOn = "ubuntu-latest";

      permissions = {
        issues = "write";
        contents = "read";
      };

      steps = [
        {uses = "actions/checkout@v4";}
        {
          name = "Scan and update dashboard";
          uses = "actions/github-script@v7";
          with_.script = builtins.readFile ./track-issues.js;
        }
      ];
    };
  };
}
