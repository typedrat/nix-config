{lib, ...}: let
  inherit (lib) options types;
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.cli.ai = {
        enable = options.mkEnableOption "AI tools and configuration" // {default = true;};

        peon-ping = {
          enable = options.mkEnableOption "peon-ping AI agent notifications";

          packs = options.mkOption {
            type = types.listOf (types.either types.str (types.submodule {
              options = {
                name = options.mkOption {
                  type = types.str;
                  description = "Name of the sound pack (used as directory name)";
                };
                src = options.mkOption {
                  type = types.either types.package types.path;
                  description = "Source for the pack (fetchFromGitHub, fetchzip, path, etc.)";
                };
              };
            }));
            default = [];
            description = "Sound packs to install (built-in names as strings, or {name, src} for third-party)";
          };

          settings = {
            # --- Audio ---

            default_pack = options.mkOption {
              type = types.str;
              default = "peon";
              description = "Default sound pack to use for notifications";
            };

            volume = options.mkOption {
              type = types.numbers.between 0.0 1.0;
              default = 0.5;
              description = "Notification volume (0.0 to 1.0)";
            };

            enabled = options.mkOption {
              type = types.bool;
              default = true;
              description = "Master audio switch (independent from desktop/mobile notifications)";
            };

            headphones_only = options.mkOption {
              type = types.bool;
              default = false;
              description = "Only play sounds when headphones are detected";
            };

            use_sound_effects_device = options.mkOption {
              type = types.bool;
              default = true;
              description = "Whether to use the system sound effects audio device";
            };

            suppress_sound_when_tab_focused = options.mkOption {
              type = types.bool;
              default = false;
              description = "Skip audio if the originating tab is active (macOS iTerm2 only)";
            };

            meeting_detect = options.mkOption {
              type = types.bool;
              default = false;
              description = "Suppress audio when microphone is in use";
            };

            # --- Desktop notifications ---

            desktop_notifications = options.mkOption {
              type = types.bool;
              default = true;
              description = "Whether to show desktop notification overlays";
            };

            notification_style = options.mkOption {
              type = types.enum ["overlay" "standard"];
              default = "overlay";
              description = "Notification display mode";
            };

            overlay_theme = options.mkOption {
              type = types.nullOr (types.enum ["jarvis" "glass" "sakura"]);
              default = null;
              description = "Overlay theme (macOS only; null for default)";
            };

            notification_position = options.mkOption {
              type = types.enum [
                "top-left"
                "top-center"
                "top-right"
                "bottom-left"
                "bottom-center"
                "bottom-right"
              ];
              default = "top-center";
              description = "Position of the notification overlay";
            };

            notification_dismiss_seconds = options.mkOption {
              type = types.ints.unsigned;
              default = 4;
              description = "Auto-dismiss time in seconds (0 = persistent)";
            };

            notification_title_override = options.mkOption {
              type = types.str;
              default = "";
              description = "Custom project name shown in notification titles";
            };

            notification_title_script = options.mkOption {
              type = types.str;
              default = "";
              description = "Shell command to dynamically compute the project name for notifications";
            };

            notification_templates = options.mkOption {
              type = types.attrsOf types.str;
              default = {};
              description = "Custom notification message formats per event type";
            };

            project_name_map = options.mkOption {
              type = types.attrsOf types.str;
              default = {};
              description = "Map directory paths to display labels for notifications";
            };

            # --- Event categories ---

            categories = options.mkOption {
              type = types.submodule {
                options = {
                  "session.start" = options.mkEnableOption "greeting sounds on session start" // {default = true;};
                  "task.complete" = options.mkEnableOption "success sounds on task completion" // {default = true;};
                  "task.error" = options.mkEnableOption "error sounds on task failure" // {default = true;};
                  "input.required" = options.mkEnableOption "request sounds when permission is needed" // {default = true;};
                  "resource.limit" = options.mkEnableOption "resource limit warning sounds" // {default = true;};
                  "user.spam" = options.mkEnableOption "spam detection sounds for rapid prompts" // {default = true;};
                  "task.acknowledge" = options.mkEnableOption "acknowledgement sounds";
                };
              };
              default = {};
              description = "Toggle individual CESP sound event categories";
            };

            # --- Spam / rate-limiting ---

            annoyed_threshold = options.mkOption {
              type = types.ints.unsigned;
              default = 3;
              description = "Number of rapid prompts before triggering annoyed/spam sounds";
            };

            annoyed_window_seconds = options.mkOption {
              type = types.ints.unsigned;
              default = 10;
              description = "Time window in seconds for counting rapid prompts";
            };

            silent_window_seconds = options.mkOption {
              type = types.ints.unsigned;
              default = 0;
              description = "Cooldown in seconds after playing a sound before another can play (0 = no cooldown)";
            };

            session_start_cooldown_seconds = options.mkOption {
              type = types.ints.unsigned;
              default = 30;
              description = "Deduplicate greeting sounds across simultaneous workspaces";
            };

            suppress_subagent_complete = options.mkOption {
              type = types.bool;
              default = false;
              description = "Whether to suppress completion sounds from subagent tasks";
            };

            # --- Pack rotation ---

            pack_rotation = options.mkOption {
              type = types.listOf types.str;
              default = [];
              description = "List of pack names to rotate between";
            };

            pack_rotation_mode = options.mkOption {
              type = types.enum ["random" "round-robin" "session_override"];
              default = "random";
              description = "How to rotate between packs in pack_rotation";
            };

            session_ttl_days = options.mkOption {
              type = types.ints.unsigned;
              default = 7;
              description = "Expire stale per-session pack assignments after this many days";
            };

            # --- Per-directory pack rules ---

            path_rules = options.mkOption {
              type = types.listOf (types.submodule {
                options = {
                  pattern = options.mkOption {
                    type = types.str;
                    description = "Directory glob pattern to match";
                  };
                  pack = options.mkOption {
                    type = types.str;
                    description = "Sound pack to use for matching directories";
                  };
                };
              });
              default = [];
              description = "Bind specific directory patterns to sound packs";
              example = [
                {
                  pattern = "~/work/*";
                  pack = "glados";
                }
              ];
            };

            # --- Mobile notifications ---

            mobile_notify = options.mkOption {
              type = types.submodule {
                options.enabled = options.mkEnableOption "mobile push notifications";
              };
              default = {};
              description = "Mobile push notification settings (configure via `peon mobile`)";
            };
          };
        };
      };
    });
  };
}
