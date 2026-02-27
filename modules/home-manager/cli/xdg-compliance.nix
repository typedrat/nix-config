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
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (cliCfg.enable or false) (modules.mkMerge [
    {
      home.sessionVariables = {
        # Development tools
        BUN_INSTALL = "${config.xdg.dataHome}/bun";
        CARGO_HOME = "${config.xdg.dataHome}/cargo";
        CLAUDE_CONFIG_DIR = "${config.xdg.configHome}/claude";
        DOCKER_CONFIG = "${config.xdg.configHome}/docker";
        NPM_CONFIG_USERCONFIG = "${config.xdg.configHome}/npm/npmrc";
        npm_config_cache = "${config.xdg.cacheHome}/npm";
        RUSTUP_HOME = "${config.xdg.dataHome}/rustup";

        # Cloud/Infra
        TF_CLI_CONFIG_FILE = "${config.xdg.configHome}/terraform/terraformrc";
        TF_PLUGIN_CACHE_DIR = "${config.xdg.cacheHome}/terraform/plugins";
        CHECKPOINT_DISABLE = "1";

        # Shell/REPL history
        IPYTHONDIR = "${config.xdg.configHome}/ipython";
        PYTHON_HISTORY = "${config.xdg.stateHome}/python/history";
        LESSHISTFILE = "${config.xdg.stateHome}/less/history";

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

    # GPU/shader cache persistence
    {
      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [".cache/mesa_shader_cache"];
      };
    }

    (modules.mkIf (osConfig.rat.hardware.nvidia.enable or false) {
      home.sessionVariables.__GL_SHADER_DISK_CACHE_PATH = "${config.xdg.cacheHome}/nvidia";

      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [".cache/nvidia" ".nv"];
      };
    })
  ]);
}
