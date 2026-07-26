# Handy offline speech-to-text — per-user session integration.
#
# The system-level pieces (package, /dev/uinput udev rule + uinput module,
# "input" group, wtype) live in modules/nixos/handy.nix. Here we do the
# per-user bits: autostart service, persisted state, the vendored model
# weights, and declarative management of Handy's settings.
#
# Handy resolves catalog models through hf-hub's shared cache
#   ~/.cache/huggingface/hub/models--<org>--<repo>/
#     refs/<revision>            -> the commit hash
#     snapshots/<hash>/<file>    -> the weights
# (hf-hub reads $HF_HOME/hub, else that literal path — it does not honour
# XDG_CACHE_HOME.) The pkgs.handy-parakeet-unified-en derivation *is* such a
# repo directory, so symlinking it into the cache makes the catalog entry
# report itself as downloaded and Handy runs offline from the first launch,
# with no ~700MB runtime download.
#
# Settings are stored by tauri-plugin-store in the app-data dir
#   ~/.local/share/com.pais.handy/settings_store.json
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

  inherit (pkgs) handy-parakeet-unified-en;
  hfCacheHome = "${config.home.homeDirectory}/.cache/huggingface/hub";

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
      selected_model = handy-parakeet-unified-en.modelId;
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
    services.handy = {
      enable = true;
      inherit (osConfig.programs.handy) package;
    };

    # Declaratively enforce the settings that control the shortcut backend and
    # push-to-talk. See the header comment for why this is a merge rather than
    # a managed file.
    home.activation.handyModel = lib.hm.dag.entryAfter ["writeBoundary"] ''
      handyRepo="${hfCacheHome}/${handy-parakeet-unified-en.cacheDirName}"

      # Only ever replace our own symlink. A real directory here is a repo the
      # user (or another HF tool) downloaded, and clobbering it would throw away
      # hundreds of megabytes that Handy is probably still pointing at.
      if [ -L "$handyRepo" ] || [ ! -e "$handyRepo" ]; then
        $DRY_RUN_CMD mkdir -p "${hfCacheHome}"
        $DRY_RUN_CMD ln -sfn ${handy-parakeet-unified-en} "$handyRepo"
      else
        echo "handy: $handyRepo is not a symlink; leaving the downloaded copy in place" >&2
      fi
    '';

    home.activation.handySettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      handyStore="${config.xdg.dataHome}/com.pais.handy/settings_store.json"
      $DRY_RUN_CMD mkdir -p "$(dirname "$handyStore")"

      # Seed a valid baseline if the store is missing or not parseable.
      if [ ! -f "$handyStore" ] || ! ${pkgs.jq}/bin/jq -e . "$handyStore" >/dev/null 2>&1; then
        $DRY_RUN_CMD install -m600 ${baselineFile} "$handyStore"
      fi

      # Deep-merge the overlay into ".settings", preserving everything else, and
      # point an unselected install at the vendored model. Selection is seeded
      # rather than re-asserted: Handy's own auto-selection stays off until
      # onboarding finishes, so without this a fresh profile sits with no model
      # despite one being on disk — but a model the user picked in the UI is
      # theirs to keep.
      _handyTmp="$(mktemp)"
      if ${pkgs.jq}/bin/jq --argjson overlay "$(cat ${overlayFile})" \
          --arg model "${handy-parakeet-unified-en.modelId}" \
          '.settings = ((.settings // {}) * $overlay)
           | if (.settings.selected_model // "") == ""
             then .settings.selected_model = $model
             else . end' "$handyStore" > "$_handyTmp"; then
        $DRY_RUN_CMD install -m600 "$_handyTmp" "$handyStore"
        $DRY_RUN_CMD rm -f "$_handyTmp"
      else
        rm -f "$_handyTmp"
        echo "handy: failed to merge settings into $handyStore; left unchanged" >&2
      fi
    '';

    # Persist the app-data dir, which holds the settings store, transcription
    # history, recordings, and downloaded models (Whisper/Parakeet weights are
    # hundreds of MB up to ~1.6GB) across the ephemeral-home reboots.
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".local/share/com.pais.handy"];
    };
  };
}
