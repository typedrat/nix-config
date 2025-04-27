{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.polkit = {
    enable = mkEnableOption "polkit" // {default = true;};
    unprivilegedPowerManagement = mkEnableOption "power management as user accounts";
  };

  config = mkIf config.rat.polkit.enable {
    security.polkit.enable = true;
    security.polkit.extraConfig = mkIf config.rat.polkit.unprivilegedPowerManagement ''
      polkit.addRule(function (action, subject) {
        if (
          subject.isInGroup("users") &&
          [
            "org.freedesktop.login1.reboot",
            "org.freedesktop.login1.reboot-multiple-sessions",
            "org.freedesktop.login1.power-off",
            "org.freedesktop.login1.power-off-multiple-sessions",
          ].indexOf(action.id) !== -1
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
