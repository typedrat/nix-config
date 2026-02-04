{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.comfy-cli;
in {
  meta.maintainers = [];

  options.programs.comfy-cli = {
    enable = lib.mkEnableOption "comfy-cli, a CLI for managing ComfyUI";

    package = lib.mkPackageOption pkgs "comfy-cli" {};

    enableBashIntegration = lib.hm.shell.mkBashIntegrationOption {inherit config;};

    enableZshIntegration = lib.hm.shell.mkZshIntegrationOption {inherit config;};

    enableFishIntegration = lib.hm.shell.mkFishIntegrationOption {inherit config;};
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    programs.bash.initExtra = lib.mkIf cfg.enableBashIntegration ''
      _comfy_completion() {
        local IFS=$'\n'
        COMPREPLY=( $( env COMP_WORDS="''${COMP_WORDS[*]}" \
                       COMP_CWORD=$COMP_CWORD \
                       _COMFY_COMPLETE=complete_bash \
                       comfy ) )
        return 0
      }
      complete -o default -F _comfy_completion comfy
    '';

    programs.zsh.initContent = lib.mkIf cfg.enableZshIntegration (lib.mkAfter ''
      _comfy_completion() {
        eval "$(env _TYPER_COMPLETE_ARGS="''${words[1,$CURRENT]}" _COMFY_COMPLETE=complete_zsh comfy)"
      }
      compdef _comfy_completion comfy
    '');

    programs.fish.interactiveShellInit = lib.mkIf cfg.enableFishIntegration ''
      complete -c comfy -f -a "(env _TYPER_COMPLETE_ARGS=(commandline -cp) _COMFY_COMPLETE=complete_fish comfy)"
    '';
  };
}
