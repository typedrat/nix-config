{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    home.packages = with pkgs; [
      # Sampling profilers
      perf
      samply

      # Flame graphs from `perf script` output
      inferno
      cargo-flamegraph

      # Debuggers and memory checkers
      gdb
      valgrind
    ];
  };
}
