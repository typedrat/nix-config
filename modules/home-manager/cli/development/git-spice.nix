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
  cliCfg = userCfg.cli or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/git-spice"];
    };

    home.packages = with pkgs; [
      git-spice
    ];

    programs.git.settings = {
      spice.branchCreate.commit = false;
    };

    home.sessionVariables = {
      GIT_SPICE_NO_GS_WARNING = 1;
    };

    # git-spice's `gs shell completion zsh` emits bash-compat completion
    # (bashcompinit + `complete -C`), not a real zsh `_gs` function. Dropping
    # it into fpath as `_gs` therefore doesn't work: autoload expects the file
    # to define a `_gs` function, which it doesn't. Eval it from initContent
    # instead so bashcompinit gets wired up at shell start.
    programs.zsh.initContent = ''
      if (( $+commands[gs] )); then
        eval "$(${lib.getExe pkgs.git-spice} shell completion zsh)"
      fi
    '';
  };
}
