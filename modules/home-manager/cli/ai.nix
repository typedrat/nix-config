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

  tankRoot =
    if impermanenceCfg.tank.enable
    then impermanenceCfg.tankDir
    else persistDir;

  hasUserSecrets = builtins.pathExists (config.rat.userSecretsDir + "/ai.yaml");
  # civitai and hf tokens live in the shared file, which only the sops admin
  # key can open.
  hasSharedSecrets = username == "awilliams";
  hasNvidia = osConfig.rat.hardware.nvidia.enable;
  gpuVram = osConfig.rat.hardware.gpu.vram;
  hasLargeVram = gpuVram >= 16;
  guiCfg = userCfg.gui or {};
  hasChromium = (guiCfg.enable or false) && (guiCfg.browsers.chromium.enable or false);
  peonPingCfg = cliCfg.ai.peon-ping or {};
  peonSettings = peonPingCfg.settings or {};

  opencodeCfg = cliCfg.ai.opencode;
  effective = (import ./ai-layering.nix {inherit lib;}).mergeHarness cliCfg.ai opencodeCfg;

  # home-manager's enableMcpIntegration still writes OpenCode 1's flat
  # `mcp.<name>`; OpenCode 2 wants `mcp.servers.<name>`.
  toOpencodeMcp = server:
    if server ? url
    then
      {
        type = "remote";
        inherit (server) url;
      }
      // lib.optionalAttrs (server ? headers) {inherit (server) headers;}
    else
      {
        type = "local";
        command = [server.command] ++ (server.args or []);
      }
      // lib.optionalAttrs (server ? env) {environment = server.env;};

  # Lists are ordered in OpenCode (the last matching permission wins), so a
  # user's additions go after the defaults rather than replacing them.
  listSettings = ["plugins" "permissions" "instructions" "skills"];
  nestedSettings = ["mcp" "agents"];
  mergeSettings = base: overlay:
    base
    // overlay
    // lib.genAttrs (lib.filter (k: overlay ? ${k}) listSettings) (k: (base.${k} or []) ++ overlay.${k})
    // lib.genAttrs (lib.filter (k: overlay ? ${k}) nestedSettings) (k: lib.recursiveUpdate (base.${k} or {}) overlay.${k});

  # comfy-cli ships Claude Code skills without a plugin manifest; wrapping its
  # skills directory as a plugin picks up whatever the installed version has.
  comfySkillsPlugin = pkgs.runCommand "comfy-cli-claude-plugin" {} ''
    mkdir -p $out/.claude-plugin
    echo '{"name": "comfy-cli"}' > $out/.claude-plugin/plugin.json
    ln -s ${config.programs.comfy-cli.package.src}/comfy_cli/skills $out/skills
  '';

  mcpServers =
    {
      context7.url = "https://mcp.context7.com/mcp/oauth";
      linear-server.url = "https://mcp.linear.app/mcp";
      # OAuth in the browser on first use; billed to Pangram API credits.
      pangram.url = "https://www.pangram.com/mcp";
    }
    // lib.optionalAttrs hasChromium {
      # https://github.com/ChromeDevTools/chrome-devtools-mcp
      # Drives the user's real Chrome via --autoConnect: it attaches to an
      # already-running Chrome (>= 144) using the default profile rather than
      # launching its own. Requires a one-time opt-in in Chrome at
      # chrome://inspect/#remote-debugging. If Chrome is not running, browser
      # tool calls fail (the server will not spawn a browser on its own).
      chrome-devtools = {
        command = "npx";
        args = [
          "-y"
          "chrome-devtools-mcp@latest"
          "--autoConnect"
          # No phoning home: disable CrUX field-data lookups and usage stats.
          "--no-performance-crux"
          "--no-usage-statistics"
        ];
        env = {
          CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS = "1";
          CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1";
        };
      };
    };
in {
  imports = [
    inputs.peon-ping.homeManagerModules.default
  ];

  config = modules.mkIf (cliCfg.enable && cliCfg.ai.enable) {
    xdg.userDirs.extraConfig.XDG_AI_DIR = "$HOME/AI";

    home.persistence = modules.mkIf impermanenceCfg.home.enable (modules.mkMerge [
      {
        ${persistDir}.directories = [
          ".codex"
          ".config/opencode"
          ".local/share/opencode"
          ".local/state/opencode"
          ".gstack"
          ".openpeon"

          # yes, this is where the authentication data for OpenCode lives
          # I want to shove a copy of the XDG specification up someone's asshole.
          ".cache/opencode"
        ];
      }
      {
        # On ulysses these land on the tank pool; elsewhere tankRoot falls back
        # to persistDir and mkMerge folds them into the block above.
        ${tankRoot}.directories = [
          "AI"

          # HuggingFace model/dataset cache — large downloads worth persisting
          ".cache/huggingface"
        ];
      }
    ]);

    sops.secrets = lib.mkIf hasSharedSecrets {
      civitaiApiToken = {};
      hfToken = {};
    };

    rat.userSecrets = lib.mkIf hasUserSecrets {
      ai = {
        openrouterApiKey = {};
        answerOverflowKey = {};
        homeAssistantToken = {};
        vastApiKey = {};
      };
    };

    home.packages =
      (with pkgs; [
        (osConfig.rat.agentSlice.wrap codex)
        llm
        # hiPrio: wins the `hf` binary collision against huggingface-hub
        # pulled transitively into the cli/python.nix scripting environment
        # (e.g. via gradio).
        (lib.hiPrio python3Packages.huggingface-hub)
        vast-cli
      ])
      ++ lib.optional (hasNvidia && hasLargeVram) pkgs.llama-cpp
      ++ lib.optional (hasNvidia && hasLargeVram) (pkgs.nemo-speech.override {
        japaneseSupport = true;
        mandarinSupport = true;
        cudaSupport = true;
        inherit (osConfig.rat.hardware.gpu) cudaArchitectures;
      });

    home.sessionVariables =
      {
        HF_XET_HIGH_PERFORMANCE = "1";
        OPENCODE_EXPERIMENTAL = "1";
      }
      // lib.optionalAttrs hasChromium {
        GSTACK_CHROMIUM_PATH = lib.getExe config.programs.google-chrome.package;
      };

    programs.comfy-cli = {
      enable = true;
      package = pkgs.comfy-cli;
    };

    programs.claude-code.plugins = {
      comfy-cli = comfySkillsPlugin;
      exa = inputs.exa-mcp-server;
    };

    home.file.".config/opencode/plugins/peon-ping.ts" = modules.mkIf config.programs.peon-ping.enable {
      source = "${config.programs.peon-ping.package}/share/peon-ping/adapters/opencode/peon-ping.ts";
    };

    catppuccin.opencode.enable = false;

    # OpenCode gets every server. Claude Code reaches Linear and Context7
    # through claude.ai's connectors, so it takes everything else.
    programs.mcp = {
      enable = true;
      servers = mcpServers;
    };
    programs.claude-code.mcpServers = removeAttrs mcpServers ["context7" "linear-server"];

    xdg.configFile = lib.mapAttrs' (name: rule:
      lib.nameValuePair "opencode/rules/${name}.md" (
        if lib.isPath rule
        then {source = rule;}
        else {text = rule;}
      ))
    effective.rules;

    programs.opencode = {
      enable = true;
      package = osConfig.rat.agentSlice.wrap pkgs.opencode;

      validateFiles = {
        config = true;
        cli = true;
      };

      inherit (effective) context skills;

      # catppuccin/nix's opencode port still writes tui.json, which OpenCode 2
      # ignores, so the theme is set here and the port is disabled below.
      cli = lib.recursiveUpdate {
        theme.name =
          if config.catppuccin.enable
          then "catppuccin-${config.catppuccin.flavor}"
          else "catppuccin-frappe";
        animations = true;
        diffs.wrap = "word";
        prompt.editor = false;
        session = {
          sidebar = "auto";
          scrollbar = true;
          thinking = "show";
        };
        # peon-ping plays the sounds.
        attention = {
          notifications = true;
          sound = false;
        };
      } opencodeCfg.cli;

      settings = mergeSettings {
        plugins = [
          "@ex-machina/opencode-anthropic-auth@next"
          "superpowers@git+https://github.com/obra/superpowers.git"
        ];

        # OpenCode 2 allows every outside directory unless told otherwise.
        permissions =
          [
            {
              action = "external_directory";
              resource = "*";
              effect = "ask";
            }
          ]
          ++ map (resource: {
            action = "external_directory";
            inherit resource;
            effect = "allow";
          }) [
            "/nix/store/*"
            "/tmp/*"
            "~/.claude/skills/*"
            "~/.gstack/*"
          ];

        # Claude Code reads its plugin's copy of Exa's server.
        mcp.servers =
          lib.mapAttrs (_: toOpencodeMcp) mcpServers
          // {
            exa = {
              type = "remote";
              url = "https://mcp.exa.ai/mcp?client=agent-plugin";
              headers.x-exa-source = "agent-plugin";
            };
          };

        instructions = map (name: "~/.config/opencode/rules/${name}.md") (lib.attrNames effective.rules);

        skills = ["${inputs.modern-web-guidance}/skills"];

        agents = {
          build.model = "anthropic/claude-opus-5-5";
          plan.model = "anthropic/claude-opus-5-5";
          explore.model = "anthropic/claude-haiku-5-5";
        };
      } opencodeCfg.settings;

      agents = {
        haiku = ''
          ---
          description: Fast, lightweight agent using Claude Haiku 5.5
          mode: subagent
          model: anthropic/claude-haiku-5-5
          ---
          You are a fast, efficient coding assistant powered by Claude Haiku.
          Prioritize speed and conciseness. Good for quick lookups, simple edits, and routine tasks.
        '';
        sonnet = ''
          ---
          description: Balanced agent using Claude Sonnet 5.5
          mode: subagent
          model: anthropic/claude-sonnet-5-5
          ---
          You are a capable coding assistant powered by Claude Sonnet.
          Balance thoroughness with efficiency. Good for most development tasks.
        '';
        opus = ''
          ---
          description: Most capable agent using Claude Opus 5.5
          mode: subagent
          model: anthropic/claude-opus-5-5
          ---
          You are an expert coding assistant powered by Claude Opus.
          Prioritize depth, correctness, and thorough analysis. Good for complex tasks, architecture decisions, and difficult debugging.
        '';
        codex = ''
          ---
          description: OpenAI agent using GPT-6.2 Sol
          mode: subagent
          model: openai/gpt-6.2-sol
          ---
          You are a coding assistant powered by OpenAI GPT-6.2 Sol.
          Leverage your strengths in code generation, reasoning, and problem-solving.
        '';
        codex-astra = ''
          ---
          description: OpenAI agent using GPT-6.2 Astra
          mode: subagent
          model: openai/gpt-6.2-astra
          ---
          You are a coding assistant powered by OpenAI GPT-6.2 Astra.
          Leverage your strengths in code generation, reasoning, and problem-solving.
        '';
      };
    };

    programs.peon-ping = modules.mkIf peonPingCfg.enable {
      enable = true;
      package = inputs'.peon-ping.packages.default;
      installPacks = peonPingCfg.packs;
      settings = lib.filterAttrs (_: v: v != null) peonSettings;
    };

    programs.zsh.initContent = lib.mkBefore (
      lib.optionalString hasSharedSecrets ''
        export CIVITAI_API_TOKEN=$(cat ${config.sops.secrets.civitaiApiToken.path})
        export HF_TOKEN=$(cat ${config.sops.secrets.hfToken.path})
      ''
      + lib.optionalString hasUserSecrets ''
        export OPENROUTER_API_KEY=$(cat ${config.sops.secrets."ai/openrouterApiKey".path})
        export ANSWER_OVERFLOW_KEY=$(cat ${config.sops.secrets."ai/answerOverflowKey".path})
        export HOME_ASSISTANT_TOKEN=$(cat ${config.sops.secrets."ai/homeAssistantToken".path})
        export VAST_API_KEY=$(cat ${config.sops.secrets."ai/vastApiKey".path})
      ''
    );
  };
}
