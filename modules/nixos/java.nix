{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.java.enable =
    mkEnableOption "java"
    // {
      default = true;
    };

  config = mkIf config.rat.java.enable {
    programs.java = {
      enable = true;
      package = pkgs.graalvmPackages.graalvm-ce;
    };
  };
}
