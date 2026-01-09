{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
in {
  imports = [
    ./gnome-keyring.nix
    ./greetd.nix
    ./hyprland.nix
    ./plymouth.nix
  ];

  options.rat.gui = {
    enable = mkEnableOption "gui";

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
