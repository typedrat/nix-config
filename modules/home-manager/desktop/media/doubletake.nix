{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (config.home) username;
  guiCfg = osConfig.rat.users.${username}.gui or {};
  cfg = guiCfg.media.doubletake or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Without -port-range the sender binds ephemeral UDP ports, which the
  # firewall would drop. Flags given on the command line still win: Go's flag
  # parser keeps the last value.
  doubletake = pkgs.symlinkJoin {
    name = "doubletake-${pkgs.doubletake.version}";
    paths = [pkgs.doubletake];
    nativeBuildInputs = [pkgs.makeBinaryWrapper];
    postBuild = ''
      wrapProgram $out/bin/doubletake \
        --add-flags "-port-range ${toString cfg.portRange.from}-${toString cfg.portRange.to}"
    '';
    inherit (pkgs.doubletake) meta;
  };
in {
  config = mkIf ((guiCfg.enable or false) && (guiCfg.media.enable or false) && (cfg.enable or false)) {
    # Pairing credentials and portal restore tokens.
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/doubletake"];
    };

    home.packages = [doubletake];
  };
}
