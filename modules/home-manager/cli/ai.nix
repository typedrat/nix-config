{
  config,
  osConfig,
  inputs,
  inputs',
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

  # Check if user has specific secrets configured (awilliams-specific)
  hasUserSecrets = username == "awilliams";
  hasNvidia = osConfig.rat.hardware.nvidia.enable;
  gpuVram = osConfig.rat.hardware.gpu.vram;
  hasLargeVram = gpuVram >= 16;
  guiCfg = userCfg.gui or {};
  hasChromium = (guiCfg.enable or false) && (guiCfg.browsers.chromium.enable or false);
  peonPingCfg = cliCfg.ai.peon-ping or {};
  peonSettings = peonPingCfg.settings or {};
in {
  imports = [
    inputs.peon-ping.homeManagerModules.default
  ];

  config = modules.mkIf (cliCfg.enable && cliCfg.ai.enable) {
    xdg.userDirs.extraConfig.XDG_AI_DIR = "$HOME/AI";

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        "AI"
        ".config/opencode"
        ".local/share/opencode"
        ".local/state/opencode"
        ".gstack"
        ".openpeon"

        # yes, this is where the authentication data for OpenCode lives
        # I want to shove a copy of the XDG specification up someone's asshole.
        ".cache/opencode"
      ];
    };

    sops.secrets = lib.mkIf hasUserSecrets {
      civitaiApiToken = {};
      hfToken = {};
      morphApiKey = {};
      openrouterApiKey = {};
      answerOverflowKey = {};
      homeAssistantToken = {};
    };

    home.packages =
      (with pkgs; [
        llm
        python3Packages.huggingface-hub
      ])
      ++ lib.optional (hasNvidia && hasLargeVram) inputs'.llama-cpp.packages.cuda;

    home.sessionVariables =
      {
        HF_XET_HIGH_PERFORMANCE = "1";
        MORPH_COMPACT_TOKEN_LIMIT = toString cliCfg.ai.morphCompactTokenLimit;
      }
      // lib.optionalAttrs hasChromium {
        GSTACK_CHROMIUM_PATH = lib.getExe config.programs.google-chrome.package;
      };

    programs.comfy-cli = {
      enable = true;
      package = pkgs.comfy-cli;
    };

    programs.opencode = {
      enable = true;

      tui = {
        theme = "catppuccin-frappe";
        plugin = [
          [
            "oc-plugin-rainbow"
            {
              enabled = true;
              fg = true;
              bg = true;
              speed = 0.008;
              turns = 3;
              glow = 0.05;
              keybinds = {
                logo_splash = "ctrl+shift+r";
              };
            }
          ]
        ];
      };

      settings = {
        plugin = [
          "@ex-machina/opencode-anthropic-auth@1.7.5"
          "opencode-pty"
          "opencode-websearch"
          "superpowers@git+https://github.com/obra/superpowers.git"
        ];

        permission = {
          external_directory = {
            "/tmp/**" = "allow";
            "~/.claude/skills/**" = "allow";
            "~/Development/gstack/**" = "allow";
          };
        };

        mcp = {
          answeroverflow = {
            type = "remote";
            url = "https://www.answeroverflow.com/mcp";
            headers = {
              X-API-Key = "{env:ANSWER_OVERFLOW_KEY}";
            };
          };
          context7 = {
            type = "remote";
            url = "https://mcp.context7.com/mcp/oauth";
          };
        };

        agent = {
          build = {
            model = "anthropic/claude-opus-4-7";
          };
          plan = {
            model = "anthropic/claude-opus-4-7";
          };
          explore = {
            model = "anthropic/claude-haiku-4-5";
          };
        };
      };

      agents = {
        haiku = ''
          ---
          description: Fast, lightweight agent using Claude Haiku 4.5
          mode: subagent
          model: anthropic/claude-haiku-4-5
          ---
          You are a fast, efficient coding assistant powered by Claude Haiku.
          Prioritize speed and conciseness. Good for quick lookups, simple edits, and routine tasks.
        '';
        sonnet = ''
          ---
          description: Balanced agent using Claude Sonnet 4.6
          mode: subagent
          model: anthropic/claude-sonnet-4-6
          ---
          You are a capable coding assistant powered by Claude Sonnet.
          Balance thoroughness with efficiency. Good for most development tasks.
        '';
        opus = ''
          ---
          description: Most capable agent using Claude Opus 4.7
          mode: subagent
          model: anthropic/claude-opus-4-7
          ---
          You are an expert coding assistant powered by Claude Opus.
          Prioritize depth, correctness, and thorough analysis. Good for complex tasks, architecture decisions, and difficult debugging.
        '';
        codex = ''
          ---
          description: OpenAI GPT-5.4 agent
          mode: subagent
          model: openai/gpt-5.5
          ---
          You are a coding assistant powered by OpenAI GPT-5.4.
          Leverage your strengths in code generation, reasoning, and problem-solving.
        '';
      };
    };

    home.file.".config/opencode/plugins/peon-ping.ts" = modules.mkIf config.programs.peon-ping.enable {
      source = "${config.programs.peon-ping.package}/share/peon-ping/adapters/opencode/peon-ping.ts";
    };

    programs.peon-ping = modules.mkIf peonPingCfg.enable {
      enable = true;
      package = inputs'.peon-ping.packages.default;
      installPacks = peonPingCfg.packs;
      settings = lib.filterAttrs (_: v: v != null) peonSettings;
    };

    programs.zsh.initContent = lib.mkIf hasUserSecrets (
      lib.mkBefore ''
        export CIVITAI_API_TOKEN=$(cat ${config.sops.secrets.civitaiApiToken.path})
        export HF_TOKEN=$(cat ${config.sops.secrets.hfToken.path})
        export MORPH_API_KEY=$(cat ${config.sops.secrets.morphApiKey.path})
        export OPENROUTER_API_KEY=$(cat ${config.sops.secrets.openrouterApiKey.path})
        export ANSWER_OVERFLOW_KEY=$(cat ${config.sops.secrets.answerOverflowKey.path})
        export HOME_ASSISTANT_TOKEN=$(cat ${config.sops.secrets.homeAssistantToken.path})
      ''
    );
  };
}
