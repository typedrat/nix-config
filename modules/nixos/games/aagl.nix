{
  config,
  inputs,
  lib,
  options,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;

  # nixpkgs' cargo setup hook makes aws-lc-sys look for a system AWS-LC,
  # which the launchers don't provide, so let it build its bundled copy.
  bundledSysLibs = launcher: let
    package = options.programs.${launcher}.package.default;
  in
    package.override {
      unwrapped = package.unwrapped.overrideAttrs {dontCargoUseSystemLibs = true;};
    };
in {
  imports = [
    inputs.anime-game-launcher.nixosModules.default
  ];

  options.rat.gaming.animeGameLaunchers.enable = mkEnableOption "anime game launchers";

  config = mkMerge [
    {
      nix.settings = inputs.anime-game-launcher.nixConfig;

      aagl.enableNixpkgsReleaseBranchCheck = false;
    }
    (mkIf (config.rat.gaming.enable && config.rat.gaming.animeGameLaunchers.enable) {
      programs.anime-game-launcher = {
        enable = true;
        package = bundledSysLibs "anime-game-launcher";
      };
      programs.honkers-railway-launcher = {
        enable = true;
        package = bundledSysLibs "honkers-railway-launcher";
      };
      programs.sleepy-launcher = {
        enable = true;
        package = bundledSysLibs "sleepy-launcher";
      };
    })
  ];
}
