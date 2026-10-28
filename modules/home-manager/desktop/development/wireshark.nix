{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  developmentCfg = guiCfg.development or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  # The package and capture rights come from the system, since dumpcap needs a
  # capability wrapper.
  config = mkIf (guiCfg.enable && developmentCfg.enable && (developmentCfg.wireshark.enable or false)) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      # Preferences, profiles, recent files and capture filters
      directories = [".config/wireshark"];
    };
  };
}
