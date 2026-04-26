{pkgs, ...}: {
  # Patch zha-quirks to add SONOFF MINI DUO (ZB2GS) and MINI DUO-L (ZB2GS-L) support
  # zigpy/zha-device-handlers#4902 — ZB2GS-L no-neutral variant (depends on #4742)
  services.home-assistant.package = pkgs.home-assistant.override {
    packageOverrides = _self: super: {
      zha-quirks = super.zha-quirks.overridePythonAttrs (oldAttrs: {
        patches =
          (oldAttrs.patches or [])
          ++ [
            (pkgs.fetchpatch {
              url = "https://github.com/zigpy/zha-device-handlers/pull/4902.diff";
              hash = "sha256-rbT4UsFdi/jSkcN+rBui5stVI0daHrQGg84e9kug1OI=";
            })
          ];
      });
    };
  };
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

      # Model Context Protocol
      "mcp"
      "mcp_server"

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

        # Sync bathroom wall switches → devices (detach relay mode)
        # The SONOFF MINI's detach mode is all-or-nothing, so both
        # the light and fan switches need HA automations to work.
        {
          alias = "Bathroom Switch → Vanity On";
          id = "bathroom_switch_vanity_on";
          trigger = [
            {
              platform = "state";
              entity_id = "binary_sensor.bathroom_light_switch";
              to = "on";
            }
          ];
          action = [
            {
              action = "light.turn_on";
              target.entity_id = "light.bathroom_vanity_light";
            }
          ];
        }
        {
          alias = "Bathroom Switch → Vanity Off";
          id = "bathroom_switch_vanity_off";
          trigger = [
            {
              platform = "state";
              entity_id = "binary_sensor.bathroom_light_switch";
              to = "off";
            }
          ];
           action = [
            {
              action = "light.turn_off";
              target.entity_id = "light.bathroom_vanity_light";
            }
          ];
        }
        {
          alias = "Bathroom Switch → Fan On";
          id = "bathroom_switch_fan_on";
          trigger = [
            {
              platform = "state";
              entity_id = "binary_sensor.bathroom_fan_switch";
              to = "on";
            }
          ];
          action = [
            {
              action = "fan.turn_on";
              target.entity_id = "fan.bathroom_fan";
            }
          ];
        }
        {
          alias = "Bathroom Switch → Fan Off";
          id = "bathroom_switch_fan_off";
          trigger = [
            {
              platform = "state";
              entity_id = "binary_sensor.bathroom_fan_switch";
              to = "off";
            }
          ];
          action = [
            {
              action = "fan.turn_off";
              target.entity_id = "fan.bathroom_fan";
            }
          ];
        }

        # Sync 3D printer chamber light → riser light
        {
          alias = "Centauri Chamber → Riser On";
          id = "centauri_chamber_riser_on";
          trigger = [
            {
              platform = "state";
              entity_id = "light.centauri_carbon_chamber_light";
              to = "on";
            }
          ];
          action = [
            {
              action = "light.turn_on";
              target.entity_id = "light.centauri_carbon_riser_light";
            }
          ];
        }
        {
          alias = "Centauri Chamber → Riser Off";
          id = "centauri_chamber_riser_off";
          trigger = [
            {
              platform = "state";
              entity_id = "light.centauri_carbon_chamber_light";
              to = "off";
            }
          ];
          action = [
            {
              action = "light.turn_off";
              target.entity_id = "light.centauri_carbon_riser_light";
            }
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
