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
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.tools.enable or false)) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/direnv"
        ".local/share/zoxide"
        ".local/state/yazi"
        ".local/share/mergiraf"
      ];
    };
    programs.aria2.enable = true;

    programs.bat.enable = true;
    programs.zsh.shellAliases.cat = "bat";

    programs.bottom.enable = true;

    programs.btop = {
      enable = true;
      package = pkgs.btop-cuda;
    };

    programs.difftastic = {
      enable = true;
      git.enable = true;
    };

    programs.direnv = {
      enable = true;
      silent = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    programs.eza = {
      enable = true;
      enableZshIntegration = true;
      colors = "auto";
      icons = "auto";
    };

    programs.fd = {
      enable = true;
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      fileWidgetCommand = "${lib.getExe config.programs.fd.package} --type f";

      defaultOptions = [
        ''--preview \"${lib.getExe config.programs.bat.package} --color=always --style=numbers --line-range=:500 {}\"''
      ];
    };

    programs.jq.enable = true;

    programs.lazygit.enable = true;

    programs.mergiraf.enable = true;

    programs.nix-index = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.parallel = {
      enable = true;
      will-cite = true;
    };

    programs.ripgrep.enable = true;

    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
