# GratKit Firefly V2 Lovelace Card — Design

**Goal:** Replace the missing `custom:gratkit-firefly-card` on the `3d-printing`
dashboard with a real, declaratively packaged custom card that shows the
filament dryer's state, plots its temperature and humidity history, and exposes
every control on one surface.

## Background

The `3d-printing` dashboard has rendered blank since it was created on
2026-04-04. It contains exactly one card, `custom:gratkit-firefly-card`, backed
by a hand-registered resource pointing at
`/local/nixos-lovelace-modules/gratkit-firefly-card.js`. That path is what the
nixpkgs Home Assistant module generates from `customLovelaceModules`, but this
repository has never populated that option, so the directory was never created
and the URL returns 404. The browser reports *"Custom element doesn't exist"*
and the view renders nothing.

The card is also not obtainable: it is absent from nixpkgs'
`custom-lovelace-modules`, HACS is not installed on this instance, and GitHub
repository search, GitHub code search, and web search all return zero results
for the name. It has to be written.

The underlying entities are healthy. All 13 come from localtuya and have been
reporting continuously for six months.

### Device model

The dryer is a Tuya device (protocol 3.5) on the LAN. Its datapoints, and how
localtuya exposes them, are the constraints the card designs around:

| DP  | Tuya code       | Entity                                        | Notes |
|-----|-----------------|-----------------------------------------------|-------|
| 1   | `switch`        | `fan.gratkit_firefly_v2_fan`                  | Device **power**, not a fan — exposed on the fan platform, so on/off only (`supported_features: 48`) |
| 20  | `temp_set`      | `number.…_temperature`                        | Setpoint, 40–70 °C, step 1 |
| 21  | `temp_current`  | `sensor.…_current_temperature`                | Chamber temperature |
| 101 | `countdown`     | `number.…_timer`                              | **Minutes** remaining, 0–1440 — mislabelled `unit_of_measurement: "s"` |
| 102 | `humidity`      | `sensor.…_current_humidity`                   | Chamber relative humidity |
| 103 | `ledlight`      | `select.…_light`                              | 21 options: `0` off, `1`–`9` named colours, `10`–`12` rainbow effects, `13`–`20` unnamed |
| 104 | `heat_wd`       | `sensor.…_heating_temperature`                | Heater element, not the chamber |
| 105 | `material_type` | `select.…_material_type`                      | ABS, DIY1, DIY2, HIPS, Nylon, PC, PETG, PLA, PLA_J, TPU |
| 106 | `erro`          | `binary_sensor.…_error`                       | Error **code**; localtuya's `state_on: "1"` matches only code 1 |
| 107 | `pvrpm`         | `sensor.…_fan_speed`                          | rpm |
| 108 | `usb_bz`        | `binary_sensor.…_usb`                         | Reports only whether something is plugged into the USB port — unused by the card |
| 109 | `speek`         | `switch.…_sound`                              | Buzzer |
| 110 | `lcd_onof`      | `switch.…_lcd`                                | Front panel display |

### Observed behaviour

Seven days of recorder history establish how the device is actually used, which
drove the layout:

- **It runs continuously.** The power entity has been `on` for the whole window;
  its only other state is `unavailable` during Home Assistant restarts. The
  timer has been `0.0` throughout — nobody uses the countdown.
- **`heating_temperature` is noise.** 101,876 state changes in 7 days, roughly
  one every 6 seconds, oscillating 85–89 °C as the element's control loop hunts.
  It is a diagnostic, not a headline, and must not be graphed.
- **Humidity is the interesting signal.** Monthly statistics since February show
  it swinging between 1% and 50% — each spool load spikes it and it decays as
  the dryer works. The chamber went from 48% at pairing to 10% now. Nothing in
  Home Assistant currently surfaces that.

## Architecture

Three files and one deploy.

```
packages/gratkit-firefly-card/
  gratkit-firefly-card.js     the card — vanilla ES module
  package.nix                 stdenvNoCC derivation, copies the .js to $out/
systems/iserlohn/home-assistant.nix
  + rat.services.home-assistant.customLovelaceModules = [pkgs.gratkit-firefly-card];
```

The card is a plain `HTMLElement` custom element using shadow DOM, with no build
step. It was chosen over a Lit/Rollup `buildNpmPackage` because there is no
upstream to track: a lockfile and an `npmDepsHash` would have to be re-pinned on
every edit of a file that only this repository will ever ship. The Nix
derivation is a copy.

The card builds its DOM **once**, then each `set hass(…)` mutates cached node
references rather than re-rendering. A full re-render on every state update
would destroy and refetch the graph several times a minute.

The only Home Assistant internals it depends on are `<ha-card>`, for correct
theming and elevation, and the `hass-more-info` event. Everything else is its
own markup styled through Home Assistant's CSS custom properties
(`--primary-text-color`, `--secondary-text-color`, `--divider-color`,
`--ha-card-background`, …), so the Catppuccin theme this host applies is picked
up without special-casing.

### Interaction with the nixpkgs module

Setting `customLovelaceModules` to a non-empty list makes the nixpkgs module do
three things at once:

1. symlink a `buildEnv` of the packages into `<configDir>/www/nixos-lovelace-modules`
2. inject `lovelace.resources` into `configuration.yaml`, with the URL
   cache-busted as `…/gratkit-firefly-card.js?<version>`
3. default `lovelace.resource_mode` to `"yaml"`

Consequence (3) is load-bearing. Once `resource_mode` is `yaml`, Home Assistant
loads resources from YAML and ignores `.storage/lovelace_resources` entirely,
and the resource-management websocket API disappears — `ResourceYAMLCollection`
registers no create/update/delete handlers. **The stale hand-registered resource
must therefore be deleted before the rebuild, not after.**

One merge hazard was checked and is clear: `filteredConfig` computes
`recursiveUpdate (customLovelaceModulesResources // themesConfig) (cfg.config)`,
and the second argument wins on conflict, so an explicit `lovelace.resources`
anywhere in this repository would silently swallow the generated list. This
repository sets no `lovelace` config at all — the effective value is
`{dashboards, resource_mode}` — so the merge yields all three keys cleanly.

## Card configuration

The dashboard's existing config already uses key names like `fan`,
`current_temp` and `heating_temp`. The card keeps those exact names so the
existing config survives with minimal churn.

```yaml
type: custom:gratkit-firefly-card
name: GratKit Firefly V2                                # optional, defaults to the fan entity's friendly name
fan: fan.gratkit_firefly_v2_fan
current_temp: sensor.gratkit_firefly_v2_current_temperature
target_temp: number.gratkit_firefly_v2_temperature
humidity: sensor.gratkit_firefly_v2_current_humidity
heating_temp: sensor.gratkit_firefly_v2_heating_temperature
fan_speed: sensor.gratkit_firefly_v2_fan_speed
timer: number.gratkit_firefly_v2_timer
material: select.gratkit_firefly_v2_material_type
light: select.gratkit_firefly_v2_light
error: binary_sensor.gratkit_firefly_v2_error
sound: switch.gratkit_firefly_v2_sound
lcd: switch.gratkit_firefly_v2_lcd
hours: 24
humidity_max: 60
```

Two keys are new: `hours` (graph window) and `humidity_max` (humidity gauge
ceiling). One is corrected: `error` pointed at `sensor.…_error`, which does not
exist — the entity is a `binary_sensor`.

`binary_sensor.…_usb` is deliberately not wired up. It only reports whether
something is plugged into the dryer's USB port, which carries no information
about drying, so it earns no space on the card.

Every entity key is optional. An unset key, or one naming an entity that is not
in `hass.states`, renders that control disabled showing an em dash. `setConfig`
throws only when the config names no entities at all.

## Layout

A single `ha-card`, in four stacked bands:

1. **Header** — device name, a status line (`Drying · PETG`), and a health pill
   on the right that reads `OK`, the error code, or `Off`.
2. **Gauges** — two 270°-sweep SVG radial gauges side by side. Chamber
   temperature is scaled to the target number entity's own `min`/`max`
   attributes (40–70 °C), footed with the current target; humidity is scaled
   `0`–`humidity_max`, footed with the highest value over the graph window,
   taken from the statistics already fetched for the graph (`peak 14%`). That
   makes the decay visible at a glance without the card having to infer when a
   spool was loaded.
3. **Graph** — the temperature and humidity history band, described below.
4. **Diagnostics strip** — one muted line between the graph and the controls,
   carrying the values that are real but not headline material:
   `Heater 87 °C · Fan 5040 rpm`. This is where `heating_temp` and `fan_speed`
   live; each segment is omitted when its key is unset.
5. **Controls** — a material dropdown, a temperature stepper and a timer
   stepper, then a chip row for power, light, LCD and sound.

## The graph

Data comes from `recorder/statistics_during_period` over the websocket, not from
raw history. Three reasons:

- Raw history is expensive here — the sensors on this device write tens of
  thousands of rows per week.
- Raw states purge at roughly 10 days; statistics are retained permanently, so
  the long humidity decay stays visible.
- Both sensors carry `state_class: measurement`, so 5-minute and hourly
  aggregates already exist going back to February 2026.

The period is `5minute` for windows of 12 hours or less and `hour` beyond that.
Data is fetched when `hass` is first set and refreshed every 5 minutes on an
interval registered in `connectedCallback` and cleared in
`disconnectedCallback`.

Two series are plotted on one grid with independent scales: temperature in amber
against the target entity's `min`/`max`, humidity in blue against
`0`–`humidity_max` with a gradient area fill beneath it. `heating_temp` is
deliberately excluded.

If the statistics call rejects, or returns no points for both series, the graph
band is replaced by a muted one-line message and the rest of the card continues
to work.

## Corrections the card makes

The card presents three things correctly that the entities get wrong, without
modifying the localtuya configuration:

- **Timer.** DP 101 is `countdown`, in minutes, but localtuya declares
  `unit_of_measurement: "s"`. The card renders it as `Off` or `2 h 30 m` and
  steps it in 30-minute increments up to 1440.
- **Error.** DP 106 carries an error *code*, and localtuya's `state_on: "1"`
  means any code other than `1` reads as `off` — a fault the dashboard would
  never show. The card reads the `raw_state` attribute and treats any value that
  is not `0` or `false` as a fault, falling back to `state` when the attribute
  is absent.
- **Light.** The select offers 21 options, eight of which are bare numbers
  (`"13"`–`"20"`) with no known meaning. The card renders the nine named colours
  as actual colour swatches plus the three rainbow effects and Off; the unnamed
  values are hidden from the picker but still display correctly when the device
  is already set to one.

## Controls and service calls

| Control | Action |
|---------|--------|
| Power chip | `fan.toggle` |
| Temperature stepper | `number.set_value`, clamped to the entity's `min`/`max`, step 1 |
| Timer stepper | `number.set_value`, 30-minute steps, 0–1440 |
| Material dropdown | `select.select_option` |
| Light picker | `select.select_option` |
| LCD, Sound chips | `switch.toggle` |
| Title, gauges | `hass-more-info` event |

Both steppers debounce for 400 ms before issuing `number.set_value`, so holding
a button does not flood the device's Tuya socket with writes.

## Error handling

- Unknown or unconfigured entity: the control renders disabled with an em dash.
- Entity in `unavailable` or `unknown`: the control dims and shows an em dash;
  the card does not throw.
- Statistics failure: graph band shows a muted message, card stays functional.
- `setConfig` with no entity keys at all: throws, which Lovelace renders as a
  card configuration error.

## Verification

No JavaScript test framework exists in this repository, so verification is
behavioural and ordered:

1. `node --check` on the module for syntax.
2. `nix build .#gratkit-firefly-card`; assert `$out/gratkit-firefly-card.js` exists.
3. `nix build` the iserlohn `system.build.toplevel`.
4. **Delete the stale storage resource over the websocket, before deploying** —
   after the rebuild, `resource_mode` is `yaml` and the API is gone.
5. Deploy, then assert `configuration.yaml` contains the generated `resources:`
   entry and `resource_mode: yaml`, and that the resource URL returns 200. It
   currently returns 404, which makes this the regression test for the original
   fault.
6. Update the `3d-printing` dashboard config through the config API, then load
   the dashboard in a browser and screenshot it to confirm the card draws, the
   gauges read plausible values, and the graph has data.

Step 6 is not optional. Every defect in the preceding PrintGuard work on this
host — a startup crash-loop, a service that could never start, wrong MQTT ACLs,
a `KeyError` on restore — surfaced only from running the artifact. `nix build`
succeeded in every one of those cases.

## Out of scope

- Rewriting the localtuya entity definitions to fix the timer unit or widen the
  error sensor. The card compensates for both; changing the config entry risks
  the entity registry and is unrelated to the dashboard fault.
- A visual editor (`getConfigElement`). The card is configured once, for one
  device, in a file.
- Reducing `heating_temperature`'s recorder volume. It is worth doing — roughly
  100k rows a week for a diagnostic nobody reads — but it is a recorder policy
  change, not a dashboard change.
- The dangling `ui-lovelace.yaml` symlink in the Home Assistant config directory,
  which points at a file that no longer exists. Harmless while `mode` is
  `storage`, and unrelated.
