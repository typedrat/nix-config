{terranix}: {self, ...}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
    terraformConfiguration = terranix.lib.terranixConfiguration {
      inherit system;

      modules = [
        self.terraformConfiguration
      ];
    };
  in {
    packages = {
      inherit terraformConfiguration;
    };

    apps = {
      terraformApply = {
        type = "app";
        program = toString (pkgs.writers.writeBash "apply" ''
          if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
          cp ${terraformConfiguration} config.tf.json \
            && ${lib.getExe pkgs.opentofu} init \
            && ${lib.getExe pkgs.opentofu} apply
        '');
      };
      # nix run ".#destroy"
      terraformDestroy = {
        type = "app";
        program = toString (pkgs.writers.writeBash "destroy" ''
          if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
          cp ${terraformConfiguration} config.tf.json \
            && ${lib.getExe pkgs.opentofu} init \
            && ${lib.getExe pkgs.opentofu} destroy
        '');
      };
    };
  };
}
