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
      expat
      fontconfig
      freetype
      glib
      libGL
      libxcb
    ];
  };
}
