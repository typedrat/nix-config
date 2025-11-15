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
in {
  config = modules.mkIf ((cliCfg.enable or false) && (cliCfg.development.enable or false)) {
    home.packages = with pkgs; [
      git-spice
    ];

    programs.zsh.plugins = [
      {
        name = "git-spice-completions";

        src =
          pkgs.runCommandWith {
            name = "git-spice-zsh-completion";
            derivationArgs = {
              nativeBuildInputs = [pkgs.gitMinimal];
            };
          } ''
            mkdir -p $out
            ${lib.getExe pkgs.git-spice} shell completion zsh > $out/_gs
          '';
      }
    ];
  };
}
