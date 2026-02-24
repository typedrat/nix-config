{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf (cliCfg.enable or false) (modules.mkMerge [
    {
      home.sessionVariables = {
        # Development tools
        CARGO_HOME = "${config.xdg.dataHome}/cargo";
        RUSTUP_HOME = "${config.xdg.dataHome}/rustup";
        BUN_INSTALL = "${config.xdg.dataHome}/bun";
        NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
        npm_config_cache = "${config.xdg.cacheHome}/npm";
        DOCKER_CONFIG = "${config.xdg.configHome}/docker";

        # Cloud/Infra
        TF_CLI_CONFIG_FILE = "${config.xdg.configHome}/terraform/terraformrc";
        TF_PLUGIN_CACHE_DIR = "${config.xdg.cacheHome}/terraform/plugins";
        CHECKPOINT_DISABLE = "1";

        # Shell/REPL history
        PYTHON_HISTORY = "${config.xdg.stateHome}/python/history";
        LESSHISTFILE = "${config.xdg.stateHome}/less/history";
        IPYTHONDIR = "${config.xdg.configHome}/ipython";

        # Other
        WINEPREFIX = "${config.xdg.dataHome}/wine";
      };

      home.sessionPath = [
        "${config.home.sessionVariables.CARGO_HOME}/bin"
        "${config.home.sessionVariables.BUN_INSTALL}/bin"
      ];

      programs.zsh = {
        completionInit = ''
          autoload -U compinit && compinit -d "${config.xdg.cacheHome}/zsh/zcompdump-$ZSH_VERSION"
        '';
        history.path = "${config.xdg.stateHome}/zsh/history";
      };

      programs.bash.historyFile = "/dev/null";
    }

    (modules.mkIf (osConfig.rat.hardware.nvidia.enable or false) {
      home.sessionVariables.__GL_SHADER_DISK_CACHE_PATH = "${config.xdg.cacheHome}/nvidia";
    })
  ]);
}
