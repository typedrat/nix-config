{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf impermanenceCfg.enable {
    home.persistence.${persistDir} = {
      directories = [
        # --- SSH ---
        {
          directory = ".ssh";
          mode = "0700";
        }

        # --- XDG user directories ---
        "Desktop"
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Public"
        "Templates"
        "Videos"

        # --- Nix / Home Manager state ---
        ".local/state/nix/profiles"
        ".local/state/home-manager"

        # --- Trash (XDG freedesktop spec) ---
        ".local/share/Trash"
      ];

      files = [
      ];
    };
  };
}
