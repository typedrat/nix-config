# PrintGuard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run PrintGuard on iserlohn to detect Centauri Carbon print failures, and notify through Home Assistant on both failures and normal print lifecycle events.

**Architecture:** Two nixpkgs-native Python packages (`pycentauri`, `printguard`) discovered by the repo's `local-packages` module, one NixOS module under `rat.services.printguard` that runs the hub plus a supervised MediaMTX, and declarative Home Assistant config for the notify group and print lifecycle automation.

**Tech Stack:** Nix (flake-parts), `buildPythonApplication` + `buildNpmPackage`, systemd, Traefik, Mosquitto, sops-nix, Home Assistant.

Spec: `docs/superpowers/specs/2026-08-26-printguard-design.md`

## Global Constraints

- Target host is **iserlohn** only. Do not touch hyperion or ulysses.
- **New files are invisible to flake evaluation until `git add`ed.** Every task that creates a file must `git add` it before running any `nix build` or `nix eval`. A missing `git add` presents as "attribute does not exist", not as a file error.
- Run `nix fmt` before every commit. treefmt runs alejandra, deadnix and statix; unformatted Nix fails CI.
- Custom options live under the `rat.*` namespace.
- Packages live at `packages/<name>/package.nix` and are auto-discovered as `.#<name>`.
- Every package sets `passthru.updateScript`. Use `nix-update-script {extraArgs = ["--flake"];}` — without `--flake`, nix-update resolves the file to its store path and fails to diff it.
- Ports come from the `links` module (`config.links.<name>.{port,portStr,tuple,url,ipv4}`). Never hardcode a port.
- Verified upstream versions: `pycentauri` **0.9.1**, `printguard` **2.4.0**.
- Verified hashes (prefetched 2026-08-26): pycentauri src `sha256-kO3CMMHsElQBkL7zm/Z5l4eOVef1Mbs7bf0AS1lVw6E=`, printguard src `sha256-Wm/tzjm96SMUA860YzaFqXHOpZzOB/6LVa6eO35OApg=`, printguard npm deps `sha256-Fyd64kSJ8g+R2WVBYUr0wTk0EZoP3sERM+yf8b7J90Y=`. If a hash mismatches, Nix prints the correct one in the error — use that value.

### A note on testing

This is Nix packaging; there is no pytest suite to drive. The test cycle for each
task is: run the build/eval command **before** writing the file and confirm it
fails with a specific message, write the file, run the command again and confirm
it succeeds. Inside the derivations, `pythonImportsCheck` is the real assertion —
it imports the module in the built environment and fails the build if anything is
missing at runtime. Treat a passing `pythonImportsCheck` as the unit test.

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/pycentauri/package.nix` | Elegoo Centauri Carbon client library |
| `packages/printguard/package.nix` | PrintGuard hub: Python app + Vite frontend + model files |
| `modules/nixos/services/home/printguard.nix` | `rat.services.printguard` — systemd unit, MediaMTX config, links, Traefik, persistence |
| `modules/nixos/services/home/default.nix` | Add the new module to the imports list |
| `systems/iserlohn/home-assistant.nix` | Enable the service, MQTT user, notify group, print lifecycle automation |
| `secrets/printguard.yaml` | sops-encrypted MQTT password |

---

### Task 1: `pycentauri` package

**Files:**
- Create: `packages/pycentauri/package.nix`

**Interfaces:**
- Consumes: nothing.
- Produces: `pkgs.pycentauri`, a Python module named `pycentauri`, consumed by Task 2's `dependencies` list.

- [ ] **Step 1: Confirm the attribute does not yet exist**

Run: `nix build .#pycentauri 2>&1 | tail -3`
Expected: an error containing `does not provide attribute` (or `attribute 'pycentauri' missing`).

- [ ] **Step 2: Write the package**

Create `packages/pycentauri/package.nix`:

```nix
{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "pycentauri";
  version = "0.9.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "brandonrthomas";
    repo = "pycentauri";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kO3CMMHsElQBkL7zm/Z5l4eOVef1Mbs7bf0AS1lVw6E=";
  };

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    httpx
    paho-mqtt
    pydantic
    typer
    typing-extensions
    websockets
  ];

  pythonImportsCheck = [
    "pycentauri"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Local-network client for Elegoo Centauri Carbon 3D printers";
    homepage = "https://github.com/brandonrthomas/pycentauri";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
})
```

- [ ] **Step 3: Stage the file so the flake can see it**

```bash
git add packages/pycentauri/package.nix
```

- [ ] **Step 4: Build and verify the import check passes**

Run: `nix build .#pycentauri -L 2>&1 | tail -20`
Expected: build succeeds and a `./result` symlink appears. The `pythonImportsCheck` phase prints `Checking whether the following imports work: pycentauri` and does not error.

If it fails with a hash mismatch, replace the `hash` value with the `got:` value Nix prints.

- [ ] **Step 5: Format and commit**

```bash
nix fmt
git add packages/pycentauri/package.nix
git commit -m "Add pycentauri package

Elegoo Centauri Carbon client library, needed by PrintGuard to talk to
the printer."
```

---

### Task 2: `printguard` package

**Files:**
- Create: `packages/printguard/package.nix`

**Interfaces:**
- Consumes: `pkgs.pycentauri` from Task 1.
- Produces: `pkgs.printguard` with `meta.mainProgram = "printguard"` (so `lib.getExe` works in Task 3), `$out/share/printguard/models`, and `$out/share/printguard/web`. Task 3 references all three.

**Background the implementer needs:**

- The frontend at `web/` is a Vite app and `dist` is **not** committed, so it needs a `buildNpmPackage` sub-derivation. `packages/dispatcharr/package.nix` is the existing example of this pattern in this repo.
- `models/` (5MB ONNX + TFLite + `prototypes.json` + `metadata.json`) is committed upstream, but `[tool.hatch.build.targets.wheel] packages = ["printguard"]` means it is **not** in the wheel. It must be copied from the source tree in `postInstall`.
- `printguard/server/app.py` hardcodes `host="0.0.0.0"`. Patch it to honour a `HOST` env var so the module can bind loopback and let Traefik front it.
- Two upstream version floors exceed what nixpkgs ships: `fastmcp>=3.4.2` (nixpkgs has 3.3.1) and `pydantic-settings>=2.14.2` (nixpkgs has 2.12.0). Relax both. `pythonImportsCheck` in Step 4 is what proves the relaxation is safe — if either library's API moved, the import fails there rather than at runtime.
- `onnxruntime-ep-openvino` is a hard dependency in `pyproject.toml` but is an *optional plugin execution provider* not packaged in nixpkgs. Remove it from the metadata. `printguard/server/inference.py` loads it opportunistically via `PLUGIN_MODULES` and works without it.
- `printguard-desktop` needs the `desktop` extra (pywebview, pystray), which is not installed. Delete that script rather than ship one that fails on import.

- [ ] **Step 1: Confirm the attribute does not yet exist**

Run: `nix build .#printguard 2>&1 | tail -3`
Expected: an error containing `does not provide attribute` (or `attribute 'printguard' missing`).

- [ ] **Step 2: Write the package**

Create `packages/printguard/package.nix`:

```nix
{
  lib,
  python3Packages,
  fetchFromGitHub,
  buildNpmPackage,
  pycentauri,
  nix-update-script,
}:
python3Packages.buildPythonApplication rec {
  pname = "printguard";
  version = "2.4.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "oliverbravery";
    repo = "PrintGuard";
    tag = "v${version}";
    hash = "sha256-Wm/tzjm96SMUA860YzaFqXHOpZzOB/6LVa6eO35OApg=";
  };

  frontend = buildNpmPackage {
    pname = "printguard-web";
    inherit version src;

    sourceRoot = "${src.name}/web";

    npmDepsHash = "sha256-Fyd64kSJ8g+R2WVBYUr0wTk0EZoP3sERM+yf8b7J90Y=";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
      runHook postInstall
    '';
  };

  # The hub binds every interface unconditionally. Honouring HOST lets the
  # service listen on loopback and be reached only through Traefik.
  postPatch = ''
    substituteInPlace printguard/server/app.py \
      --replace-fail \
        'host="0.0.0.0"' \
        'host=os.environ.get("HOST", "0.0.0.0")'
  '';

  build-system = with python3Packages; [
    hatchling
  ];

  # onnxruntime-ep-openvino is an optional ONNX execution provider that is not
  # in nixpkgs; inference.py loads it opportunistically and falls back without
  # it. The two relaxed floors exceed what nixpkgs ships — pythonImportsCheck
  # covers whether that actually matters.
  pythonRemoveDeps = [
    "onnxruntime-ep-openvino"
  ];

  pythonRelaxDeps = [
    "fastmcp"
    "pydantic-settings"
  ];

  dependencies = with python3Packages; [
    ai-edge-litert
    aiomqtt
    av
    fastapi
    fastmcp
    httpx
    ml-dtypes
    numpy
    onnxruntime
    packaging
    paho-mqtt
    pydantic-settings
    pyprusalink
    starlette
    uvicorn
    wasmtime
  ]
  ++ [pycentauri];

  # models/ is committed upstream but excluded from the wheel, which only ships
  # the printguard package directory.
  postInstall = ''
    mkdir -p $out/share/printguard
    cp -r ${frontend} $out/share/printguard/web
    cp -r models $out/share/printguard/models

    # The desktop entry point needs the pywebview/pystray extra, which is not
    # installed here.
    rm -f $out/bin/printguard-desktop
  '';

  pythonImportsCheck = [
    "printguard"
    "printguard.server.app"
    "printguard.server.inference"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake" "--subpackage" "frontend"];
  };

  meta = {
    description = "Real-time 3D print failure detection";
    homepage = "https://github.com/oliverbravery/PrintGuard";
    license = lib.licenses.gpl2Only;
    mainProgram = "printguard";
    platforms = lib.platforms.linux;
  };
}
```

- [ ] **Step 3: Stage the file so the flake can see it**

```bash
git add packages/printguard/package.nix
```

- [ ] **Step 4: Build and verify**

Run: `nix build .#printguard -L 2>&1 | tail -40`
Expected: build succeeds.

Failure modes and what to do:

| Symptom | Fix |
|---|---|
| npm deps hash mismatch | Use the `got:` hash Nix prints for `npmDepsHash` |
| `Checking whether the following imports work` fails on `fastmcp` or `pydantic_settings` | The relaxed floor was not safe. Package the newer version locally rather than relaxing. |
| A dependency is reported unsatisfied in the dist-info check | Add its name to `pythonRelaxDeps` if the installed version is close, or `pythonRemoveDeps` if it is genuinely optional |
| `substituteInPlace ... --replace-fail` errors | Upstream changed the binding line; grep `printguard/server/app.py` for `uvicorn.run` and adjust the match |
| `python3` is 3.14 and a dependency fails to build there | Switch the two `python3Packages` references to `python312Packages` in both this file and `packages/pycentauri/package.nix` |

- [ ] **Step 5: Verify the installed layout matches what Task 3 expects**

```bash
test -f result/bin/printguard && echo "bin OK"
test -d result/share/printguard/web && echo "web OK"
test -f result/share/printguard/models/encoder_float32.tflite && echo "models OK"
find result -name qjs.wasm | head -1
```

Expected: `bin OK`, `web OK`, `models OK`, and a path ending in `printguard/server/runtime/qjs.wasm`.

If `qjs.wasm` is missing, hatchling excluded it; add to `postInstall`:
`cp ${src}/printguard/server/runtime/qjs.wasm $out/${python3Packages.python.sitePackages}/printguard/server/runtime/qjs.wasm`

- [ ] **Step 6: Format and commit**

```bash
nix fmt
git add packages/printguard/package.nix
git commit -m "Add printguard package

PrintGuard hub with its Vite frontend and the committed detection model.
Patches the hardcoded 0.0.0.0 bind to honour HOST so the service can sit
behind Traefik on loopback."
```

---

### Task 3: PrintGuard NixOS module

**Files:**
- Create: `modules/nixos/services/home/printguard.nix`
- Modify: `modules/nixos/services/home/default.nix`

**Interfaces:**
- Consumes: `pkgs.printguard` from Task 2 (`lib.getExe`, `share/printguard/{web,models}`), `pkgs.mediamtx` from nixpkgs.
- Produces: `rat.services.printguard.{enable,subdomain,enableTraefik,authentik,plugins}`, and the links `printguard`, `printguard-mediamtx-api`, `printguard-mediamtx-rtsp`, `printguard-mediamtx-hls`. Task 4 sets `enable`.

**Background the implementer needs:**

- MediaMTX is **not** optional. `ServerPlatform` always constructs a MediaMTX client and republishes every camera through it. PrintGuard supervises the binary itself, spawning it as `create_subprocess_exec(binary, config)` — the config path is the sole argument.
- Upstream's bundled `mediamtx.yml` binds RTSP `:8554`, HLS `127.0.0.1:8888`, API `127.0.0.1:9997` and RTMP `:1935`. **go2rtc already owns 8554 on this host.** Every address must come from `links`. RTMP is switched off because PrintGuard never publishes over it and 1935 has no `links` reservation behind it.
- `authInternalUsers` with `user: any` must be preserved, or PrintGuard cannot publish to or read from its own MediaMTX.
- The MQTT broker address and credentials, plus cameras, printers and monitors, are configured in PrintGuard's **web UI** and stored in `DATA_DIR/state.json`. They are not environment-driven. This module deliberately does not try to declare them.

- [ ] **Step 1: Confirm the option does not yet exist**

Run: `nix eval .#nixosConfigurations.iserlohn.config.rat.services.printguard.enable 2>&1 | tail -3`
Expected: an error containing `does not have attribute 'printguard'`.

- [ ] **Step 2: Write the module**

Create `modules/nixos/services/home/printguard.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.printguard;
  impermanenceCfg = config.rat.impermanence;
  inherit (config.rat.services) domainName;

  stateDir = "/var/lib/printguard";

  # PrintGuard supervises this binary itself and republishes every camera
  # through it, so the addresses have to be reservations rather than the
  # upstream defaults — go2rtc already holds the stock RTSP port.
  mediamtxConfig = (pkgs.formats.yaml {}).generate "mediamtx.yml" {
    api = true;
    apiAddress = config.links.printguard-mediamtx-api.tuple;

    # Without a permissive internal user PrintGuard cannot publish to or read
    # from the instance it just spawned.
    authInternalUsers = [
      {
        user = "any";
        permissions = [
          {action = "publish";}
          {action = "read";}
          {action = "playback";}
          {action = "api";}
        ];
      }
    ];

    rtsp = true;
    rtspAddress = config.links.printguard-mediamtx-rtsp.tuple;
    rtspTransports = ["tcp"];

    hls = true;
    hlsAddress = config.links.printguard-mediamtx-hls.tuple;
    hlsVariant = "fmp4";
    hlsSegmentCount = 3;
    hlsSegmentDuration = "1s";

    # Nothing here publishes over RTMP, and its default 1935 has no `links`
    # reservation standing behind it.
    rtmp = false;
    webrtc = false;
    srt = false;

    paths.all_others = null;
  };
in {
  options.rat.services.printguard = {
    enable = options.mkEnableOption "PrintGuard 3D print failure detection";

    subdomain = options.mkOption {
      type = types.str;
      default = "printguard";
      description = "The subdomain for PrintGuard.";
    };

    enableTraefik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Traefik reverse proxy for PrintGuard.";
    };

    authentik = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Put the web UI behind Authentik forward auth. Home Assistant reaches
        PrintGuard over MQTT rather than HTTP, so nothing machine-driven needs
        the HTTP surface — but forward auth does block the scoped-token REST
        and MCP API, so turn this off to use those.
      '';
    };

    plugins = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Run the QuickJS-on-wasmtime plugin sandbox. Disabling sets
        `PRINTGUARD_PLUGINS=off`, which the hub reports at startup.
      '';
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.printguard.protocol = "http";
      links.printguard-mediamtx-api.protocol = "http";
      links.printguard-mediamtx-rtsp.protocol = "rtsp";
      links.printguard-mediamtx-hls.protocol = "http";

      users.users.printguard = {
        isSystemUser = true;
        group = "printguard";
        home = stateDir;
      };
      users.groups.printguard = {};

      systemd.services.printguard = {
        description = "PrintGuard 3D print failure detection";
        after = ["network-online.target" "mosquitto.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        environment =
          {
            HOST = config.links.printguard.ipv4;
            PORT = config.links.printguard.portStr;

            DATA_DIR = stateDir;
            MODEL_DIR = "${pkgs.printguard}/share/printguard/models";
            STATIC_DIR = "${pkgs.printguard}/share/printguard/web";

            MEDIAMTX_BINARY = lib.getExe pkgs.mediamtx;
            MEDIAMTX_CONFIG = "${mediamtxConfig}";
            MEDIAMTX_API = config.links.printguard-mediamtx-api.url;
            MEDIAMTX_RTSP = config.links.printguard-mediamtx-rtsp.url;
            MEDIAMTX_HLS = config.links.printguard-mediamtx-hls.url;

            PRINTGUARD_ORIGINS = "https://${cfg.subdomain}.${domainName}";
          }
          // lib.optionalAttrs (!cfg.plugins) {
            PRINTGUARD_PLUGINS = "off";
          };

        serviceConfig = {
          ExecStart = lib.getExe pkgs.printguard;
          User = "printguard";
          Group = "printguard";
          WorkingDirectory = stateDir;
          StateDirectory = "printguard";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })

    (modules.mkIf (cfg.enable && cfg.enableTraefik) {
      rat.services.traefik.routes.printguard = {
        enable = true;
        inherit (cfg) subdomain authentik;
        serviceUrl = config.links.printguard.url;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = stateDir;
            user = "printguard";
            group = "printguard";
          }
        ];
      };
    })
  ];
}
```

- [ ] **Step 3: Add the module to the imports list**

In `modules/nixos/services/home/default.nix`, add `./printguard.nix` to the `imports` list, keeping it alphabetical. The result:

```nix
{
  imports = [
    ./go2rtc.nix
    ./ha-mcp.nix
    ./home-assistant
    ./matter-server.nix
    ./mosquitto.nix
    ./printguard.nix
    ./zwave-js.nix
  ];
}
```

- [ ] **Step 4: Stage and verify the option now evaluates**

```bash
git add modules/nixos/services/home/printguard.nix modules/nixos/services/home/default.nix
nix eval .#nixosConfigurations.iserlohn.config.rat.services.printguard.enable
```

Expected: `false` (the module exists; Task 4 turns it on).

- [ ] **Step 5: Verify no port collides with go2rtc**

```bash
nix eval --json .#nixosConfigurations.iserlohn.config.links --apply \
  'l: builtins.listToAttrs (map (n: {name = n; value = l.${n}.port;}) ["printguard" "printguard-mediamtx-api" "printguard-mediamtx-rtsp" "printguard-mediamtx-hls" "go2rtc" "go2rtc-rtsp"])'
```

Expected: six distinct port numbers. The `links` module asserts on collisions at eval time, so a duplicate would already have failed Step 4 — this makes the RTSP separation visible.

- [ ] **Step 6: Format and commit**

```bash
nix fmt
git add modules/nixos/services/home/printguard.nix modules/nixos/services/home/default.nix
git commit -m "Add PrintGuard service module

Runs the hub with a supervised MediaMTX whose listeners are all links
reservations — the stock RTSP port belongs to go2rtc on this host."
```

---

### Task 4: Enable PrintGuard on iserlohn with its MQTT user

**Files:**
- Create: `secrets/printguard.yaml`
- Modify: `systems/iserlohn/home-assistant.nix`

**Interfaces:**
- Consumes: `rat.services.printguard.enable` from Task 3, `rat.services.mosquitto.users` from the existing mosquitto module.
- Produces: a running service and an MQTT account whose credentials are typed into PrintGuard's web UI.

**Background the implementer needs:**

- PrintGuard publishes Home Assistant MQTT discovery messages under `homeassistant/`, so its ACL needs `readwrite homeassistant/#`. It also needs `read homeassistant/status` to see HA's birth/will messages, matching the existing `homeassistant` user's rules.
- `secrets/printguard.yaml` is covered by the existing `.sops.yaml` `creation_rules` path regex, so `sops` will encrypt it to all four age keys with no rule changes.
- The MQTT username and password are entered by hand in PrintGuard's Settings UI. Nothing in Nix can push them into `state.json`.

- [ ] **Step 1: Create the encrypted secret**

```bash
nix run nixpkgs#pwgen -- -s 32 1
```

Copy the generated password, then:

```bash
nix run nixpkgs#sops -- secrets/printguard.yaml
```

In the editor that opens, enter exactly:

```yaml
mqtt_password: <the generated password>
```

Save and exit. Verify it encrypted:

```bash
grep -q "sops:" secrets/printguard.yaml && echo "encrypted OK"
grep -q "mqtt_password: ENC\[" secrets/printguard.yaml && echo "value encrypted OK"
```

Expected: both lines print OK. Keep the plaintext password — you type it into the PrintGuard UI in Step 6.

- [ ] **Step 2: Stage the secret**

```bash
git add secrets/printguard.yaml
```

This is required before the next step: an untracked secrets file is invisible to flake evaluation, and the `sops.secrets` entry referencing it silently does nothing.

- [ ] **Step 3: Wire it up**

In `systems/iserlohn/home-assistant.nix`, add at the top level of the returned attribute set, next to the other `rat.services.*` entries:

```nix
  sops.secrets."printguard/mqtt_password" = {
    sopsFile = ../../secrets/printguard.yaml;
    key = "mqtt_password";
    restartUnits = ["printguard.service"];
  };

  rat.services.printguard.enable = true;

  # PrintGuard publishes HA MQTT discovery for each monitor, so it needs the
  # same homeassistant/ topic access the HA user has.
  rat.services.mosquitto.users.printguard = {
    passwordFile = config.sops.secrets."printguard/mqtt_password".path;
    acl = [
      "readwrite homeassistant/#"
      "read homeassistant/status"
    ];
  };
```

- [ ] **Step 4: Verify the whole host still evaluates and builds**

```bash
nix eval .#nixosConfigurations.iserlohn.config.rat.services.printguard.enable
```

Expected: `true`.

```bash
nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel -L 2>&1 | tail -20
```

Expected: builds successfully.

- [ ] **Step 5: Format, commit and deploy**

```bash
nix fmt
git add systems/iserlohn/home-assistant.nix secrets/printguard.yaml
git commit -m "Enable PrintGuard on iserlohn

Adds an MQTT account with homeassistant/ topic access so the hub can
publish discovery messages for each monitor."
nix run .#switch iserlohn -- --build-host iserlohn
```

- [ ] **Step 6: Verify the service is actually up**

```bash
ssh iserlohn systemctl status printguard.service --no-pager
ssh iserlohn 'curl -sf http://$(systemctl show printguard.service -p Environment --value | tr " " "\n" | grep ^HOST= | cut -d= -f2):$(systemctl show printguard.service -p Environment --value | tr " " "\n" | grep ^PORT= | cut -d= -f2)/api/health'
```

Expected: unit `active (running)`, and the health endpoint returns JSON.

Confirm MediaMTX came up under it and did not disturb go2rtc:

```bash
ssh iserlohn 'ss -tlnp | grep -E "mediamtx|go2rtc"'
ssh iserlohn systemctl is-active go2rtc.service
```

Expected: mediamtx listening on the three allocated ports, go2rtc still `active`.

- [ ] **Step 7: Configure the monitor through the web UI**

This part is not declarative — it writes to `state.json`.

1. Open `https://printguard.<domainName>`.
2. In Settings, point MQTT at the broker: host is iserlohn, port from `config.links.mosquitto.port`, username `printguard`, password from Step 1.
3. Add a camera using the existing go2rtc RTSP stream for `centauri_webcam`. Get its URL with:
   `nix eval --raw .#nixosConfigurations.iserlohn.config.links.go2rtc-rtsp.url` and append `/centauri_webcam`.
4. Register the printer as an Elegoo device at `Centauri-Carbon.lan`.
5. Bind camera and printer into a monitor, and choose whether a sustained defect alerts, pauses or cancels.

- [ ] **Step 8: Confirm MQTT discovery reached Home Assistant**

```bash
ssh iserlohn 'journalctl -u printguard.service -n 50 --no-pager | grep -i mqtt'
```

Then search Home Assistant for the new entities and record their exact IDs — Task 5's follow-on alert automation needs them:

Use the `ha_search` MCP tool with query `printguard`, or the HA UI under Developer Tools → States.

Expected: a defect sensor, a score sensor, a snapshot camera and an Enabled switch per monitor.

---

### Task 5: Home Assistant notify group and print lifecycle automation

**Files:**
- Modify: `systems/iserlohn/home-assistant.nix`

**Interfaces:**
- Consumes: nothing from earlier tasks — this is independent of PrintGuard and can be done first if preferred.
- Produces: `notify.alexis_push`, targeted by any future PrintGuard alert automation.

**Background the implementer needs:**

- Both notify services are confirmed present: `notify.mobile_app_alexis_iphone` and `notify.mobile_app_ipad_nuevo`.
- `sensor.centauri_carbon_current_print_state_2` is an `enum` sensor whose options are exactly `["standby" "printing" "paused" "complete" "cancelled" "error"]`.
- Units, confirmed against the live entities: `print_duration` is **minutes**, `filament_used` is **metres**, `progress` is **percent**.
- The printer has an Elegoo Canvas MMU, so `M600` manual filament changes never happen — every pause is a runout, jam, or MMU error. `binary_sensor.centauri_carbon_canvas_{1..4}_prep_2` are `device_class: occupancy` sensors reporting filament presence per slot.
- `sensor.centauri_carbon_current_print_message_2` is empty during a normal print and has **not** been observed during an actual pause. Treat it as opportunistic — the template must tolerate an empty string.
- Match the existing style in this file: `trigger`/`condition`/`action` keys with `platform =` inside triggers, which is what the surrounding automations already use.

- [ ] **Step 1: Add the notify group**

In `systems/iserlohn/home-assistant.nix`, inside the `rat.services.home-assistant.config` attribute set (the same level as the existing `automation` list), add:

```nix
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
```

- [ ] **Step 2: Add the print lifecycle automation**

Append this entry to the existing `automation = [ ... ]` list in the same file:

```nix
        # Every pause here is a runout, jam, or MMU error: the Canvas unit
        # means M600 manual filament changes never happen.
        {
          alias = "Centauri Carbon → Print Ended";
          id = "centauri_print_ended";
          mode = "single";
          variables = {
            print_file = "{{ states('sensor.centauri_carbon_filename_2') }}";
            print_elapsed = ''
              {% set m = states('sensor.centauri_carbon_print_duration_2') | float(0) %}
              {{ '%dh %dm' | format(m // 60, m % 60) }}
            '';
            print_filament = "{{ states('sensor.centauri_carbon_filament_used_2') | float(0) | round(1) }} m";
            print_progress = "{{ states('sensor.centauri_carbon_progress_2') | float(0) | round(1) }}%";
            # Klipper's pause reason. Empty during a normal print, and not
            # observed during a real pause, so never depended on.
            print_reason = "{{ states('sensor.centauri_carbon_current_print_message_2') }}";
            canvas_empty = ''
              {% set ns = namespace(slots=[]) %}
              {% for slot in range(1, 5) %}
                {% if is_state('binary_sensor.centauri_carbon_canvas_' ~ slot ~ '_prep_2', 'off') %}
                  {% set ns.slots = ns.slots + [slot | string] %}
                {% endif %}
              {% endfor %}
              {{ ns.slots | join(', ') }}
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
                        message = "{{ print_file }} — {{ print_elapsed }}, {{ print_filament }} used";
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
                        message = "{{ print_file }} errored at {{ print_progress }}{% if print_reason %} — {{ print_reason }}{% endif %}";
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
                        message = "{{ print_file }} cancelled at {{ print_progress }}";
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
                        message = "{{ print_file }} paused at {{ print_progress }}{% if canvas_empty %} — Canvas {{ canvas_empty }} empty{% endif %}{% if print_reason %} — {{ print_reason }}{% endif %}";
                        data.image = "/api/camera_proxy/camera.centauri_webcam";
                      };
                    }
                  ];
                }
              ];
            }
          ];
        }
```

- [ ] **Step 3: Verify it evaluates and builds**

```bash
nix eval --json .#nixosConfigurations.iserlohn.config.services.home-assistant.config.notify
```

Expected: JSON showing the `alexis_push` group with both services.

```bash
nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel -L 2>&1 | tail -20
```

Expected: builds successfully.

- [ ] **Step 4: Format, commit and deploy**

```bash
nix fmt
git add systems/iserlohn/home-assistant.nix
git commit -m "Notify on Centauri Carbon print end

Adds a notify group covering phone and iPad, and one automation covering
complete, error, cancelled and paused. The paused branch names the empty
Canvas slot, since with an MMU a pause always means something went wrong."
nix run .#switch iserlohn -- --build-host iserlohn
```

- [ ] **Step 5: Verify the notify group registered**

```bash
ssh iserlohn 'journalctl -u home-assistant.service -n 100 --no-pager | grep -iE "notify|automation" | tail -20'
```

Then confirm the service exists and the automation loaded, using the `ha_list_services` MCP tool with `domain: notify` (expect `notify.alexis_push`) and `ha_get_state` on `automation.centauri_carbon_print_ended` (expect state `on`).

- [ ] **Step 6: Verify the templates render without waiting for a print**

A manual `automation.trigger` is not a useful test here: it carries no `trigger.id`, so no `choose` branch matches and the run completes silently. Check the templates directly instead.

Use the `ha_eval_template` MCP tool on each of these, with a print in progress or recently finished:

```jinja
{% set m = states('sensor.centauri_carbon_print_duration_2') | float(0) %}
{{ '%dh %dm' | format(m // 60, m % 60) }}
```

Expected: a duration like `3h 28m`.

```jinja
{% set ns = namespace(slots=[]) %}
{% for slot in range(1, 5) %}
  {% if is_state('binary_sensor.centauri_carbon_canvas_' ~ slot ~ '_prep_2', 'off') %}
    {% set ns.slots = ns.slots + [slot | string] %}
  {% endif %}
{% endfor %}
{{ ns.slots | join(', ') }}
```

Expected: a comma-separated list of the empty Canvas slots — `3, 4` given the slot states observed while writing this plan.

Then send one real notification to prove the group and the image attachment work, using `ha_call_service` with domain `notify`, service `alexis_push`, and data `{"title": "PrintGuard test", "message": "notify group works", "data": {"image": "/api/camera_proxy/camera.centauri_webcam"}}`.

Expected: a notification on both phone and iPad carrying a webcam still.

Finally, confirm end-to-end on the next real print end.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| `packages/pycentauri/` | Task 1 |
| `packages/printguard/` (frontend, model, wasm, Python floor) | Task 2 |
| Inference runtime — LiteRT default, no GPU | Task 2 (no CUDA wiring; `onnxruntime` taken as-is) |
| NixOS module, links ports, MediaMTX collision | Task 3 |
| Traefik + authentik option | Task 3 |
| Persistence | Task 3 |
| "What the module does not configure" | Task 4 Step 7 |
| Camera source = go2rtc RTSP | Task 4 Step 7 |
| Notify group | Task 5 Step 1 |
| Print lifecycle automation, 4 branches | Task 5 Step 2 |
| Canvas MMU enrichment | Task 5 Step 2 (`canvas_empty`) |
| PrintGuard alert automation | Deferred by design — entity IDs do not exist until Task 4 Step 8 records them |

**Deviations from the spec, and why:**

- The spec did not mention an MQTT user. PrintGuard cannot publish discovery without one, and mosquitto here denies anonymous connections, so Task 4 adds it.
- The spec did not mention patching the bind address. `app.py` hardcodes `0.0.0.0`; the one-line patch in Task 2 lets the module bind loopback instead of relying on the firewall.
- The spec did not anticipate the `fastmcp` and `pydantic-settings` version floors. Task 2 relaxes both and states how to tell whether that was safe.

**Open risk:** the two relaxed floors are the most likely thing to fail. If `pythonImportsCheck` rejects either, the fallback is a local package of the newer version, which is a new task rather than an edit to Task 2.
