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

    const style = document.createElement("style");
    style.textContent = STYLE;
    this.shadowRoot.append(style, card);
    this._built = true;
  }

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
}

customElements.define(CARD_TAG, GratkitFireflyCard);

window.customCards = window.customCards || [];
window.customCards.push({
  type: CARD_TAG,
  name: "GratKit Firefly V2",
  description: "Filament dryer status, history and controls",
  preview: false,
});
