---
name: coolercontrol-api
description: Use when configuring fan curves, creating profiles, assigning profiles to fans, or querying device sensors via the CoolerControl daemon REST API. Use when the user asks to control fans, pumps, or cooling based on temperature sensors.
---

# CoolerControl REST API

## Overview

CoolerControl exposes a REST API on `https://127.0.0.1:11987` for controlling fans, pumps, LCD screens, and lighting on detected hardware. The daemon uses self-signed TLS by default, so always use `-k` / `verify=False` with curl/requests.

## Authentication

The API requires auth. Two methods:

| Method | Use case | Header |
|--------|----------|--------|
| Bearer token | Scripts, API calls | `Authorization: Bearer cc_<token>` |
| Session cookie | Interactive (login first) | `POST /login` with basic auth `CCAdmin:<password>` |

Create bearer tokens in the CoolerControl UI under Settings > Access Protection > Access Tokens.

```bash
AUTH="Authorization: Bearer cc_<your_token>"
BASE="https://127.0.0.1:11987"
```

## Quick Reference

| Action | Method | Endpoint |
|--------|--------|----------|
| List devices | GET | `/devices` |
| Device status (temps, RPMs) | GET | `/status` |
| List profiles | GET | `/profiles` |
| Create profile | POST | `/profiles` |
| Update profile | PUT | `/profiles` |
| Delete profile | DELETE | `/profiles/{profile_uid}` |
| List functions | GET | `/functions` |
| Create function | POST | `/functions` |
| Update function | PUT | `/functions` |
| Delete function | DELETE | `/functions/{function_uid}` |
| Get device settings | GET | `/settings/devices/{device_uid}` |
| Update device settings | PUT | `/settings/devices/{device_uid}` |
| Set manual fan speed | PUT | `/devices/{device_uid}/settings/{channel}/manual` |
| Assign profile to channel | PUT | `/devices/{device_uid}/settings/{channel}/profile` |
| Reset channel to default | PUT | `/devices/{device_uid}/settings/{channel}/reset` |
| List modes | GET | `/modes` |
| Activate mode | POST | `/modes-active/{mode_uid}` |

## Workflow: Fan Curve Based on Sensor

### 1. Discover devices and identify UIDs

```bash
curl -sk -H "$AUTH" $BASE/devices | jq '.devices[] | {name, type, uid, temps: .info.temps, channels: (.info.channels | keys)}'
```

Key fields per device:
- `uid` -- unique device identifier (used in all endpoints)
- `info.temps` -- available temperature sensors (keyed by `temp1`, `temp2`, etc.)
- `info.channels` -- controllable outputs (fans, pumps, LEDs, LCDs)
- `info.channels.<name>.speed_options` -- if present, the channel is controllable

### 2. Check current temps and fan RPMs

```bash
curl -sk -H "$AUTH" $BASE/status | jq '.devices[] | select(.uid == "<device_uid>") | .status_history[0]'
```

Each status entry has `.temps[]` (name + temp) and `.channels[]` (name + rpm + duty).

### 3. Create a function (controls smoothing/hysteresis)

```bash
curl -sk -X POST -H "$AUTH" -H "Content-Type: application/json" $BASE/functions -d '{
  "uid": "<uuid>",
  "name": "My Function",
  "f_type": "Standard",
  "duty_minimum": 1,
  "duty_maximum": 100,
  "step_size_min_decreasing": 2,
  "step_size_max_decreasing": 5,
  "response_delay": 3,
  "deviance": 5.0,
  "only_downward": false,
  "sample_window": 6,
  "threshold_hopping": true
}'
```

| Field | Purpose |
|-------|---------|
| `duty_minimum` | Minimum duty % (must be >= 1) |
| `duty_maximum` | Maximum duty % |
| `deviance` | Hysteresis in degrees C (fan won't ramp down until temp drops this far below the curve point) |
| `response_delay` | Seconds before reacting to temp changes |
| `sample_window` | Seconds of temp data to average |
| `step_size_min/max_decreasing` | How fast duty ramps down (% per step) |
| `threshold_hopping` | Snap to nearest curve point instead of interpolating on thresholds |
| `f_type` | `"Identity"` (passthrough) or `"Standard"` (with smoothing) |

### 4. Create a graph profile (fan curve)

```bash
curl -sk -X POST -H "$AUTH" -H "Content-Type: application/json" $BASE/profiles -d '{
  "uid": "<uuid>",
  "p_type": "Graph",
  "name": "My Fan Curve",
  "speed_fixed": null,
  "speed_profile": [
    [35, 0],
    [45, 0],
    [50, 30],
    [60, 50],
    [70, 75],
    [80, 100]
  ],
  "temp_source": {
    "device_uid": "<temp_sensor_device_uid>",
    "temp_name": "temp1"
  },
  "temp_min": 35,
  "temp_max": 80,
  "function_uid": "<function_uid_from_step_3>",
  "member_profile_uids": [],
  "mix_function_type": null,
  "offset_profile": null
}'
```

- `speed_profile` -- array of `[temp_celsius, duty_percent]` pairs
- `temp_source.device_uid` -- UID of the device providing the temperature
- `temp_source.temp_name` -- sensor key (e.g. `temp1` for Composite on NVMe)
- `temp_min` / `temp_max` -- must match the range of your speed_profile
- `function_uid` -- the function UID from step 3

### 5. Assign the profile to a fan channel

This is the step that actually makes the fan respond to the profile:

```bash
curl -sk -X PUT -H "$AUTH" -H "Content-Type: application/json" \
  $BASE/devices/<fan_device_uid>/settings/<channel_name>/profile \
  -d '{"profile_uid": "<profile_uid_from_step_4>"}'
```

**Important:** The `/settings/devices/{uid}` endpoint (for labels/disable) does NOT assign profiles. You must use `/devices/{uid}/settings/{channel}/profile`.

### 6. Verify

```bash
curl -sk -H "$AUTH" $BASE/status | jq '.devices[] | select(.uid == "<fan_device_uid>") | .status_history[0].channels[] | select(.name == "<channel_name>")'
```

Check that `duty` changed to match your curve for the current temp.

## Profile Types

| Type | `p_type` | Required fields |
|------|----------|----------------|
| Default (reset) | `"Default"` | none |
| Fixed speed | `"Fixed"` | `speed_fixed` (integer 0-100) |
| Graph (fan curve) | `"Graph"` | `speed_profile`, `temp_source`, `function_uid` |
| Mix (combine profiles) | `"Mix"` | `member_profile_uids`, `mix_function_type` |
| Overlay | `"Overlay"` | `member_profile_uids`, `offset_profile` |

## Other Useful Endpoints

**Set manual speed (no profile):**
```bash
curl -sk -X PUT -H "$AUTH" -H "Content-Type: application/json" \
  $BASE/devices/<uid>/settings/<channel>/manual \
  -d '{"speed_fixed": 50}'
```

**Reset channel to default:**
```bash
curl -sk -X PUT -H "$AUTH" -H "Content-Type: application/json" \
  $BASE/devices/<uid>/settings/<channel>/reset -d '{}'
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `duty_minimum: 0` | Must be >= 1, API rejects 0 |
| Using `/settings/devices/{uid}` to assign profiles | Use `/devices/{uid}/settings/{channel}/profile` instead |
| Profile created before function | Create the function first, profile references it by UID |
| Missing `temp_source` on Graph profile | Required: both `device_uid` and `temp_name` |
| Wrong field name `disable` vs `disabled` | Channel settings use `disabled` (with d) |

## Known Issues

Qt WebEngine 6.10.2 hangs on NVIDIA with open kernel modules (NixOS/nixpkgs#508998). The CoolerControl GUI won't launch. Workaround: `QTWEBENGINE_FORCE_USE_GBM=1`. The daemon and REST API are unaffected.
