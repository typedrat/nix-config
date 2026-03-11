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
      ];
    };

    home.packages = with pkgs; [
      catbox-cli
      cowsay
      (fastfetch.overrideAttrs (oldAttrs: {
        buildInputs =
          (oldAttrs.buildInputs or [])
          ++ [
            zfs
          ];
      }))
      file
      gawk
      gdu
      gnused
      gnutar
      hyfetch
      jd-diff-patch
      openssl
      pv
      rename
      tree
      vim.xxd
      which
    ];

    programs.aria2.enable = true;

    programs.bat.enable = true;
    programs.zsh.shellAliases.cat = "bat";

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
