{
  config,
  osConfig,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.development.enable or false)) {
    home.packages = with pkgs; [
      # Rust toolchain with multiple targets
      (inputs'.fenix.packages.combine [
        inputs'.fenix.packages.stable.defaultToolchain
        inputs'.fenix.packages.targets.x86_64-unknown-linux-gnu.stable.rust-std
        inputs'.fenix.packages.targets.x86_64-unknown-linux-musl.stable.rust-std
        inputs'.fenix.packages.targets.aarch64-unknown-linux-gnu.stable.rust-std
        inputs'.fenix.packages.targets.aarch64-unknown-linux-musl.stable.rust-std
        inputs'.fenix.packages.targets.wasm32-unknown-unknown.stable.rust-std
      ])

      # Python with common data science packages
      (python3.withPackages (ps:
        with ps; [
          ipython
          matplotlib
          numpy
          pandas
          polars
          pynput
          scipy
          seaborn
          sympy
        ]))

      # JavaScript/Node.js
      nodejs
      corepack

      # Java
      jdk
      maven

      # Lean theorem prover
      elan
    ];
  };
}
