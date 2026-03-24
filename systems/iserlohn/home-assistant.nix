{pkgs, ...}: {
  rat.services.matter-server.enable = true;

  rat.services.home-assistant = {
    enable = true;
    mqtt.enable = true;

    customComponents = with pkgs.home-assistant-custom-components; [
      adaptive_lighting
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

      # Chromecast
      "cast"

      # Denon AVR / HEOS
      "denonavr"
      "heos"

      # Electricity Maps
      "co2signal"

      # Enphase
      "enphase_envoy"

      # ESPHome
      "esphome"

      # Magic Home
      "flux_led"

      # HomeKit
      "homekit"
      "homekit_controller"

      # Matter
      "matter"

      # Jellyfin
      "jellyfin"

      # NWS
      "nws"

      # SMUD
      "opower"

      # TP-Link Kasa Smart
      "tplink"

      # Vizio TV
      "vizio"

      # Zigbee Home Automation
      "zha"
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

      # Sunrise wake-up alarm helpers
      input_datetime = {
        sunrise_alarm_time = {
          name = "Sunrise Alarm Time";
          has_date = false;
          has_time = true;
        };
      };

      input_boolean = {
        sunrise_alarm_enabled = {
          name = "Sunrise Alarm Enabled";
          icon = "mdi:weather-sunset-up";
        };
      };

      input_number = {
        sunrise_alarm_duration = {
          name = "Sunrise Ramp Duration (minutes)";
          min = 5;
          max = 60;
          step = 5;
          initial = 30;
          unit_of_measurement = "min";
          icon = "mdi:timer-outline";
        };
      };

      # Sunrise wake-up script
      script = {
        sunrise_wakeup = {
          alias = "Sunrise Wake-Up";
          mode = "restart";
          sequence = [
            {
              variables = rec {
                steps = 30;
                duration_sec = "{{ states('input_number.sunrise_alarm_duration') | float * 60 }}";
                step_delay = "{{ (duration_sec / ${toString steps}) | int }}";
              };
            }
            {
              repeat = {
                count = "{{ steps }}";
                sequence = [
                  # Stop if alarm toggle is turned off
                  {
                    condition = "state";
                    entity_id = "input_boolean.sunrise_alarm_enabled";
                    state = "on";
                  }
                  # After first step, stop if all lights were manually turned off
                  {
                    condition = "template";
                    value_template = ''
                      {{ repeat.index == 1 or
                         is_state('light.desk_lamp', 'on') or
                         is_state('light.ceiling_fan_lights', 'on') }}'';
                  }
                  {
                    variables = {
                      brightness = "{{ (repeat.index / steps * 255) | int }}";
                      color_temp = "{{ (2200 + (repeat.index / steps * 1800)) | int }}";
                    };
                  }
                  # Desk lamp — brightness only
                  {
                    action = "light.turn_on";
                    target.entity_id = "light.desk_lamp";
                    data = {
                      brightness = "{{ brightness }}";
                      transition = 1;
                    };
                  }
                  # Hue-capable lights — brightness + warm-to-neutral ramp
                  {
                    action = "light.turn_on";
                    target.entity_id = [
                      "light.ceiling_fan_lights"
                      "light.desk_skeleton_lamp"
                    ];
                    data = {
                      brightness = "{{ brightness }}";
                      color_temp_kelvin = "{{ color_temp }}";
                      transition = 1;
                    };
                  }
                  {
                    delay.seconds = "{{ step_delay }}";
                  }
                ];
              };
            }
            # Hand control back to Adaptive Lighting after ramp completes
            {
              action = "adaptive_lighting.set_manual_control";
              data = {
                entity_id = "switch.adaptive_lighting_bedroom";
                lights = [
                  "light.desk_lamp"
                  "light.ceiling_fan_lights"
                  "light.desk_skeleton_lamp"
                ];
                manual_control = false;
              };
            }
          ];
        };
      };

      # Sunrise alarm automation
      automation = [
        {
          alias = "Sunrise Alarm Trigger";
          id = "sunrise_alarm_trigger";
          trigger = [
            {
              platform = "time";
              at = "input_datetime.sunrise_alarm_time";
            }
          ];
          condition = [
            {
              condition = "state";
              entity_id = "input_boolean.sunrise_alarm_enabled";
              state = "on";
            }
          ];
          action = [
            {action = "script.sunrise_wakeup";}
          ];
        }
      ];
    };
  };

  # Ports 3030 and 3031 are used by the Elegoo integration
  networking.firewall.allowedTCPPorts = [
    3030
    3031
  ];
}
