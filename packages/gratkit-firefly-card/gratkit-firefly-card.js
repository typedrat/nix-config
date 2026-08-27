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
  .graph { margin-top: 10px; position: relative; }
  .graph svg { display: block; width: 100%; height: 96px; }
  .axis { display: flex; justify-content: space-between; font-size: 10px;
          color: var(--gkf-muted); margin-top: 2px; }
  .nodata { position: absolute; inset: 0; display: flex; align-items: center;
            justify-content: center; font-size: 12px; color: var(--gkf-muted); }
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

  connectedCallback() {
    // Statistics change at most once every five minutes; polling faster only
    // costs recorder queries.
    this._statsTimer = setInterval(() => this._fetchStats(), 5 * 60 * 1000);
    this._fetchStats();
  }

  disconnectedCallback() {
    clearInterval(this._statsTimer);
    this._statsTimer = null;
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
