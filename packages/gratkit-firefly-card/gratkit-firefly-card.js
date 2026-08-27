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
