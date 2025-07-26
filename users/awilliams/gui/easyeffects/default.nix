{
  osConfig,
  lib,
  ...
}: let
  inherit (lib) mkIf;
in {
  imports = [
    ./meze-99-eq.nix
    ./neutral.nix
    ./voice-calls.nix
  ];

  config = mkIf osConfig.rat.audio.enable {
    services.easyeffects = {
      enable = true;
    };

    # workaround for nix-community/home-manager#6448
    systemd.user.services.easyeffects.Service.TimeoutStopSec = 1;
  };
}
