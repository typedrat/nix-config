{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.services.home-assistant;
  musicAssistantCfg = cfg.musicAssistant;
in {
  options.rat.services.home-assistant.musicAssistant = {
    enable = options.mkEnableOption "Music Assistant as a Home Assistant media source";
  };

  config = modules.mkIf (cfg.enable && musicAssistantCfg.enable) {
    rat.services.music-assistant.enable = true;

    # The integration is config-flow only, and its auth step is a browser
    # redirect that trades a session token for a long-lived one, so nothing
    # beyond the component itself can be declared here. Home Assistant offers
    # the flow on its own once it sees the server's _mass._tcp advertisement.
    rat.services.home-assistant.extraComponents = lib.mkAfter ["music_assistant"];
  };
}
