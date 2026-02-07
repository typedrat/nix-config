{
  perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: {
    checks = let
      # Get only our local packages (excluding terraform outputs)
      localPkgs =
        lib.filterAttrs
        (name: v: lib.isDerivation v && !(lib.hasPrefix "terraform" name))
        config.packages;
      packagesWithoutUpdateScript =
        lib.filterAttrs
        (_: pkg: !(pkg.passthru.updateScript or null != null))
        localPkgs;
    in {
      packages-have-updateScript = pkgs.runCommand "check-updateScript" {} ''
        ${lib.optionalString (packagesWithoutUpdateScript != {}) ''
          echo "The following packages are missing passthru.updateScript:"
          ${lib.concatMapStringsSep "\n" (name: "echo '  - ${name}'") (lib.attrNames packagesWithoutUpdateScript)}
          exit 1
        ''}
        echo "All packages have updateScript set."
        touch $out
      '';
    };
  };
}
