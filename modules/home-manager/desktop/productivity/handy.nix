# Handy offline speech-to-text — per-user session integration.
#
# The system-level pieces (package, /dev/uinput udev rule + uinput module,
# "input" group, wtype) live in modules/nixos/handy.nix. Here we do the
# per-user bits: autostart service, compositor keybind, persisted state, and
# declarative management of Handy's settings.
#
# Settings are stored by tauri-plugin-store in
#   ~/.config/com.pais.handy/settings_store.json
# under a top-level "settings" key. Handy rewrites that file at runtime (it
# backfills post-process providers and missing bindings on launch), so we
# cannot hand it a read-only Nix symlink. Instead an activation script
# deep-merges our declared overlay into the store on every rebuild, seeding a
# valid baseline first if the file is missing or corrupt. This keeps the file
# mutable for the app while re-asserting the declared values each switch.
#
# Note: Handy only reads the store at startup, so the handy service must be
# restarted (or the machine rebooted) for changes to take effect.
{
  config,
  osConfig,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  productivityCfg = guiCfg.productivity or {};
  handyCfg = productivityCfg.handy or {};

  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  handyEnabled = guiCfg.enable && productivityCfg.enable && handyCfg.enable;
  hyprlandEnabled = handyEnabled && (guiCfg.hyprland.enable or false);

  # Keys we re-assert on every activation. Deep-merged into the existing
  # ".settings" so unrelated/user-tweaked keys are preserved.
  settingsOverlay = {
    keyboard_implementation = handyCfg.keyboardImplementation;
    push_to_talk = handyCfg.pushToTalk;
    bindings.transcribe.current_binding = handyCfg.shortcut;
  };

  # Full default bindings (mirrors get_default_settings() for Linux). Only used
  # to seed a fresh/corrupt store; the merge step above handles the steady state.
  defaultBindings = {
    transcribe = {
      id = "transcribe";
      name = "Transcribe";
      description = "Converts your speech into text.";
      default_binding = "ctrl+space";
      current_binding = handyCfg.shortcut;
    };
    transcribe_with_post_process = {
      id = "transcribe_with_post_process";
      name = "Transcribe with Post-Processing";
      description = "Converts your speech into text and applies AI post-processing.";
      default_binding = "ctrl+shift+space";
      current_binding = "ctrl+shift+space";
    };
    cancel = {
      id = "cancel";
      name = "Cancel";
      description = "Cancels the current recording.";
      default_binding = "escape";
      current_binding = "escape";
    };
  };

  # Minimal-but-valid baseline: must contain every field that lacks a
  # #[serde(default)] in AppSettings (bindings, push_to_talk, audio_feedback,
  # external_script_path) or Handy rejects the file and resets to defaults.
  baseline = {
    settings = {
      bindings = defaultBindings;
      push_to_talk = handyCfg.pushToTalk;
      audio_feedback = false;
      external_script_path = null;
      keyboard_implementation = handyCfg.keyboardImplementation;
    };
  };

  baselineFile = pkgs.writeText "handy-settings-baseline.json" (builtins.toJSON baseline);
  overlayFile = pkgs.writeText "handy-settings-overlay.json" (builtins.toJSON settingsOverlay);
in {
  imports = [
    inputs.handy.homeManagerModules.default
  ];

  config = modules.mkIf handyEnabled {
    # Autostart the Handy background service on login (systemd user service
    # provided by the upstream HM module).
    services.handy.enable = true;

    # Bind Super+O to toggle dictation as a convenience alongside the native
    # push-to-talk shortcut. Shells out to the running instance via the CLI.
    wayland.windowManager.hyprland.settings.bind = modules.mkIf hyprlandEnabled (modules.mkAfter [
      "$main_mod, o, global, handy:transcribe"
    ]);

    # Declaratively enforce the settings that control the shortcut backend and
    # push-to-talk. See the header comment for why this is a merge rather than
    # a managed file.
    home.activation.handySettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      handyStore="${config.xdg.configHome}/com.pais.handy/settings_store.json"
      $DRY_RUN_CMD mkdir -p "$(dirname "$handyStore")"

      # Seed a valid baseline if the store is missing or not parseable.
      if [ ! -f "$handyStore" ] || ! ${pkgs.jq}/bin/jq -e . "$handyStore" >/dev/null 2>&1; then
        $DRY_RUN_CMD install -m600 ${baselineFile} "$handyStore"
      fi

      # Deep-merge the overlay into ".settings", preserving everything else.
      _handyTmp="$(mktemp)"
      if ${pkgs.jq}/bin/jq --argjson overlay "$(cat ${overlayFile})" \
          '.settings = ((.settings // {}) * $overlay)' "$handyStore" > "$_handyTmp"; then
        $DRY_RUN_CMD install -m600 "$_handyTmp" "$handyStore"
        $DRY_RUN_CMD rm -f "$_handyTmp"
      else
        rm -f "$_handyTmp"
        echo "handy: failed to merge settings into $handyStore; left unchanged" >&2
      fi
    '';

    # Persist config and downloaded models (Whisper/Parakeet weights are
    # hundreds of MB up to ~1.6GB) across the ephemeral-home reboots.
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/com.pais.handy"];
    };
  };
}
