{
  config,
  pkgs,
  ...
}: {
  rat.services.ha-mcp.enable = true;

  rat.services.matter-server.enable = true;

  rat.services.zwave-js = {
    enable = true;
    serialPort = "/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00";
  };

  # zwave-js defaults to querying sensors in Celsius. The Honeywell T6 Pro
  # sometimes answers those with a Celsius value flagged as Fahrenheit,
  # so HA shows e.g. 27 °F for 27 °C. Preferring Fahrenheit makes the
  # driver request/normalize temperatures in °F, matching the thermostat.
  services.zwave-js.settings.preferences.scales.temperature = "Fahrenheit";

  sops.secrets."go2rtc/tapo_cloud_password" = {
    sopsFile = ../../secrets/go2rtc.yaml;
    key = "tapo_cloud_password";
    restartUnits = ["go2rtc.service"];
  };

  sops.secrets."printguard/mqtt_password" = {
    sopsFile = ../../secrets/printguard.yaml;
    key = "mqtt_password";
    # The seed step runs as the service user and reads this directly.
    # Mosquitto takes it through systemd credentials, which the service manager
    # resolves as root, so narrowing the owner does not affect the broker.
    owner = "printguard";
    # Mosquitto bakes this into its password database at preStart, and
    # PrintGuard itself never reads the file — the credentials are entered
    # in its web UI. Rotating the password only takes effect once the broker
    # restarts.
    restartUnits = ["mosquitto.service"];
  };

  rat.services.printguard = {
    enable = true;

    # Written only if state.json is absent, so a rebuilt host comes back with
    # the printer, camera and monitor already wired. PrintGuard owns the file
    # afterwards -- changes made in its UI persist and are not reverted.
    seed = {
      enable = true;
      mqttPasswordFile = config.sops.secrets."printguard/mqtt_password".path;

      state = {
        printers = [
          {
            id = "centauri";
            name = "Centauri Carbon";
            # Real Klipper, not Elegoo's fork, so the generic Moonraker adapter
            # applies. Moonraker answers on port 80 here rather than the usual
            # 7125, and needs no API key on a trusted LAN.
            provider = "klipper";
            config.base_url = "http://Centauri-Carbon.lan";
          }
        ];

        cameras = [
          {
            # This id is what the printer's own webcam discovery would generate
            # (<printer id>-<moonraker webcam uid>), so claiming it first means
            # the discovered camera is never added and this source stands. Left
            # to itself PrintGuard would pull the printer's MJPEG directly,
            # putting a second consumer on a 128MB single-core board and
            # reintroducing the untimestamped stream go2rtc exists to repair.
            id = "centauri-56ec4ede-7367-552e-9a77-e1d425c44067";
            name = "Centauri Webcam";
            printer_id = "centauri";
            # Mandatory: the restore path reads record["max_fps"] directly and
            # CAMERA_DEFAULTS has no entry for it, so a record without it takes
            # the whole engine down with a KeyError on start.
            max_fps = 15.0;
            source = {
              kind = "url";
              url = "${config.links.go2rtc-rtsp.url}/centauri_webcam";
            };
          }
        ];

        monitors = [
          {
            id = "centauri";
            name = "Centauri Carbon";
            camera_id = "centauri-56ec4ede-7367-552e-9a77-e1d425c44067";
            printer_id = "centauri";
            enabled = true;
            # Alert only until the detector has been watched over a few real
            # prints; flip to "pause" once its behaviour is known.
            on_defect = "none";
            # Home Assistant sees defects over MQTT, so PrintGuard's own
            # notifier stays off rather than duplicating them.
            notify = false;
          }
        ];

        settings.mqtt = {
          enabled = true;
          host = config.links.mosquitto.ipv4;
          inherit (config.links.mosquitto) port;
          username = "printguard";
          tls = false;
        };
      };
    };
  };

  # PrintGuard publishes HA MQTT discovery for each monitor, so it needs the
  # same homeassistant/ topic access the HA user has.
  rat.services.mosquitto.users.printguard = {
    passwordFile = config.sops.secrets."printguard/mqtt_password".path;
    acl = [
      # Discovery goes under homeassistant/; everything else -- state, the
      # snapshot, the last will, and the command topics it subscribes to --
      # lives under the default base_topic.
      "readwrite printguard/#"
      "readwrite homeassistant/#"
      "read homeassistant/status"
    ];
  };

  rat.services.go2rtc = {
    enable = true;

    # WebRTC media goes browser-to-go2rtc directly, so the port has to be
    # reachable rather than proxied. The stun candidate only resolves to
    # something usable once 8555 is forwarded to this host; without that,
    # off-LAN viewers fall back to HLS, which still reads the repaired
    # streams below.
    openFirewall = true;
    webrtcCandidates = ["stun:8555"];

    credentials.TAPO_CLOUD_PASSWORD =
      config.sops.secrets."go2rtc/tapo_cloud_password".path;

    ffmpegTemplates = {
      # Crowsnest's multipart MJPEG carries no timestamps, so a muxer bills
      # the ~8 frames it gets each second against the 25fps the container
      # claims and playback crawls. Take timing from arrival instead.
      mjpegin = "-use_wallclock_as_timestamps 1 -i {input}";

      # Keyframes on a wall-clock interval, not a frame count: the source
      # runs 5fps idle and 15fps printing, so a fixed -g would stretch the
      # gap between keyframes to twelve seconds on an idle printer.
      mjpeg2h264 =
        "-codec:v libx264 -preset:v superfast -tune:v zerolatency"
        + " -profile:v main -level:v 4.1 -pix_fmt yuv420p"
        + " -force_key_frames expr:gte(t,n_forced*2)";
    };

    streams = {
      # The C110's RTSP server is what the tplink integration pulls, and that
      # path is where the macroblock corruption comes from. TP-Link's own
      # protocol carries the same 2304x1296 feed with a clean two-second GOP,
      # so this hands the bitstream over untouched.
      centauri_external = "tapo://\${TAPO_CLOUD_PASSWORD}@C110.lan";

      # Moonraker's camera has no stream source for Home Assistant to hand to
      # go2rtc, so it is declared here and re-encoded to H.264.
      centauri_webcam =
        "ffmpeg:http://Centauri-Carbon.lan/webcam/?action=stream"
        + "#video=mjpeg2h264#input=mjpegin";
    };
  };

  rat.services.home-assistant = {
    enable = true;
    mqtt.enable = true;
    # Home Assistant needs the PrintGuard topic tree too, or the entities
    # discovery creates stay unavailable and their controls do nothing.
    mqtt.extraAclRules = ["readwrite printguard/#"];
    go2rtc.enable = true;

    customComponents = with pkgs.home-assistant-custom-components; [
      adaptive_lighting
      elegoo_printer
      ha_mcp_tools
      localtuya
      moonraker
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

      # Camera platform for the go2rtc-fed entities
      "ffmpeg"

      # Magic Home
      "flux_led"

      # HomeKit
      "homekit"
      "homekit_controller"

      # Matter
      "matter"

      # Model Context Protocol client, for pointing Assist at an external
      # MCP server. The built-in mcp_server is left out: ha-mcp replaces it.
      "mcp"

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

      # Z-Wave
      "zwave_js"
    ];

    config = {
      default_config = {};

      # Both printer cameras are served from go2rtc rather than from their
      # own integrations: the Tapo's RTSP output arrives with corrupted
      # reference frames, and Moonraker's MJPEG entity advertises no stream
      # source at all, which leaves it stuck on Home Assistant's proxy and
      # excluded from WebRTC. FFmpegCamera derives its stream source from the
      # last whitespace-separated token of `input`, so the bare URL is what
      # the go2rtc integration ends up brokering.
      camera = [
        {
          platform = "ffmpeg";
          name = "Centauri External";
          input = "${config.links.go2rtc-rtsp.url}/centauri_external";
        }
        {
          platform = "ffmpeg";
          name = "Centauri Webcam";
          input = "${config.links.go2rtc-rtsp.url}/centauri_webcam";
        }
      ];

      # Home zone: 4800 Trona Way, Fair Oaks, CA 95628
      homeassistant.latitude = 38.652948;
      homeassistant.longitude = -121.293407;

      # HomeKit-friendly wrapper for the Vizio TV that hides the firehose of
      # FAST/streaming sources the TV advertises. The Vizio integration
      # publishes ~300 sources (FAST channels, streaming apps, etc.) and
      # HomeKit truncates to 90 alphabetically, surfacing garbage like
      # "Bill Perry BMX" in the input picker. This wrapper exposes only the
      # five physical HDMI inputs; the underlying media_player.alexis_tv
      # retains the full source_list for direct use.
      media_player = [
        {
          platform = "universal";
          name = "Alexis TV HomeKit";
          unique_id = "alexis_tv_homekit";
          children = ["media_player.alexis_tv"];
          device_class = "tv";
          attributes = {
            state = "media_player.alexis_tv";
            source = "media_player.alexis_tv|source";
            volume_level = "media_player.alexis_tv|volume_level";
            is_volume_muted = "media_player.alexis_tv|is_volume_muted";
            supported_features = "media_player.alexis_tv|supported_features";
          };
          commands = {
            select_source = {
              action = "media_player.select_source";
              target.entity_id = "media_player.alexis_tv";
              data.source = "{{ source }}";
            };
            turn_on.action = "media_player.turn_on";
            turn_off.action = "media_player.turn_off";
            volume_up.action = "media_player.volume_up";
            volume_down.action = "media_player.volume_down";
            volume_mute = {
              action = "media_player.volume_mute";
              target.entity_id = "media_player.alexis_tv";
              data.is_volume_muted = "{{ is_volume_muted }}";
            };
            volume_set = {
              action = "media_player.volume_set";
              target.entity_id = "media_player.alexis_tv";
              data.volume_level = "{{ volume_level }}";
            };
          };
        }
      ];

      # Override the wrapper's source_list with just the physical HDMI inputs.
      # The universal media_player would otherwise inherit the full 300-source
      # list from its child.
      homeassistant.customize = {
        "media_player.alexis_tv_homekit" = {
          source_list = [
            "HDMI-1"
            "HDMI-2"
            "HDMI-3"
            "HDMI-4"
            "HDMI-5"
          ];
        };
      };

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

      # One target for every push, so adding a device is a one-line change
      # rather than an edit in each automation.
      notify = [
        {
          platform = "group";
          name = "alexis_push";
          services = [
            {service = "mobile_app_alexis_iphone";}
            {service = "mobile_app_ipad_nuevo";}
          ];
        }
      ];

      # Moonraker clears the filename, duration, progress and filament sensors
      # in the same millisecond the print-state sensor changes, so nothing is
      # left to read by the time an end-of-print automation fires. These hold a
      # snapshot taken at print start.
      input_text.centauri_print_file = {
        name = "Centauri Print File";
        max = 255;
      };

      input_datetime.centauri_print_started = {
        name = "Centauri Print Started";
        has_date = true;
        has_time = true;
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

        # Snapshots what the end-of-print notification needs, because Moonraker
        # wipes these sensors the instant a print stops. `not_from` skips
        # resume-from-pause without also skipping a Home Assistant restart
        # mid-print, which arrives as None, unknown or unavailable and would
        # otherwise leave the previous print's details in the helpers.
        {
          alias = "Centauri Carbon → Print Started";
          id = "centauri_print_started";
          mode = "single";
          trigger = [
            {
              platform = "state";
              entity_id = "sensor.centauri_carbon_current_print_state_2";
              not_from = "paused";
              to = "printing";
            }
          ];
          action = [
            # Both reads happen after the delay: Moonraker populates the
            # filename and the duration counter a fraction of a second after
            # the state flips, so reading either immediately returns the
            # previous print's value.
            {delay = "00:00:05";}
            {
              action = "input_datetime.set_datetime";
              target.entity_id = "input_datetime.centauri_print_started";
              # Derived from the duration counter rather than now(), so a Home
              # Assistant restart mid-print recovers the true start instead of
              # restamping to the restart.
              data.datetime = ''
                {{ (now().timestamp() - (states('sensor.centauri_carbon_print_duration_2') | float(0)) * 60)
                   | timestamp_custom('%Y-%m-%d %H:%M:%S', true) }}
              '';
            }
            {
              action = "input_text.set_value";
              target.entity_id = "input_text.centauri_print_file";
              data.value = "{{ states('sensor.centauri_carbon_filename_2') | truncate(255, true, '') }}";
            }
          ];
        }

        # Every pause here is a runout, jam, or MMU error: the Canvas unit
        # means M600 manual filament changes never happen.
        {
          alias = "Centauri Carbon → Print Ended";
          id = "centauri_print_ended";
          mode = "single";
          variables = {
            # Snapshotted at print start; the live sensors are already cleared
            # by the time this automation runs.
            # Unset helpers read "unknown"; say something sensible instead.
            print_file = ''
              {% set f = states('input_text.centauri_print_file') %}
              {% if f and f not in ['unknown', 'unavailable'] %}{{ f }}{% else %}A print{% endif %}
            '';
            # The stamp is derived from Moonraker's duration counter at
            # capture time, so a long mid-print pause still counts toward the
            # elapsed figure. An unset input_datetime reads midnight today
            # rather than epoch, so its timestamp looks perfectly plausible --
            # the filename helper is the honest marker, since it is written in
            # the same run as the stamp.
            print_elapsed = ''
              {% set f = states('input_text.centauri_print_file') %}
              {% set t = state_attr('input_datetime.centauri_print_started', 'timestamp') %}
              {% set s = (now().timestamp() - (t | float(0))) | int %}
              {% if f and f not in ['unknown', 'unavailable'] and t and s > 0 and s < 604800 %}{{ '%dh %dm' | format(s // 3600, (s % 3600) // 60) }}{% else %}an unknown time{% endif %}
            '';
            # Klipper's pause reason. Empty during a normal print, and not
            # observed during a real pause, so never depended on.
            print_reason = "{{ states('sensor.centauri_carbon_current_print_message_2') }}";
            # The wording lives inside the variable on purpose. Home Assistant
            # renders automation variables with parse_result=True, so a bare
            # "3, 4" would come back as a tuple and stringify with brackets.
            canvas_empty = ''
              {% set ns = namespace(slots=[]) %}
              {% for slot in range(1, 5) %}
                {% if is_state('binary_sensor.centauri_carbon_canvas_' ~ slot ~ '_prep_2', 'off') %}
                  {% set ns.slots = ns.slots + [slot | string] %}
                {% endif %}
              {% endfor %}
              {% if ns.slots %}Canvas {{ ns.slots | join(', ') }} empty{% endif %}
            '';
          };
          trigger = [
            {
              platform = "state";
              entity_id = "sensor.centauri_carbon_current_print_state_2";
              to = "complete";
              id = "complete";
            }
            {
              platform = "state";
              entity_id = "sensor.centauri_carbon_current_print_state_2";
              to = "error";
              id = "error";
            }
            {
              platform = "state";
              entity_id = "sensor.centauri_carbon_current_print_state_2";
              to = "cancelled";
              id = "cancelled";
            }
            {
              platform = "state";
              entity_id = "sensor.centauri_carbon_current_print_state_2";
              to = "paused";
              id = "paused";
            }
          ];
          action = [
            {
              choose = [
                {
                  conditions = [
                    {
                      condition = "trigger";
                      id = "complete";
                    }
                  ];
                  sequence = [
                    {
                      action = "notify.alexis_push";
                      data = {
                        title = "Print finished";
                        message = "{{ print_file }} — finished in {{ print_elapsed }}";
                        data.image = "/api/camera_proxy/camera.centauri_webcam";
                      };
                    }
                  ];
                }
                {
                  conditions = [
                    {
                      condition = "trigger";
                      id = "error";
                    }
                  ];
                  sequence = [
                    {
                      action = "notify.alexis_push";
                      data = {
                        title = "Print failed";
                        message = "{{ print_file }} — failed after {{ print_elapsed }}{% if print_reason %} — {{ print_reason }}{% endif %}";
                        data.image = "/api/camera_proxy/camera.centauri_webcam";
                      };
                    }
                  ];
                }
                {
                  conditions = [
                    {
                      condition = "trigger";
                      id = "cancelled";
                    }
                  ];
                  sequence = [
                    {
                      action = "notify.alexis_push";
                      data = {
                        title = "Print cancelled";
                        message = "{{ print_file }} — cancelled after {{ print_elapsed }}";
                        data.image = "/api/camera_proxy/camera.centauri_webcam";
                      };
                    }
                  ];
                }
                {
                  conditions = [
                    {
                      condition = "trigger";
                      id = "paused";
                    }
                  ];
                  sequence = [
                    {
                      action = "notify.alexis_push";
                      data = {
                        title = "Print paused";
                        message = "{{ print_file }} — paused after {{ print_elapsed }}{% if canvas_empty %} — {{ canvas_empty }}{% endif %}{% if print_reason %} — {{ print_reason }}{% endif %}";
                        data.image = "/api/camera_proxy/camera.centauri_webcam";
                      };
                    }
                  ];
                }
              ];
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

  # HomeKit accessories listen on TCP ports starting at 21063, with each
  # additional bridge/accessory taking the next sequential port. Opening a
  # generous range here means new HomeKit entries pair without firewall
  # changes. mDNS discovery uses UDP 5353, which avahi already opens.
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 21063;
      to = 21149;
    }
  ];
}
