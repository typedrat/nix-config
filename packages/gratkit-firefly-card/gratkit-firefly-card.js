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
  .gauges { display: flex; justify-content: space-around; align-items: center;
            margin-top: 12px; }
  .gauges > * { cursor: pointer; }
  .graph { margin-top: 10px; position: relative; }
  .graph svg { display: block; width: 100%; height: 96px; }
  .axis { display: flex; justify-content: space-between; font-size: 10px;
          color: var(--gkf-muted); margin-top: 2px; }
  .nodata { position: absolute; inset: 0; display: flex; align-items: center;
            justify-content: center; font-size: 12px; color: var(--gkf-muted); }
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
`;

class GratkitFireflyCard extends HTMLElement {
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
    // A config change can repoint target_temp/timer at a different entity;
    // without this the old entity's optimistic value and timers would linger
    // in the maps forever.
    for (const t of Object.values(this._pending)) clearTimeout(t);
    for (const t of Object.values(this._expiry)) clearTimeout(t);
    this._pending = {};
    this._optimistic = {};
    this._expiry = {};
  }

  set hass(hass) {
    const first = !this._hass;
    this._hass = hass;
    if (!this._built) this._build();
    this._update();
    if (first && this.isConnected) this._fetchStats();
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

  _build() {
    const c = this._config;

    this._els.name = h("div", {
      class: "name",
      onclick: () => this._moreInfo(c.fan || c.current_temp),
    });
    this._els.sub = h("div", { class: "sub" });
    this._els.pill = h("span", { class: "pill" });

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
        graph,
        this._els.diag,
        controls,
      ),
    );

    const style = document.createElement("style");
    style.textContent = STYLE;
    this.shadowRoot.append(style, card);
    this._built = true;
  }

  _update() {
    if (!this._hass || !this._config) return;
    this._updateHeader();
    this._updateGauges();
    this._updateDiagnostics();
    this._updateControls();
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
}

customElements.define(CARD_TAG, GratkitFireflyCard);

window.customCards = window.customCards || [];
window.customCards.push({
  type: CARD_TAG,
  name: "GratKit Firefly V2",
  description: "Filament dryer status, history and controls",
  preview: false,
});
