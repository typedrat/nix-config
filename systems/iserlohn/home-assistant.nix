{pkgs, ...}: {
  rat.services.home-assistant = {
    enable = true;
    mqtt.enable = true;

    customComponents = with pkgs.home-assistant-custom-components; [
      elegoo_printer
      localtuya
      waste_collection_schedule
    ];

    extraComponents = [
      # Components required to complete the onboarding
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"

      # Recommended for fast zlib compression
      # https://www.home-assistant.io/integrations/isal
      "isal"

      # Apple TV
      "apple_tv"

      # Denon AVR
      "denonavr"

      # Electricity Maps
      "co2signal"

      # Enphase
      "enphase_envoy"

      # ESPHome
      "esphome"

      # Magic Home
      "flux_led"

      # Jellyfin
      "jellyfin"

      # NWS
      "nws"

      # SMUD
      "opower"

      # Vizio TV
      "vizio"
    ];

    config = {
      default_config = {};

      waste_collection_schedule = {
        sources = [
          {
            name = "ics";
            args = {
              url = "!secret waste_collection_schedule_url";
            };
          }
        ];
      };
    };
  };

  # Ports 3030 and 3031 are used by the Elegoo integration
  networking.firewall.allowedTCPPorts = [
    3030
    3031
  ];
}
