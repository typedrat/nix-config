{
  inputs,
  pkgs,
  lib,
  ...
}: {
  catppuccin.hyprlock.useDefaultConfig = false;

  programs.hyprlock = {
    enable = true;
    package = inputs.hyprlock.packages."${pkgs.stdenv.system}".hyprlock;

    extraConfig = lib.readFile ./hyprlock.conf;
  };
}
