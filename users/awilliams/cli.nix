{
  config,
  lib,
  ...
}: {
  programs.bat.enable = true;
  programs.zsh.shellAliases.cat = "bat";

  programs.bottom.enable = true;

  programs.direnv = {
    enable = true;
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

  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
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
}
