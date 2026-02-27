{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf impermanenceCfg.home.enable {
    home.persistence.${persistDir} = {
      hideMounts = true;

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

        # --- Nix caches ---
        ".cache/nix"

        # --- Trash (XDG freedesktop spec) ---
        ".local/share/Trash"
      ];

      files = [
      ];
    };
  };
}
