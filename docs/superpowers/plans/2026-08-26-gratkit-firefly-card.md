# GratKit Firefly V2 Lovelace Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy a custom Lovelace card for the GratKit Firefly V2 filament dryer, replacing the missing `custom:gratkit-firefly-card` that has left the `3d-printing` dashboard blank since April.

**Architecture:** One hand-written vanilla ES module (`HTMLElement` + shadow DOM, no build step) packaged by a `stdenvNoCC` copy derivation and wired into Home Assistant through `rat.services.home-assistant.customLovelaceModules`. The card builds its DOM once and mutates cached node references on each `hass` update, so a state change several times a minute never tears down the SVG graph.

**Tech Stack:** Vanilla JavaScript (ES2022, no dependencies), SVG, Nix (`stdenvNoCC`), NixOS `services.home-assistant`, Home Assistant websocket API (`recorder/statistics_during_period`).

## Global Constraints

- Card element tag and package `pname` are both exactly `gratkit-firefly-card`; the module installs to `$out/gratkit-firefly-card.js`.
- No npm, no lockfile, no build step. The derivation copies one file.
- Config keys reuse the names already in the dashboard: `fan`, `current_temp`, `target_temp`, `humidity`, `heating_temp`, `fan_speed`, `timer`, `material`, `light`, `error`, `sound`, `lcd`. New keys: `name`, `hours` (default `24`), `humidity_max` (default `60`).
- `binary_sensor.gratkit_firefly_v2_usb` is NOT wired up. It only reports whether something is plugged into the USB port.
- Every entity key is optional. An unset key, or one naming an entity absent from `hass.states`, renders that control disabled showing an em dash (`—`). `setConfig` throws only when the config names no entities at all.
- The timer entity (`number`, DP 101 `countdown`) is in **minutes** despite declaring `unit_of_measurement: "s"`. Render as `Off` / `45 m` / `2 h 30 m`; step in 30-minute increments, range 0–1440.
- The error entity carries an error **code**. localtuya's `state_on: "1"` matches only code 1. Read the `raw_state` attribute and treat anything not `0`/`false` as a fault; fall back to `state` when the attribute is absent.
- The light select offers 21 options including bare numerals `"13"`–`"20"`. Show only `OFF`, the nine named colours, and the three `Rainbow *` effects — but still display a value outside that set correctly if the device is already on one.
- Graph data comes from `recorder/statistics_during_period`, never raw history. `heating_temp` is never graphed (101,876 rows in 7 days).
- Styling goes through Home Assistant CSS custom properties so the host's Catppuccin theme applies. Never hardcode a colour without a `var(--…, fallback)` wrapper.
- The stale storage resource (id `6906523868364b138ea56d4d82d48b05`) must be deleted **before** the first rebuild. After it, `resource_mode` is `yaml` and the resource-management websocket API no longer exists.
- Do not commit or echo the localtuya `local_key` or `client_secret` found in `.storage/core.config_entries`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `packages/gratkit-firefly-card/gratkit-firefly-card.js` | The entire card: element registration, config, rendering, graph, controls |
| `packages/gratkit-firefly-card/package.nix` | Copy derivation; content-hashed version so the resource URL cache-busts on every edit |
| `systems/iserlohn/home-assistant.nix` | One line adding the package to `customLovelaceModules` |

The card is a single file by design. It is one device's UI with no reusable parts, and splitting ~500 lines across modules would mean either a bundler (rejected in the spec) or multiple `<script>` resources.

Live state changed through APIs, not files:

- The `3d-printing` storage dashboard config (via `ha_config_set_dashboard`)
- The stale resource registration (via `ha_config_delete_dashboard_resource`)

---

## Task 1: Pipeline — package, wiring, and a card that renders

Proves the whole chain end to end (Nix package → `buildEnv` → `www/nixos-lovelace-modules` symlink → YAML resource → element registration → browser) with the least possible UI code. Every later task is then verifiable by reloading a page.

**Files:**
- Create: `packages/gratkit-firefly-card/gratkit-firefly-card.js`
- Create: `packages/gratkit-firefly-card/package.nix`
- Modify: `systems/iserlohn/home-assistant.nix:178` (immediately after the `customComponents` block)

**Interfaces:**
- Produces: package attribute `pkgs.gratkit-firefly-card`; custom element `gratkit-firefly-card`; the module-scope helpers `stateOf`, `isDead`, `num`, `fmt`, `h`, `svgEl`, and the class `GratkitFireflyCard` with private fields `_config`, `_hass`, `_els`, `_built`, which Tasks 2–4 extend.

- [ ] **Step 1: Write the card module**

Create `packages/gratkit-firefly-card/gratkit-firefly-card.js`:

```js
const CARD_TAG = "gratkit-firefly-card";

// Config keys naming an entity. Everything else in the config is a scalar option.
const ENTITY_KEYS = [
  "fan", "current_temp", "target_temp", "humidity", "heating_temp",
  "fan_speed", "timer", "material", "light", "error", "sound", "lcd",
];

const DASH = "—";

const stateOf = (hass, id) => (id && hass && hass.states[id]) || null;
const isDead = (s) => !s || s.state === "unavailable" || s.state === "unknown";

// Numeric value of a state object, or null when it is missing or not a number.
const num = (s) => {
  if (isDead(s)) return null;
  const n = Number(s.state);
  return Number.isFinite(n) ? n : null;
};

// Format a number for display, falling back to an em dash.
const fmt = (n, digits = 0, suffix = "") =>
  n === null || n === undefined ? DASH : `${n.toFixed(digits)}${suffix}`;

// Terse element builder: h("div", {class: "x"}, "text", childNode)
const h = (tag, attrs = {}, ...kids) => {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") el.className = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v);
  }
  for (const kid of kids) {
    if (kid === null || kid === undefined) continue;
    el.appendChild(typeof kid === "string" ? document.createTextNode(kid) : kid);
  }
  return el;
};

const NS = "http://www.w3.org/2000/svg";
const svgEl = (tag, attrs = {}) => {
  const el = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  return el;
};

const STYLE = `
  :host { --gkf-temp: var(--state-climate-heat-color, #ffb74d);
          --gkf-humidity: var(--state-humidifier-on-color, #64b5f6);
          --gkf-muted: var(--secondary-text-color, #9b9b9b);
          --gkf-line: var(--divider-color, rgba(127,127,127,.25)); }
  .wrap { padding: 16px; }
  .hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
  .name { font-size: 16px; font-weight: 500; cursor: pointer; }
  .sub { font-size: 12px; color: var(--gkf-muted); margin-top: 2px; }
  .pill { font-size: 11px; font-weight: 500; letter-spacing: .3px; padding: 3px 9px;
          border-radius: 10px; white-space: nowrap;
          background: color-mix(in srgb, var(--success-color, #4caf50) 18%, transparent);
          color: var(--success-color, #4caf50); }
  .pill.bad { background: color-mix(in srgb, var(--error-color, #f44336) 18%, transparent);
              color: var(--error-color, #f44336); }
  .pill.idle { background: color-mix(in srgb, var(--gkf-muted) 18%, transparent);
               color: var(--gkf-muted); }
`;

class GratkitFireflyCard extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._config = null;
    this._hass = null;
    this._els = {};
    this._built = false;
  }

  setConfig(config) {
    if (!config || !ENTITY_KEYS.some((k) => config[k])) {
      throw new Error(
        `${CARD_TAG}: configure at least one of ${ENTITY_KEYS.join(", ")}`,
      );
    }
    this._config = { hours: 24, humidity_max: 60, ...config };
    this._built = false;
    this._els = {};
    this.shadowRoot.innerHTML = "";
  }

  set hass(hass) {
    this._hass = hass;
    if (!this._built) this._build();
    this._update();
  }

  getCardSize() {
    return 10;
  }

  // Open the standard more-info dialog for an entity.
  _moreInfo(entityId) {
    if (!entityId) return;
    const ev = new Event("hass-more-info", { bubbles: true, composed: true });
    ev.detail = { entityId };
    this.dispatchEvent(ev);
  }

  _build() {
    const c = this._config;

    this._els.name = h("div", {
      class: "name",
      onclick: () => this._moreInfo(c.fan || c.current_temp),
    });
    this._els.sub = h("div", { class: "sub" });
    this._els.pill = h("span", { class: "pill" });

    const card = h(
      "ha-card",
      {},
      h(
        "div",
        { class: "wrap" },
        h(
          "div",
          { class: "hdr" },
          h("div", {}, this._els.name, this._els.sub),
          this._els.pill,
        ),
      ),
    );

    const style = document.createElement("style");
    style.textContent = STYLE;
    this.shadowRoot.append(style, card);
    this._built = true;
  }

  _update() {
    const hass = this._hass;
    const c = this._config;
    if (!hass || !c) return;

    const fan = stateOf(hass, c.fan);
    this._els.name.textContent =
      c.name || fan?.attributes?.friendly_name || "GratKit Firefly V2";

    const material = stateOf(hass, c.material);
    const running = fan && fan.state === "on";
    const bits = [running ? "Drying" : "Off"];
    if (!isDead(material)) bits.push(material.state);
    this._els.sub.textContent = bits.join(" · ");

    const chamber = num(stateOf(hass, c.current_temp));
    this._els.pill.textContent = fmt(chamber, 0, " °C");
    this._els.pill.className = running ? "pill" : "pill idle";
  }
}

customElements.define(CARD_TAG, GratkitFireflyCard);

window.customCards = window.customCards || [];
window.customCards.push({
  type: CARD_TAG,
  name: "GratKit Firefly V2",
  description: "Filament dryer status, history and controls",
  preview: false,
});
```

- [ ] **Step 2: Check the module parses**

```bash
node --check packages/gratkit-firefly-card/gratkit-firefly-card.js && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`. `node` is v24 on this host; a syntax error prints a `SyntaxError` and exits non-zero.

- [ ] **Step 3: Write the Nix package**

Create `packages/gratkit-firefly-card/package.nix`:

```nix
{
  lib,
  stdenvNoCC,
}: let
  source = ./gratkit-firefly-card.js;
in
  stdenvNoCC.mkDerivation {
    pname = "gratkit-firefly-card";

    # The Home Assistant module appends this to the resource URL as a query
    # string. Deriving it from the file's own hash means an edited card always
    # gets a new URL, so browsers cannot serve a stale copy from cache.
    version = "1.0.0-${builtins.substring 0 8 (builtins.hashFile "sha256" source)}";

    src = source;

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp $src $out/gratkit-firefly-card.js

      runHook postInstall
    '';

    meta = {
      description = "Lovelace card for the GratKit Firefly V2 filament dryer";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
```

There is deliberately no `passthru.updateScript`: the card has no upstream to track. The GitHub Actions update workflow filters on that attribute, so omitting it simply excludes the package.

- [ ] **Step 4: Build the package**

```bash
git add packages/gratkit-firefly-card
nix build .#gratkit-firefly-card --no-link --print-out-paths
```

`git add` first — flake evaluation only sees git-tracked files, so an untracked package directory silently does not exist.

Expected: one `/nix/store/…-gratkit-firefly-card-1.0.0-<8 hex chars>` path.

```bash
ls -l "$(nix build .#gratkit-firefly-card --no-link --print-out-paths)"
```

Expected: exactly `gratkit-firefly-card.js`.

- [ ] **Step 5: Wire the package into Home Assistant**

In `systems/iserlohn/home-assistant.nix`, immediately after the closing `];` of the `customComponents` list, add:

```nix
    customLovelaceModules = [pkgs.gratkit-firefly-card];
```

- [ ] **Step 6: Verify the generated resource entry**

```bash
nix eval --json .#nixosConfigurations.iserlohn.config.services.home-assistant.config.lovelace
```

Expected: `resource_mode` is now `"yaml"` (it was `null`), and the `dashboards` key is unchanged.

```bash
nix eval --json .#nixosConfigurations.iserlohn.config.services.home-assistant.customLovelaceModules --apply 'ps: map (p: p.name) ps'
```

Expected: one entry naming `gratkit-firefly-card`.

- [ ] **Step 7: Build the host**

```bash
nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel --no-link --print-out-paths
echo "exit=$?"
```

Expected: a store path and `exit=0`. Check the exit code explicitly — piping a build into `tail` and chaining with `&&` tests the exit status of `tail`, not of `nix build`, and will report success for a failed build.

- [ ] **Step 8: Delete the stale storage resource — BEFORE deploying**

Use the MCP tool `ha_config_delete_dashboard_resource` with `resource_id` `6906523868364b138ea56d4d82d48b05`.

Confirm it is gone with `ha_config_list_dashboard_resources`.

Expected: `total_count: 0`.

This must happen now. After the next step `resource_mode` is `yaml`, Home Assistant builds a `ResourceYAMLCollection` which registers no create/update/delete websocket handlers, and the entry becomes undeletable through the API.

- [ ] **Step 9: Deploy**

```bash
nix run .#switch iserlohn -- --build-host iserlohn
```

Expected: completes without error.

- [ ] **Step 10: Verify the resource now resolves**

```bash
ssh -A iserlohn 'sudo grep -A4 "^lovelace:" /etc/home-assistant/configuration.yaml'
```

Expected: a `resources:` list containing one `url: /local/nixos-lovelace-modules/gratkit-firefly-card.js?1.0.0-…` with `type: module`, and `resource_mode: yaml`.

```bash
ssh -A iserlohn 'sudo ls -l /var/lib/hass/www/nixos-lovelace-modules/'
```

Expected: `gratkit-firefly-card.js` present.

```bash
ssh iserlohn 'curl -s -o /dev/null -w "%{http_code}\n" \
  http://127.0.0.1:38156/local/nixos-lovelace-modules/gratkit-firefly-card.js'
```

Expected: `200`. This returned `404` before the change and is the regression test for the original fault.

- [ ] **Step 11: Correct the dashboard config**

The existing `3d-printing` config points `error` at `sensor.gratkit_firefly_v2_error`, which does not exist — the entity is a `binary_sensor`. Use `ha_config_set_dashboard` with `url_path` `3d-printing` and this config:

```json
{
  "views": [{
    "type": "sections",
    "max_columns": 2,
    "sections": [{
      "type": "grid",
      "cards": [{
        "type": "custom:gratkit-firefly-card",
        "fan": "fan.gratkit_firefly_v2_fan",
        "current_temp": "sensor.gratkit_firefly_v2_current_temperature",
        "target_temp": "number.gratkit_firefly_v2_temperature",
        "humidity": "sensor.gratkit_firefly_v2_current_humidity",
        "heating_temp": "sensor.gratkit_firefly_v2_heating_temperature",
        "fan_speed": "sensor.gratkit_firefly_v2_fan_speed",
        "timer": "number.gratkit_firefly_v2_timer",
        "material": "select.gratkit_firefly_v2_material_type",
        "light": "select.gratkit_firefly_v2_light",
        "error": "binary_sensor.gratkit_firefly_v2_error",
        "sound": "switch.gratkit_firefly_v2_sound",
        "lcd": "switch.gratkit_firefly_v2_lcd",
        "hours": 24
      }]
    }]
  }]
}
```

- [ ] **Step 12: Confirm it renders in a browser**

Using the Chrome MCP tools, open `https://home.thisratis.gay/3d-printing/0` and take a screenshot.

Expected: a card headed `GratKit Firefly V2`, sub-line `Drying · PETG`, and a pill reading the current chamber temperature. Not the red "Custom element doesn't exist" box.

If the browser shows the old error, hard-reload — the frontend caches modules aggressively, though the content-hashed query string should prevent it.

- [ ] **Step 13: Commit**

```bash
nix fmt
git add packages/gratkit-firefly-card systems/iserlohn/home-assistant.nix
git commit -m "Add the GratKit Firefly card and wire it into Home Assistant

The 3d-printing dashboard referenced a custom element whose JavaScript was
never packaged, so its resource URL 404'd and the view rendered blank.

Setting customLovelaceModules also flips lovelace.resource_mode to yaml, so
the hand-registered storage resource was deleted first — that API disappears
once the module list is non-empty."
```

---

## Task 2: Status header and radial gauges

**Files:**
- Modify: `packages/gratkit-firefly-card/gratkit-firefly-card.js`

**Interfaces:**
- Consumes: `stateOf`, `isDead`, `num`, `fmt`, `h`, `svgEl`, `DASH`, `STYLE`, and `GratkitFireflyCard._build` / `._update` from Task 1.
- Produces: `errorInfo(stateObj)` returning `{fault: boolean, code: string|null}`; `gauge(opts)` returning `{node, set}` where `set({value, lo, hi, foot})` updates it in place. Task 3 relies on `_update` already being split into per-section updates.

- [ ] **Step 1: Add the error reader and gauge factory**

Insert after `svgEl` in the module:

```js
// The error entity carries a code, but localtuya declares state_on: "1", so any
// code other than 1 reads as "off". Trust the raw code when it is present.
const errorInfo = (s) => {
  if (isDead(s)) return { fault: false, code: null };
  const raw = s.attributes?.raw_state;
  if (raw !== undefined && raw !== null) {
    const code = String(raw);
    const clear = code === "0" || code === "false" || code === "False";
    return { fault: !clear, code: clear ? null : code };
  }
  return { fault: s.state === "on", code: s.state === "on" ? "1" : null };
};

const GAUGE_START = 135;
const GAUGE_SWEEP = 270;

// A 270-degree radial gauge. Returns the SVG node plus a setter so the caller
// can update it without rebuilding the DOM.
const gauge = ({ label, unit, colour, digits = 0 }) => {
  const R = 44, CX = 64, CY = 60;
  const point = (deg) => [
    CX + R * Math.cos((deg * Math.PI) / 180),
    CY + R * Math.sin((deg * Math.PI) / 180),
  ];
  const arc = (from, to) => {
    const [x1, y1] = point(from);
    const [x2, y2] = point(to);
    return `M ${x1} ${y1} A ${R} ${R} 0 ${to - from > 180 ? 1 : 0} 1 ${x2} ${y2}`;
  };

  const node = svgEl("svg", { width: 128, height: 112, viewBox: "0 0 128 112" });
  const track = svgEl("path", {
    d: arc(GAUGE_START, GAUGE_START + GAUGE_SWEEP),
    fill: "none", stroke: "var(--gkf-line)", "stroke-width": 9, "stroke-linecap": "round",
  });
  const fill = svgEl("path", {
    fill: "none", stroke: colour, "stroke-width": 9, "stroke-linecap": "round",
  });
  const value = svgEl("text", {
    x: CX, y: CY + 4, "text-anchor": "middle", fill: colour,
    "font-size": 27, "font-weight": 300,
  });
  const foot = svgEl("text", {
    x: CX, y: CY + 22, "text-anchor": "middle", fill: "var(--gkf-muted)", "font-size": 10,
  });
  const cap = svgEl("text", {
    x: CX, y: 106, "text-anchor": "middle", fill: "var(--gkf-muted)",
    "font-size": 11, "letter-spacing": .6,
  });
  cap.textContent = label;
  node.append(track, fill, value, foot, cap);

  const set = ({ value: v, lo, hi, foot: footText }) => {
    value.textContent = v === null ? DASH : `${v.toFixed(digits)}${unit}`;
    foot.textContent = footText || "";
    const frac = v === null || hi === lo ? 0 : Math.max(0, Math.min(1, (v - lo) / (hi - lo)));
    if (frac > 0.001) {
      fill.setAttribute("d", arc(GAUGE_START, GAUGE_START + GAUGE_SWEEP * frac));
      fill.removeAttribute("visibility");
    } else {
      fill.setAttribute("visibility", "hidden");
    }
  };

  set({ value: null, lo: 0, hi: 1 });
  return { node, set };
};
```

- [ ] **Step 2: Extend the stylesheet**

Append to the `STYLE` template literal, before its closing backtick:

```js
  .gauges { display: flex; justify-content: space-around; align-items: center;
            margin-top: 12px; }
  .gauges > * { cursor: pointer; }
```

- [ ] **Step 3: Build the gauges**

In `_build`, replace the `const card = h(` statement with:

```js
    this._els.tempGauge = gauge({
      label: "CHAMBER", unit: "°", colour: "var(--gkf-temp)",
    });
    this._els.humGauge = gauge({
      label: "HUMIDITY", unit: "%", colour: "var(--gkf-humidity)",
    });

    const gauges = h(
      "div",
      { class: "gauges" },
      h("div", { onclick: () => this._moreInfo(c.current_temp) }, this._els.tempGauge.node),
      h("div", { onclick: () => this._moreInfo(c.humidity) }, this._els.humGauge.node),
    );

    const card = h(
      "ha-card",
      {},
      h(
        "div",
        { class: "wrap" },
        h(
          "div",
          { class: "hdr" },
          h("div", {}, this._els.name, this._els.sub),
          this._els.pill,
        ),
        gauges,
      ),
    );
```

- [ ] **Step 4: Rework `_update` into sections**

Replace the whole `_update` method with:

```js
  _update() {
    if (!this._hass || !this._config) return;
    this._updateHeader();
    this._updateGauges();
  }

  _updateHeader() {
    const hass = this._hass;
    const c = this._config;

    const fan = stateOf(hass, c.fan);
    this._els.name.textContent =
      c.name || fan?.attributes?.friendly_name || "GratKit Firefly V2";

    const material = stateOf(hass, c.material);
    const running = fan && fan.state === "on";
    const bits = [running ? "Drying" : "Off"];
    if (!isDead(material)) bits.push(material.state);
    this._els.sub.textContent = bits.join(" · ");

    const { fault, code } = errorInfo(stateOf(hass, c.error));
    const pill = this._els.pill;
    if (fault) {
      pill.textContent = `Error ${code}`;
      pill.className = "pill bad";
    } else if (running) {
      pill.textContent = "OK";
      pill.className = "pill";
    } else {
      pill.textContent = "Off";
      pill.className = "pill idle";
    }
  }

  _updateGauges() {
    const hass = this._hass;
    const c = this._config;

    const target = stateOf(hass, c.target_temp);
    const targetVal = num(target);
    this._els.tempGauge.set({
      value: num(stateOf(hass, c.current_temp)),
      lo: target?.attributes?.min ?? 40,
      hi: target?.attributes?.max ?? 70,
      foot: targetVal === null ? "" : `target ${targetVal.toFixed(0)}`,
    });

    this._els.humGauge.set({
      value: num(stateOf(hass, c.humidity)),
      lo: 0,
      hi: c.humidity_max,
      foot: this._peakHumidity === undefined || this._peakHumidity === null
        ? ""
        : `peak ${this._peakHumidity.toFixed(0)}%`,
    });
  }
```

`this._peakHumidity` is deliberately undefined until Task 3 populates it from the statistics fetch; the guard renders an empty footer until then.

- [ ] **Step 5: Check syntax and rebuild**

```bash
node --check packages/gratkit-firefly-card/gratkit-firefly-card.js && echo "SYNTAX OK"
nix build .#gratkit-firefly-card --no-link --print-out-paths
```

Expected: `SYNTAX OK`, and a store path whose hash suffix **differs** from Task 1's — confirming the content-hashed version works.

- [ ] **Step 6: Deploy and confirm visually**

```bash
nix run .#switch iserlohn -- --build-host iserlohn
```

Reload the `3d-printing` dashboard in Chrome and screenshot.

Expected: two radial gauges. Chamber reads roughly 65 °C with its arc about five-sixths of the way round the 40–70 range and a `target 65` footer; humidity reads about 10% with a short arc and no footer yet.

- [ ] **Step 7: Commit**

```bash
nix fmt
git add packages/gratkit-firefly-card/gratkit-firefly-card.js
git commit -m "Draw the chamber and humidity gauges

The error pill reads the raw error code rather than the binary sensor, whose
state_on is pinned to \"1\" and so misses every other fault code."
```

---

## Task 3: Temperature and humidity graph

**Files:**
- Modify: `packages/gratkit-firefly-card/gratkit-firefly-card.js`

**Interfaces:**
- Consumes: `svgEl`, `h`, `stateOf`, `num`, `STYLE`, and `GratkitFireflyCard._build` / `_updateGauges` from Tasks 1–2.
- Produces: `this._peakHumidity` (number or null) consumed by `_updateGauges`; `_fetchStats()`, `_drawGraph()`; lifecycle hooks `connectedCallback` / `disconnectedCallback`.

- [ ] **Step 1: Extend the stylesheet**

Append to `STYLE` before its closing backtick:

```js
  .graph { margin-top: 10px; position: relative; }
  .graph svg { display: block; width: 100%; height: 96px; }
  .axis { display: flex; justify-content: space-between; font-size: 10px;
          color: var(--gkf-muted); margin-top: 2px; }
  .nodata { position: absolute; inset: 0; display: flex; align-items: center;
            justify-content: center; font-size: 12px; color: var(--gkf-muted); }
```

- [ ] **Step 2: Add the graph node to `_build`**

Immediately before `const card = h(` in `_build`, add:

```js
    this._els.plot = svgEl("svg", {
      viewBox: "0 0 380 96", preserveAspectRatio: "none",
    });
    this._els.nodata = h("div", { class: "nodata" }, "No history yet");
    this._els.axisFrom = h("span", {}, `${c.hours}h ago`);
    const graph = h(
      "div",
      { class: "graph" },
      this._els.plot,
      this._els.nodata,
      h("div", { class: "axis" }, this._els.axisFrom, h("span", {}, "now")),
    );
```

and add `graph,` to the `h("div", {class: "wrap"}, …)` argument list, immediately after `gauges,`.

- [ ] **Step 3: Add the statistics fetch and lifecycle hooks**

Add these methods to the class, after `_updateGauges`:

```js
  connectedCallback() {
    // Statistics change at most once every five minutes; polling faster only
    // costs recorder queries.
    this._statsTimer = setInterval(() => this._fetchStats(), 5 * 60 * 1000);
    this._fetchStats();
  }

  disconnectedCallback() {
    clearInterval(this._statsTimer);
    this._statsTimer = null;
    // _pending write timers are left running deliberately: a click the user
    // already made should still reach the device even if the card leaves the
    // DOM before the debounce fires. _expiry timers exist only to repaint
    // this card, so there is nothing left for them to do.
    for (const t of Object.values(this._expiry)) clearTimeout(t);
    this._expiry = {};
  }

  async _fetchStats() {
    const hass = this._hass;
    const c = this._config;
    // The 5-minute interval keeps firing across a setConfig, which clears the
    // shadow root and the node cache — drawing into it then would throw.
    if (!hass || !c || !this._built) return;

    const ids = [c.current_temp, c.humidity].filter(Boolean);
    if (!ids.length) return;

    const end = new Date();
    const start = new Date(end.getTime() - c.hours * 3600 * 1000);

    let res;
    try {
      res = await hass.callWS({
        type: "recorder/statistics_during_period",
        start_time: start.toISOString(),
        end_time: end.toISOString(),
        statistic_ids: ids,
        // 5-minute statistics are only retained ~10 days; hourly are permanent.
        period: c.hours <= 12 ? "5minute" : "hour",
        types: ["mean"],
      });
    } catch (err) {
      // A recorder that is busy or purging should degrade the graph, not the card.
      console.warn(`${CARD_TAG}: statistics unavailable`, err);
      res = null;
    }

    // setConfig may have run while the above await was pending, clearing the
    // node cache — bail out quietly rather than draw into stale/missing nodes.
    if (!this._built) return;

    const series = (id) =>
      ((res && res[id]) || [])
        .map((row) => ({ t: row.start, v: row.mean }))
        .filter((p) => typeof p.v === "number" && Number.isFinite(p.v));

    this._temps = series(c.current_temp);
    this._hums = series(c.humidity);
    this._peakHumidity = this._hums.length
      ? Math.max(...this._hums.map((p) => p.v))
      : null;

    this._drawGraph();
    this._updateGauges();
  }
```

- [ ] **Step 4: Add the renderer**

Add after `_fetchStats`:

```js
  _drawGraph() {
    const plot = this._els.plot;
    const c = this._config;
    const W = 380, H = 96, PAD = 8;

    plot.textContent = "";

    const temps = this._temps || [];
    const hums = this._hums || [];
    const empty = !temps.length && !hums.length;
    this._els.nodata.style.display = empty ? "flex" : "none";
    if (empty) return;

    // Both series share the x range so they stay time-aligned even when one has
    // fewer points than the other.
    const stamps = [...temps, ...hums].map((p) => p.t);
    const t0 = Math.min(...stamps);
    const t1 = Math.max(...stamps);
    const span = t1 - t0 || 1;

    const path = (pts, lo, hi) => {
      const range = hi - lo || 1;
      return pts
        .map((p, i) => {
          const x = ((p.t - t0) / span) * W;
          const y = H - PAD - ((p.v - lo) / range) * (H - PAD * 2);
          return `${i ? "L" : "M"}${x.toFixed(1)} ${y.toFixed(1)}`;
        })
        .join(" ");
    };

    for (let i = 1; i < 3; i++) {
      plot.appendChild(svgEl("line", {
        x1: 0, x2: W, y1: (H / 3) * i, y2: (H / 3) * i,
        stroke: "var(--gkf-line)", "stroke-width": 1,
      }));
    }

    if (hums.length) {
      const gradId = `${CARD_TAG}-hum-fill`;
      const defs = svgEl("defs");
      const grad = svgEl("linearGradient", { id: gradId, x1: 0, y1: 0, x2: 0, y2: 1 });
      grad.appendChild(svgEl("stop", {
        offset: "0%", "stop-color": "var(--gkf-humidity)", "stop-opacity": .3,
      }));
      grad.appendChild(svgEl("stop", {
        offset: "100%", "stop-color": "var(--gkf-humidity)", "stop-opacity": 0,
      }));
      defs.appendChild(grad);
      plot.appendChild(defs);

      const d = path(hums, 0, c.humidity_max);
      plot.appendChild(svgEl("path", {
        d: `${d} L ${W} ${H} L 0 ${H} Z`, fill: `url(#${gradId})`,
      }));
      plot.appendChild(svgEl("path", {
        d, fill: "none", stroke: "var(--gkf-humidity)", "stroke-width": 2,
        "stroke-linejoin": "round", "stroke-linecap": "round",
      }));
    }

    if (temps.length) {
      const target = stateOf(this._hass, c.target_temp);
      plot.appendChild(svgEl("path", {
        d: path(temps, target?.attributes?.min ?? 40, target?.attributes?.max ?? 70),
        fill: "none", stroke: "var(--gkf-temp)", "stroke-width": 2,
        "stroke-linejoin": "round", "stroke-linecap": "round",
      }));
    }
  }
```

- [ ] **Step 5: Fetch once the card first receives `hass`**

`connectedCallback` can run before Lovelace assigns `hass`, in which case its immediate `_fetchStats()` returns early. Add a one-shot fetch to the setter. Replace `set hass(hass)` with:

```js
  set hass(hass) {
    const first = !this._hass;
    this._hass = hass;
    if (!this._built) this._build();
    this._update();
    if (first && this.isConnected) this._fetchStats();
  }
```

- [ ] **Step 6: Check syntax, build, deploy**

```bash
node --check packages/gratkit-firefly-card/gratkit-firefly-card.js && echo "SYNTAX OK"
nix build .#gratkit-firefly-card --no-link --print-out-paths
nix run .#switch iserlohn -- --build-host iserlohn
```

Expected: `SYNTAX OK`, a fresh store hash, a clean deploy.

- [ ] **Step 7: Confirm the graph draws**

Reload the dashboard in Chrome and screenshot.

Expected: an amber temperature trace and a blue humidity trace with a gradient fill, over three faint gridlines, with `24h ago` / `now` beneath. The humidity gauge footer now reads `peak N%`.

Check the browser console for warnings:

Expected: no `statistics unavailable` warning. If one appears, read its payload — an `unknown command` there means the recorder integration is not loaded, which would be a separate fault.

- [ ] **Step 8: Commit**

```bash
git add packages/gratkit-firefly-card/gratkit-firefly-card.js
git commit -m "Plot chamber temperature and humidity from statistics

Raw history is the wrong source here: these sensors write tens of thousands of
rows a week and raw states purge at ten days, while statistics are aggregated,
permanent, and already recorded back to February."
```

---

## Task 4: Diagnostics strip and controls

**Files:**
- Modify: `packages/gratkit-firefly-card/gratkit-firefly-card.js`

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: `fmtDuration(minutes)`; `LIGHT_COLOURS`, `LIGHT_EFFECTS`; `fillSelect(sel, options)`; methods `_setNumber`, `_settleOptimistic`, `_updateDiagnostics`, `_updateControls`.

- [ ] **Step 1: Add the duration formatter and light tables**

Insert after `errorInfo` in the module:

```js
// DP 101 is `countdown`, in minutes, but localtuya declares its unit as "s".
const fmtDuration = (mins) => {
  if (mins === null || mins <= 0) return "Off";
  mins = Math.round(mins);
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (!h) return `${m} m`;
  return m ? `${h} h ${m} m` : `${h} h`;
};

const TIMER_STEP = 30;

const LIGHT_COLOURS = {
  Red: "#e53935", Green: "#43a047", Blue: "#1e88e5", White: "#fafafa",
  Yellow: "#fdd835", Cyan: "#00acc1", Purple: "#8e24aa", Orange: "#fb8c00",
  Pink: "#ec407a",
};
const LIGHT_EFFECTS = ["Rainbow Fade", "Rainbow Blink", "Rainbow Smooth"];
const RAINBOW = "linear-gradient(90deg,#e53935,#fdd835,#43a047,#1e88e5)";

// The select also offers "13".."20", which have no documented meaning.
const lightOptions = (s) => {
  const all = s?.attributes?.options || [];
  const known = ["OFF", ...Object.keys(LIGHT_COLOURS), ...LIGHT_EFFECTS];
  const shown = all.filter((o) => known.includes(o));
  // Keep the current value selectable even when it is one of the unnamed ones.
  if (s && !shown.includes(s.state) && all.includes(s.state)) shown.push(s.state);
  return shown;
};

const lightSwatch = (option) => {
  if (option === "OFF") return "transparent";
  if (LIGHT_EFFECTS.includes(option)) return RAINBOW;
  return LIGHT_COLOURS[option] || "var(--gkf-muted)";
};

// A <select> with no options to show renders as an empty greyed box; give it
// a single disabled option so a disabled select reads the same em dash as
// every other disabled control.
const fillSelect = (sel, options) => {
  const key = options.join(" ");
  if (sel.dataset.options === key) return;
  sel.dataset.options = key;
  sel.textContent = "";
  if (options.length) {
    for (const o of options) sel.appendChild(h("option", { value: o }, o));
  } else {
    sel.appendChild(h("option", { value: "", disabled: "" }, DASH));
  }
};
```

- [ ] **Step 2: Extend the stylesheet**

Append to `STYLE` before its closing backtick:

```js
  .diag { display: flex; gap: 6px; flex-wrap: wrap; font-size: 11px;
          color: var(--gkf-muted); margin-top: 10px; }
  .rule { height: 1px; background: var(--gkf-line); margin: 12px 0; }
  .row { display: flex; align-items: center; justify-content: space-between;
         gap: 10px; padding: 5px 0; }
  .row .k { font-size: 13px; }
  .stepper { display: flex; align-items: center; gap: 2px;
             background: var(--gkf-line); border-radius: 16px; padding: 2px; }
  .stepper button { width: 26px; height: 26px; border: 0; border-radius: 50%;
                    background: transparent; color: inherit; font-size: 15px;
                    line-height: 1; cursor: pointer; }
  .stepper button:disabled { opacity: .35; cursor: default; }
  .stepper .v { min-width: 66px; text-align: center; font-size: 13px;
                font-variant-numeric: tabular-nums; }
  select { background: var(--gkf-line); border: 0; border-radius: 8px;
           padding: 6px 10px; font-size: 13px; color: inherit;
           font-family: inherit; cursor: pointer; }
  select:disabled { opacity: .35; cursor: default; }
  .chips { display: flex; gap: 6px; flex-wrap: wrap; }
  .chip { display: flex; align-items: center; gap: 6px; font-size: 12px;
          padding: 6px 11px; border-radius: 16px; background: var(--gkf-line);
          cursor: pointer; border: 0; color: inherit; font-family: inherit; }
  .chip:disabled { opacity: .35; cursor: default; }
  .chip.on { background: color-mix(in srgb, var(--primary-color, #03a9f4) 20%, transparent);
             color: var(--primary-color, #03a9f4); }
  .sw { width: 12px; height: 12px; border-radius: 50%;
        border: 1px solid var(--gkf-line); }
```

- [ ] **Step 3: Add the debounced number setter**

Also extend the constructor and `setConfig` written in Task 1 with the three
maps this step introduces (`_pending`, `_optimistic`, and a new `_expiry`) —
a config change can repoint `target_temp`/`timer` at a different entity,
which would otherwise orphan the old one's optimistic value and timers
forever:

```js
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._config = null;
    this._hass = null;
    this._els = {};
    this._built = false;
    // entityId -> setTimeout handle for a debounced number.set_value write.
    this._pending = {};
    // entityId -> value shown in place of the (stale) device state until the
    // write round-trips.
    this._optimistic = {};
    // entityId -> setTimeout handle that gives up on an optimistic value.
    this._expiry = {};
  }

  setConfig(config) {
    if (!config || !ENTITY_KEYS.some((k) => config[k])) {
      throw new Error(
        `${CARD_TAG}: configure at least one of ${ENTITY_KEYS.join(", ")}`,
      );
    }
    this._config = { hours: 24, humidity_max: 60, ...config };
    this._built = false;
    this._els = {};
    this.shadowRoot.innerHTML = "";
    for (const t of Object.values(this._pending)) clearTimeout(t);
    for (const t of Object.values(this._expiry)) clearTimeout(t);
    this._pending = {};
    this._optimistic = {};
    this._expiry = {};
  }
```

Add to the class, after `_moreInfo`:

```js
  // Holding a stepper button would otherwise fire one Tuya write per click.
  _setNumber(entityId, value) {
    this._optimistic[entityId] = value;
    clearTimeout(this._pending[entityId]);
    this._pending[entityId] = setTimeout(() => {
      delete this._pending[entityId];
      this._hass.callService("number", "set_value", {
        entity_id: entityId,
        value,
      }).catch(() => {});
      // A Tuya write takes 1-3s to round-trip through localtuya, and hass
      // pushes a fresh state several times a second from unrelated entities.
      // Hold the optimistic value across those pushes instead of falling back
      // to the stale device state; the expiry is only a backstop in case the
      // write is dropped and the device never echoes it back.
      clearTimeout(this._expiry[entityId]);
      this._expiry[entityId] = setTimeout(() => {
        delete this._expiry[entityId];
        delete this._optimistic[entityId];
        this._updateControls();
      }, 5000);
    }, 400);
    this._updateControls();
  }

  // Drop a held optimistic value once the device echoes it back. Does not
  // call _updateControls itself — the caller is already mid-render.
  _settleOptimistic(entityId, real) {
    if (entityId in this._optimistic && this._optimistic[entityId] === real) {
      delete this._optimistic[entityId];
      clearTimeout(this._expiry[entityId]);
      delete this._expiry[entityId];
    }
  }
```

- [ ] **Step 4: Build the diagnostics strip and controls**

In `_build`, immediately before `const card = h(`, add:

```js
    this._els.diag = h("div", { class: "diag" });

    this._els.material = h("select", {
      onchange: (e) =>
        this._hass.callService("select", "select_option", {
          entity_id: c.material,
          option: e.target.value,
        }).catch(() => {}),
    });

    const stepper = (onDown, onUp) => {
      const down = h("button", { onclick: onDown }, "−");
      const up = h("button", { onclick: onUp }, "+");
      const v = h("span", { class: "v" });
      return { node: h("span", { class: "stepper" }, down, v, up), down, up, v };
    };

    this._els.temp = stepper(
      () => this._nudgeTemp(-1),
      () => this._nudgeTemp(1),
    );
    this._els.timer = stepper(
      () => this._nudgeTimer(-TIMER_STEP),
      () => this._nudgeTimer(TIMER_STEP),
    );

    this._els.power = h("button", {
      class: "chip",
      onclick: () => this._hass.callService("fan", "toggle", { entity_id: c.fan }).catch(() => {}),
    });
    this._els.lightSw = h("span", { class: "sw" });
    this._els.light = h("select", {
      onchange: (e) =>
        this._hass.callService("select", "select_option", {
          entity_id: c.light,
          option: e.target.value,
        }).catch(() => {}),
    });
    this._els.lightChip = h("span", { class: "chip" }, this._els.lightSw, this._els.light);
    this._els.lcd = h("button", {
      class: "chip",
      onclick: () => this._hass.callService("switch", "toggle", { entity_id: c.lcd }).catch(() => {}),
    });
    this._els.sound = h("button", {
      class: "chip",
      onclick: () => this._hass.callService("switch", "toggle", { entity_id: c.sound }).catch(() => {}),
    });

    const controls = h(
      "div",
      {},
      h("div", { class: "rule" }),
      h("div", { class: "row" }, h("span", { class: "k" }, "Material"), this._els.material),
      h("div", { class: "row" }, h("span", { class: "k" }, "Target temp"), this._els.temp.node),
      h("div", { class: "row" }, h("span", { class: "k" }, "Timer"), this._els.timer.node),
      h("div", { class: "rule" }),
      h(
        "div",
        { class: "chips" },
        this._els.power,
        this._els.lightChip,
        this._els.lcd,
        this._els.sound,
      ),
    );
```

Note: the light chip's `class` is no longer the literal `"chip on"` — it starts
plain and is set from the light entity's state in `_updateControls` (Step 5).

Then add `this._els.diag,` and `controls,` to the `h("div", {class: "wrap"}, …)` argument list, after `graph,`.

- [ ] **Step 5: Add the nudge helpers and section updaters**

Add to the class, after `_setNumber`:

```js
  _nudgeTemp(delta) {
    const s = stateOf(this._hass, this._config.target_temp);
    const current = this._optimistic[this._config.target_temp] ?? num(s);
    if (current === null) return;
    const lo = s?.attributes?.min ?? 40;
    const hi = s?.attributes?.max ?? 70;
    this._setNumber(this._config.target_temp, Math.min(hi, Math.max(lo, current + delta)));
  }

  _nudgeTimer(delta) {
    const s = stateOf(this._hass, this._config.timer);
    const current = this._optimistic[this._config.timer] ?? num(s);
    if (current === null) return;
    // Snap off-grid values (the device counts down continuously) onto the step.
    const base = delta > 0 ? Math.floor(current / TIMER_STEP) * TIMER_STEP
                           : Math.ceil(current / TIMER_STEP) * TIMER_STEP;
    this._setNumber(this._config.timer, Math.min(1440, Math.max(0, base + delta)));
  }

  _updateDiagnostics() {
    const hass = this._hass;
    const c = this._config;
    const bits = [];
    const heater = num(stateOf(hass, c.heating_temp));
    if (c.heating_temp) bits.push(`Heater ${fmt(heater, 0, " °C")}`);
    const rpm = num(stateOf(hass, c.fan_speed));
    if (c.fan_speed) bits.push(`Fan ${fmt(rpm, 0, " rpm")}`);
    this._els.diag.textContent = bits.join(" · ");
  }

  _updateControls() {
    const hass = this._hass;
    const c = this._config;

    const material = stateOf(hass, c.material);
    const sel = this._els.material;
    sel.disabled = isDead(material);
    fillSelect(sel, material?.attributes?.options || []);
    if (!isDead(material)) sel.value = material.state;

    const target = stateOf(hass, c.target_temp);
    this._settleOptimistic(c.target_temp, num(target));
    const targetVal = this._optimistic[c.target_temp] ?? num(target);
    const targetLo = target?.attributes?.min ?? 40;
    const targetHi = target?.attributes?.max ?? 70;
    this._els.temp.v.textContent = fmt(targetVal, 0, " °C");
    this._els.temp.down.disabled = targetVal === null || targetVal <= targetLo;
    this._els.temp.up.disabled = targetVal === null || targetVal >= targetHi;

    const timer = stateOf(hass, c.timer);
    this._settleOptimistic(c.timer, num(timer));
    const timerVal = this._optimistic[c.timer] ?? num(timer);
    this._els.timer.v.textContent = timerVal === null ? DASH : fmtDuration(timerVal);
    this._els.timer.down.disabled = timerVal === null || timerVal <= 0;
    this._els.timer.up.disabled = timerVal === null || timerVal >= 1440;

    const fan = stateOf(hass, c.fan);
    const on = fan && fan.state === "on";
    this._els.power.textContent = `⏻ ${isDead(fan) ? DASH : on ? "On" : "Off"}`;
    this._els.power.className = on ? "chip on" : "chip";
    this._els.power.disabled = isDead(fan);

    const light = stateOf(hass, c.light);
    const lsel = this._els.light;
    const lightAlive = !isDead(light);
    lsel.disabled = !lightAlive;
    fillSelect(lsel, lightOptions(light));
    if (lightAlive) {
      lsel.value = light.state;
      this._els.lightSw.style.background = lightSwatch(light.state);
    } else {
      this._els.lightSw.style.background = "transparent";
    }
    this._els.lightChip.className = lightAlive && light.state !== "OFF" ? "chip on" : "chip";

    for (const [key, icon, label] of [["lcd", "▣", "LCD"], ["sound", "♪", "Sound"]]) {
      const s = stateOf(hass, c[key]);
      const el = this._els[key];
      el.textContent = `${icon} ${label}`;
      el.className = s && s.state === "on" ? "chip on" : "chip";
      el.disabled = isDead(s);
    }
  }
```

- [ ] **Step 6: Call the new updaters**

Replace `_update` with:

```js
  _update() {
    if (!this._hass || !this._config) return;
    this._updateHeader();
    this._updateGauges();
    this._updateDiagnostics();
    this._updateControls();
  }
```

- [ ] **Step 7: Check syntax, build, deploy**

```bash
node --check packages/gratkit-firefly-card/gratkit-firefly-card.js && echo "SYNTAX OK"
nix build .#gratkit-firefly-card --no-link --print-out-paths
nix run .#switch iserlohn -- --build-host iserlohn
```

Expected: `SYNTAX OK`, fresh store hash, clean deploy.

- [ ] **Step 8: Verify every control against the live device**

Reload the dashboard and screenshot.

Expected: a diagnostics line reading `Heater 8x °C · Fan ~5040 rpm`, a `PETG` material dropdown, `65 °C` and `Off` steppers, and four chips — power showing `⏻ On` highlighted, a light dropdown with a colour swatch reading `Rainbow Fade`, `▣ LCD` and `♪ Sound` both highlighted.

Then exercise the controls, checking each state actually changes:

```
ha_get_state("number.gratkit_firefly_v2_temperature")   # note the value
```

Click the temperature `+` once, wait a second, re-read. Expected: the value increased by 1. Click `−` to restore it.

Click the timer `+` once. Expected: the display reads `30 m` and `number.gratkit_firefly_v2_timer` becomes `30.0`. Click `−` to return it to `Off` / `0.0`.

The steppers are debounced by 400 ms, so click, then pause before re-reading.

- [ ] **Step 9: Confirm graceful degradation**

Temporarily point one key at a nonexistent entity to prove the disabled path, using `ha_config_set_dashboard` to set `"sound": "switch.does_not_exist"`.

Expected: the Sound chip renders greyed and unclickable; the rest of the card is unaffected and no console error appears.

Restore the correct entity id afterwards.

- [ ] **Step 10: Commit**

```bash
git add packages/gratkit-firefly-card/gratkit-firefly-card.js
git commit -m "Add the diagnostics strip and every control

The timer renders as a duration because DP 101 counts minutes despite being
declared in seconds, and the light picker hides options 13-20, which the
device offers but nothing documents."
```

---

## Task 5: Final verification

**Files:** none — this task only reads.

**Interfaces:**
- Consumes: the deployed card from Tasks 1–4.

- [ ] **Step 1: Confirm the original fault is gone**

```bash
ssh iserlohn 'curl -s -o /dev/null -w "%{http_code}\n" \
  http://127.0.0.1:38156/local/nixos-lovelace-modules/gratkit-firefly-card.js'
```

Expected: `200`.

```bash
ssh -A iserlohn 'sudo grep -c "nixos-lovelace-modules" /etc/home-assistant/configuration.yaml'
```

Expected: `1`.

- [ ] **Step 2: Confirm there is exactly one source of truth for resources**

Call `ha_config_list_dashboard_resources`.

Expected: `total_count: 0` — the storage collection is empty and the YAML entry is the only registration.

- [ ] **Step 3: Check Home Assistant logged nothing new**

```bash
ssh -A iserlohn 'sudo journalctl -u home-assistant.service --since "30 min ago" \
  --no-pager | grep -iE "lovelace|resource|gratkit" | tail -20'
```

Expected: no errors mentioning the card or its resource.

- [ ] **Step 4: Screenshot the finished card at two widths**

Using the Chrome MCP tools, load the `3d-printing` dashboard at 1280px and at 420px wide, screenshotting each.

Expected: at both widths the card renders whole, the graph scales without overflowing its `ha-card`, and the chip row wraps rather than clipping. The page body must not scroll horizontally.

- [ ] **Step 5: Verify the cache-buster actually changes**

```bash
git log --oneline -4 -- packages/gratkit-firefly-card/gratkit-firefly-card.js
nix eval --raw .#gratkit-firefly-card.version
```

Expected: the version ends in an 8-character hex suffix. Confirm it differs from the value recorded in Task 1 Step 4 — proving an edited card cannot be served from browser cache.

- [ ] **Step 6: Record the behaviour change in the repository**

`resource_mode` is now `yaml`, so Lovelace resources are managed by Nix and the
Home Assistant UI can no longer add or edit them. That is a surprise waiting for
whoever next tries. Add it to `CLAUDE.md` under **Important Patterns**, as a new
subsection after *Secret Management*:

```markdown
### Lovelace Custom Cards

Custom Lovelace modules are packages in `packages/`, installed to
`$out/<pname>.js` and listed in `rat.services.home-assistant.customLovelaceModules`.

Setting that option to a non-empty list makes the nixpkgs module set
`lovelace.resource_mode = "yaml"`, which means Home Assistant loads resources
from `configuration.yaml` and **ignores `.storage/lovelace_resources`**. The
UI's Settings → Dashboards → Resources page stops working; add packages to
`customLovelaceModules` instead. Any resource registered through the UI must be
deleted *before* the list becomes non-empty, because the resource-management
websocket API disappears with the switch to YAML mode.

Give each card a content-hashed `version` — the module appends it to the
resource URL as a query string, so a card edited without a version bump is
served from browser cache.
```

Commit it:

```bash
git add CLAUDE.md
git commit -m "Document Lovelace custom cards and the resource_mode switch"
```

---

## Notes for whoever picks this up later

- **Editing the card requires a rebuild.** The file lives in the Nix store; there is no live-reload. `nix run .#switch iserlohn -- --build-host iserlohn` after every change.
- **Resources are now declarative.** The Home Assistant UI's *Settings → Dashboards → Resources* page will refuse to add or edit entries while `resource_mode` is `yaml`. Add packages to `customLovelaceModules` instead.
- **`heating_temperature` writes roughly 100,000 recorder rows a week.** Out of scope here, but a `recorder.exclude` entry for it would be a cheap win.
- **The `ui-lovelace.yaml` symlink in `/var/lib/hass` is dangling** and has been since April. Harmless while `lovelace.mode` is `storage`, and unrelated to this work.
