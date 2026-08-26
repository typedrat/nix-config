{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.services.home-assistant;
  go2rtcCfg = cfg.go2rtc;
in {
  options.rat.services.home-assistant.go2rtc = {
    enable = options.mkEnableOption "go2rtc as Home Assistant's WebRTC provider";
  };

  config = modules.mkIf (cfg.enable && go2rtcCfg.enable) {
    rat.services.go2rtc.enable = true;

    rat.services.home-assistant = {
      extraComponents = lib.mkAfter ["go2rtc"];

      # Cameras that expose a stream source get WebRTC instead of HLS: Home
      # Assistant registers the source with go2rtc over this API and brokers
      # the offer, then the browser talks to go2rtc directly. Registration is
      # a passthrough, so a camera whose own stream is unusable still needs an
      # explicit entry under `rat.services.go2rtc.streams`.
      config.go2rtc.url = config.links.go2rtc.url;
    };

    # go2rtc leaves `url` out of a producer that is actively connected over a
    # protocol whose client does not carry one — tapo:// among them — while
    # go2rtc-client declares the field required. The decode blows up inside
    # streams.list(), which parses every stream in one response, so a single
    # such producer fails WebRTC for every camera rather than just its own.
    # Drop this once the field is optional upstream; 0.4.0 is current.
    services.home-assistant.package =
      (pkgs.home-assistant.override {
        packageOverrides = _final: prev: {
          go2rtc-client = prev.go2rtc-client.overridePythonAttrs (old: {
            postPatch =
              (old.postPatch or "")
              + ''
                substituteInPlace go2rtc_client/models.py \
                  --replace-fail 'url: str' 'url: str | None = None'
              '';
          });
        };
      })
      .overrideAttrs (_: {
        doInstallCheck = false;
      });
  };
}
