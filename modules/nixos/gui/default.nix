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
    ./gnome-keyring.nix
    ./greeter
    ./hyprland.nix
    ./plymouth.nix
  ];

  options.rat.gui = {
    enable = mkEnableOption "gui";

    greeter.variant = mkOption {
      default = "tuigreet";
      type = types.enum ["tuigreet" "sddm"];
      description = "The display manager / greeter to use";
    };

    chat.enable = mkEnableOption "chat clients" // {default = true;};
    media.enable = mkEnableOption "media software" // {default = true;};
    productivity.enable = mkEnableOption "productivity software" // {default = true;};
    devtools.enable = mkEnableOption "graphical development tools" // {default = true;};
  };

  config = mkIf config.rat.gui.enable {
    boot = {
      extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
      kernelModules = ["v4l2loopback"];
    };
  };
}
