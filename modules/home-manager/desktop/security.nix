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
    # Seahorse itself is installed system-wide via programs.seahorse.enable
    # in modules/nixos/gui/gnome-keyring.nix.
    (modules.mkIf guiCfg.enable {
      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [
          {
            directory = ".local/share/keyrings";
            mode = "0700";
          }
        ];
      };

      services.gnome-keyring = {
        enable = true;
        components = ["secrets"];
      };
    })
  ];
}
