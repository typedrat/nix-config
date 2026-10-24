{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption mkOption;
in {
  imports = [
    ./chromium.nix
    ./gnome-keyring.nix
    ./greeter
    ./hyprland.nix
    ./kde.nix
    ./plymouth.nix
  ];

  options.rat.gui = {
    enable = mkEnableOption "gui";

    defaultSession = mkOption {
      default = "hyprland-uwsm";
      type = types.enum ["hyprland-uwsm" "plasma"];
      description = "The default desktop session for the display manager";
    };

    greeter.variant = mkOption {
      default = "tuigreet";
      type = types.enum ["tuigreet" "sddm"];
      description = "The display manager / greeter to use";
    };

    chat.enable = mkEnableOption "chat clients" // {default = true;};
    media.enable = mkEnableOption "media software" // {default = true;};
    productivity.enable = mkEnableOption "productivity software" // {default = true;};
    development.enable = mkEnableOption "graphical development tools" // {default = true;};
  };

  config = mkIf config.rat.gui.enable {
    services.displayManager.defaultSession = config.rat.gui.defaultSession;

    programs.ydotool.enable = true;

    boot = {
      # The kernel's modules_install runs depmod itself, so the output carries
      # its own modules.dep, modules.softdep, ... that collide with the
      # kernel's when the module tree is merged.
      extraModulePackages = [
        (config.boot.kernelPackages.v4l2loopback.overrideAttrs (old: {
          postInstall =
            (old.postInstall or "")
            + ''
              rm -f "$out"/lib/modules/*/modules.*
            '';
        }))
      ];
      kernelModules = ["v4l2loopback"];
    };
  };
}
