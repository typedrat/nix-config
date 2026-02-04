{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  imports = [
    ./development
    ./shell
    ./comfy-cli.nix
    ./networking.nix
    ./system-tools.nix
    ./tools.nix
    ./utilities.nix
  ];

  config = modules.mkIf (cliCfg.enable or false) {
    # Base CLI configuration
  };
}
