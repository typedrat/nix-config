{inputs, ...}: let
  aagl = inputs.aagl;
in {
  imports = [aagl.nixosModules.default];
  nix.settings = aagl.nixConfig;

  programs.anime-game-launcher.enable = true;
  programs.honkers-railway-launcher.enable = true;
  programs.sleepy-launcher.enable = true;
}
