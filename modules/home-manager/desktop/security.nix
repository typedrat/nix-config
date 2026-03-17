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
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkMerge [
    # Bitwarden
    (modules.mkIf (guiCfg.enable && guiCfg.security.enable) {
      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [".local/share/Bitwarden"];
      };

      # home.packages = with pkgs; [
      #   bitwarden-desktop
      # ];
    })

    # GNOME Keyring
    (modules.mkIf guiCfg.enable {
      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [
          {
            directory = ".local/share/keyrings";
            mode = "0700";
          }
        ];
      };

      home.packages = [pkgs.seahorse];

      services.gnome-keyring = {
        enable = true;
        components = ["secrets"];
      };
    })
  ];
}
