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
  hyprlandCfg = guiCfg.hyprland or {};
  idleCfg = hyprlandCfg.idle or {};

  # `dpms on` alone can't be trusted to wake anything: a DPMS-on commit that
  # the DRM backend rejects still leaves the monitor recorded as on, and
  # setDPMS returns early when the requested state already matches, so every
  # later `dpms on` is a no-op against a dark panel. Cycling off first puts
  # that record back in sync; the pause gives a sleeping DP link time to train,
  # since an enable sent immediately after a disable gets rejected as well. The
  # off is free when the display really is off — it matches the recorded state
  # and returns without committing.
  wakeDisplays = "hyprctl dispatch dpms off; sleep 1; hyprctl dispatch dpms on";
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && hyprlandCfg.enable
      && (idleCfg.enable or true)
      && (idleCfg.variant or "hypridle") == "hypridle"
    ) {
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "pidof hyprlock || hyprlock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = wakeDisplays;
          };

          listener = [
            {
              timeout = 300;
              on-timeout = "loginctl lock-session";
            }
            {
              timeout = 600;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = wakeDisplays;
            }
          ];
        };
      };
    };
}
