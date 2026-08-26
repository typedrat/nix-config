# PrintGuard: self-hosted print failure detection on iserlohn

Date: 2026-08-26
Status: approved, not yet implemented

## Summary

Run [PrintGuard](https://github.com/oliverbravery/PrintGuard) on iserlohn to watch the
Elegoo Centauri Carbon for print failures, pause or cancel on a sustained defect, and
surface everything through the Home Assistant instance already running on the same host.
Alongside it, add Home Assistant notifications for normal print lifecycle events.

Two new packages, one NixOS module, one notify group, two automations.

## Why not Obico

The original ask was for a self-hosted Obico server. It was designed in full and rejected
for three reasons, recorded here so the decision is not relitigated:

1. **Mobile push is structurally impossible when self-hosting.** `backend/lib/mobile_notifications.py`
   sends through `firebase_admin`, and device tokens are minted by Obico's own Firebase
   project. A different sender is rejected — the code catches `SenderIdMismatchError` and
   deactivates the device row. Rebuilding the app against another Firebase project is not
   an option either: the mobile app source is not public. Obico's own comparison page
   confirms self-hosted push needs an Apple developer account, i.e. your own app build.
2. **The packaging cost was disproportionate.** Obico pins Django 4.0.10 with ~140 exact
   dependencies, ten of which are absent from nixpkgs plus a git fork of
   `django-channels-presence`. nixpkgs ships only Django 5.2 and 6.0, so the options were
   a uv2nix lock against an EOL Django or porting across two major Django versions and a
   major `django-allauth` rewrite.
3. **It duplicated infrastructure that already exists here.** Webcam viewing (go2rtc),
   remote access (Traefik), print status (the Moonraker HA integration) and notifications
   (HA companion app) are all already running. The only thing Obico added was the detector.

PrintGuard supplies the detector, has native Elegoo support, and publishes into Home
Assistant over MQTT, which is where the rest of the house already lives.

## Goals

- Detect print failures on the Centauri Carbon and pause or cancel the print.
- Every monitor visible in Home Assistant with its score, snapshot and controls.
- Notifications for failures and for normal print end, reaching a phone.
- Fully declarative: packages in `packages/`, service in `modules/nixos/services/home/`,
  automations in `systems/iserlohn/home-assistant.nix`.

## Non-goals

- Print history and timelapse galleries. Moonraker and HA already track prints.
- Obico compatibility of any kind. The agent, the account system and the tunnel are gone.
- GPU inference. See "Inference runtime" below.

## Packages

### `packages/pycentauri/`

`buildPythonPackage` from `brandonrthomas/pycentauri`, the Elegoo Centauri Carbon client
PrintGuard uses to talk to the printer. Dependencies are `httpx`, `paho-mqtt`, `pydantic`,
`typer`, `typing-extensions` and `websockets`, all present in nixpkgs. Needs
`passthru.updateScript` per repository convention.

### `packages/printguard/`

`buildPythonApplication` (hatchling) at v2.4.0.

- **Frontend**: `web/` is a Vite/TypeScript app and `dist` is not committed, so it needs a
  `buildNpmPackage` sub-derivation installed to `$out/share/printguard/web`, exposed to the
  service as `STATIC_DIR`. This mirrors `packages/dispatcharr`, which already carries a
  `buildNpmPackage` frontend with an `npmDepsHash`.
- **Model**: `models/` is committed upstream (5MB ONNX, 5MB TFLite, `prototypes.json`,
  `metadata.json`). Copy to `$out/share/printguard/models` and point `MODEL_DIR` at it. No
  `fetchurl`, no network at build time.
- **Plugin sandbox**: `printguard/server/runtime/qjs.wasm` must survive into the output;
  `printguard/server/plugins.py` loads it through `wasmtime` at import.
- **Python**: upstream requires `>=3.12`. nixpkgs' `python3` is currently **3.14**; try the
  default first and pin `python312`/`python313` only if `ai-edge-litert` or `wasmtime` fail
  to build or import there.

Every remaining dependency — `ai-edge-litert`, `pyprusalink`, `fastmcp`, `aiomqtt`,
`paho-mqtt`, `pydantic-settings`, `av`, `ml-dtypes`, `uvicorn`, `fastapi`, `starlette`,
`httpx`, `onnxruntime`, `numpy` — is already in nixpkgs. `pycentauri` is the only gap.

### Inference runtime

`printguard/server/inference.py` defaults to `runtime = "litert"`, running the model through
`ai_edge_litert`. ONNX Runtime is the alternative, and `onnxruntime_ep_openvino` /
`onnxruntime_ep_nv_tensorrt_rtx` are optional plugin execution providers loaded
opportunistically.

Leave it on the LiteRT default and do **not** wire up GPU inference. iserlohn's
`hardware.nvidia.cuda.enable = true` sets `nixpkgs.config.cudaSupport` globally, but the
default CUDA capability set on CUDA 12.9 evaluates to
`["7.5" "8.0" "8.6" "8.9" "9.0" "10.0" "10.3" "12.0" "12.1"]`. The Quadro P1000 is Pascal
(6.1) and is not in it, and `cudaForwardCompat` only JITs PTX forward to newer GPUs. Making
the P1000 usable would mean `cudaCapabilities = ["6.1"]` and a from-source onnxruntime
rebuild on every nixpkgs bump, to accelerate roughly one inference per second.

## NixOS module

`modules/nixos/services/home/printguard.nix`, added to that directory's `default.nix`
imports, exposing `rat.services.printguard`.

### Ports

Allocate through the `links` module rather than hardcoding:

| link | purpose |
|---|---|
| `printguard` | hub HTTP (`PORT`) |
| `printguard-mediamtx-api` | MediaMTX control API (`MEDIAMTX_API`) |
| `printguard-mediamtx-rtsp` | MediaMTX RTSP (`MEDIAMTX_RTSP`) |
| `printguard-mediamtx-hls` | MediaMTX HLS (`MEDIAMTX_HLS`) |

MediaMTX defaults to RTSP on 8554 and **would collide with go2rtc**, which is why these go
through `links` instead of taking upstream defaults.

### Environment

- `MEDIAMTX_BINARY` = `lib.getExe pkgs.mediamtx`, `MEDIAMTX_CONFIG` = a generated config in
  the state directory. MediaMTX is not optional: `ServerPlatform` always constructs a
  client and republishes every camera through it.
- `MODEL_DIR`, `STATIC_DIR` = store paths from the package.
- `DATA_DIR` = `/var/lib/printguard`, holding `state.json`.
- `PRINTGUARD_ORIGINS` = the Traefik origin.

### Traefik

`rat.services.traefik.routes.printguard` with `authentik = true`. Unlike the Obico design
there is no unauthenticated machine traffic to accommodate — Home Assistant talks to
PrintGuard over MQTT, not HTTP. Expose `authentik` as a module option, because forward-auth
will block the scoped-token REST/MCP API if that is ever wanted.

### Persistence

Persist `/var/lib/printguard` under `environment.persistence`, landing on `rpool/safe/persist`
which is snapshotted and already inside the backup story.

### What the module does not configure

Cameras, printers, monitors and the MQTT broker address are configured through PrintGuard's
web UI and stored in `state.json`. They are not environment-driven. The module declares the
service and its plumbing; the monitor definitions are runtime state. This is a limitation of
upstream, not an oversight in the module.

### Camera source

Point PrintGuard at the existing go2rtc `centauri_webcam` RTSP stream rather than at the
printer directly. go2rtc already repairs the camera's untimestamped MJPEG via the `mjpegin`
template and re-encodes to H.264, so PrintGuard inherits that fix, and the printer — 128MB
of RAM and a single armv7l core — keeps serving exactly one client.

## Home Assistant integration

### Notify group

Add to `systems/iserlohn/home-assistant.nix`:

```nix
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
```

Automations target `notify.alexis_push` so adding a device is a one-line change rather than
edits scattered across automations.

The phone is listed first so it is the primary target; the iPad tags along. Both service
names are confirmed present in the running instance.

### Print lifecycle automation

One entry in the existing `automation = [...]` block, matching that file's
`trigger`/`condition`/`action` idiom.

`sensor.centauri_carbon_current_print_state_2` is an `enum` sensor whose options are exactly
`["standby" "printing" "paused" "complete" "cancelled" "error"]`, so the `to:` values are
validated rather than guessed.

- `mode = "single"` — one-shot notifications.
- Four triggers, each with an `id`, dispatched by a `choose` on `condition: trigger`:
  - `complete` → "Print finished"
  - `error` → "Print failed"
  - `cancelled` → "Print cancelled" — this doubles as confirmation when PrintGuard
    auto-cancels on a sustained defect
  - `paused` → "Print paused" — catches filament runout and PrintGuard's pause action, but
    will also fire on every manual pause and on `M600` filament changes
- Top-level `variables:` capture the sensor values once so all four branches read a
  consistent snapshot.
- Each notification attaches a still via `data.image = "/api/camera_proxy/camera.centauri_webcam"`.

Units, confirmed against the live entities: `sensor.centauri_carbon_print_duration_2` is in
**minutes** (format as `Xh Ym`), `sensor.centauri_carbon_filament_used_2` is in **metres**,
`sensor.centauri_carbon_progress_2` is a **percentage**.

Templates appear only in `variables:` and in notification `message`/`title`/`data` fields,
which is where the Home Assistant best-practice guidance permits them.

**Caveat:** Moonraker holds `print_duration` and `filament_used` after `complete` but resets
them when the next print starts. The notification is accurate when sent; the sensors are not
a historical record.

### PrintGuard alert automation

Once PrintGuard is running and MQTT discovery has populated its entities, add a second
automation triggering on the discovered defect sensor and notifying `notify.alexis_push`
with the snapshot. The exact entity IDs are not knowable until the service runs and the
monitor is created, so this is specified but not written in the same pass.

## Verification plan

Staged, because this is a large change and a rebuild is the slowest way to find a typo:

1. `nix build .#pycentauri`
2. `nix build .#printguard` — includes the npm frontend, the slowest step
3. `nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel`
4. Deploy, then `curl` the hub's health endpoint on its `links` port
5. Confirm MediaMTX came up on its allocated RTSP port and did **not** collide with go2rtc
6. Register the printer and a monitor against the go2rtc RTSP stream in the web UI
7. Confirm MQTT discovery created the HA entities
8. Trigger the print lifecycle automation manually, then confirm on a real print end

New files must be `git add`ed before they evaluate at all — untracked files are invisible to
flake evaluation, which presents as a module or package simply not existing.

## Risks

- **Single-maintainer upstream.** PrintGuard is ~316 stars with one maintainer, against
  Obico's ~1,900 and a company. Expect more API churn. Mitigated by the small surface area:
  two packages and one module.
- **Detector quality is self-reported.** The 93.6%-vs-53.8% accuracy comparison against
  Obico's Spaghetti Detective is the author's own benchmark, backed by their dissertation
  but not independently replicated. Treat the direction as credible and the margin as
  unverified.
- **`state.json` is the source of truth for monitors.** Losing it loses the configuration.
  It is persisted and snapshotted, but it is not declarative.
- **Paused notifications may be noisy** if `M600` filament changes are common. Easy to drop
  that branch later.
