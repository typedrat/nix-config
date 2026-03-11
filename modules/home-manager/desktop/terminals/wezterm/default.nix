{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  terminalsCfg = guiCfg.terminals or {};
in {
  config = modules.mkIf ((guiCfg.enable or false) && (terminalsCfg.wezterm.enable or false)) {
    programs.wezterm = {
      enable = true;
      enableZshIntegration = true;
      extraConfig = builtins.readFile ./wezterm.lua;
    };
  };
}
