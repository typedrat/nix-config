{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir cacheRoot;
in {
  config = mkIf impermanenceCfg.home.enable {
    home.persistence = mkMerge [
      {
        ${persistDir} = {
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

            # --- Trash (XDG freedesktop spec) ---
            ".local/share/Trash"
          ];

          files = [
          ];
        };
      }
      {
        ${cacheRoot} = {
          hideMounts = true;
          directories = [
            # --- Nix caches ---
            ".cache/nix"
          ];
        };
      }
    ];
  };
}
