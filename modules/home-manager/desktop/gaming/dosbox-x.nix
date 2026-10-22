{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  gamingCfg = guiCfg.gaming or {};
  dosboxXCfg = gamingCfg.dosboxX or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Save states otherwise land in ./save under whatever directory DOSBox-X was
  # launched from, which for a desktop launch is $HOME. A custom --savedir is
  # never created on demand, so the wrapper makes it first; a --savedir given
  # on the command line still wins, since the last one parsed is used.
  dosbox-x = pkgs.symlinkJoin {
    inherit (pkgs.dosbox-x) name;
    paths = [pkgs.dosbox-x];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/dosbox-x \
        --run 'mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/dosbox-x"' \
        --add-flags '--savedir "''${XDG_STATE_HOME:-$HOME/.local/state}/dosbox-x"'
    '';
    inherit (pkgs.dosbox-x) meta;
  };
in {
  config = modules.mkIf (guiCfg.enable && dosboxXCfg.enable) {
    home.packages = [dosbox-x];

    # $XDG_DATA_HOME/dosbox-x is deliberately not persisted: when it exists,
    # DOSBox-X uses it as its whole resource directory instead of the package's,
    # so an empty one hides the bundled shaders, fonts and translations. User
    # overrides for those go in the config directory, which is searched first.
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        # dosbox-x-<version>.conf, mapper files, and user shaders/fonts/languages
        ".config/dosbox-x"
        ".local/state/dosbox-x"
      ];
    };
  };
}
