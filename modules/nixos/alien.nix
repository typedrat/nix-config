{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.nix-ld.enable =
    mkEnableOption "nix-ld"
    // {
      default = true;
    };

  config = mkIf config.rat.nix-ld.enable {
    # environment.systemPackages = [
    #   inputs'.nix-alien.packages.nix-alien
    # ];

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      alsa-lib
      at-spi2-atk
      atk
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      glib
      libGL
      libgbm
      libxcb
      libxkbcommon
      mesa
      nspr
      nss
      pango
      systemdMinimal
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
    ];
  };
}
