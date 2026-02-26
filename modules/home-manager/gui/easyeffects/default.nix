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
  guiCfg = userCfg.gui or {};
  easyeffectsCfg = guiCfg.easyeffects or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    ./jlab-go-pop.nix
    ./meze-99-eq.nix
    ./neutral.nix
    ./voice-calls.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (easyeffectsCfg.enable or false)) {
    services.easyeffects.enable = true;
    systemd.user.services.easyeffects.Unit.ConditionEnvironment = "WAYLAND_DISPLAY";
    home.packages = with pkgs; [lsp-plugins];

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.enable {
      directories = [".config/easyeffects" ".local/share/easyeffects"];
    };
  };
}
