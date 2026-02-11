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
        build = import ./build.nix;
        update-flake-lock = import ./update-flake-lock.nix;
        update-packages = import ./update-packages.nix;
        track-issues = import ./track-issues.nix;
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
