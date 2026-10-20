// Claude Desktop entrypoint: themes claude.ai and the app's own windows with
// Catppuccin, then starts the real app.
const { app, webFrameMain } = require("electron");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const css = fs.readFileSync(path.join(__dirname, "catppuccin.css"), "utf8");
const appUrl = pathToFileURL(app.getAppPath()).href;

// Only Anthropic's pages and the app's own windows: the same WebContents also
// host arbitrary sites (link previews, the browser tool).
const isThemed = (url) => {
  if (url.startsWith(`${appUrl}/`)) return true;
  try {
    const { protocol, hostname } = new URL(url);
    return protocol === "https:" && (hostname === "claude.ai" || hostname.endsWith(".claude.ai"));
  } catch {
    return false;
  }
};

// insertCSS only reaches a WebContents' main frame, and Claude Code renders
// inside a cross-origin a.claude.ai iframe, so subframes adopt the sheet from
// a script instead.
const adoptSheet = `(() => {
  if (window.__catppuccin) return;
  window.__catppuccin = true;
  const sheet = new CSSStyleSheet();
  sheet.replaceSync(${JSON.stringify(css)});
  document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
})()`;

app.on("web-contents-created", (_event, contents) => {
  contents.on("dom-ready", () => {
    if (isThemed(contents.getURL())) contents.insertCSS(css).catch(() => {});
  });

  contents.on("did-frame-finish-load", (_event, isMainFrame, processId, routingId) => {
    if (isMainFrame) return;
    const frame = webFrameMain.fromId(processId, routingId);
    if (frame && isThemed(frame.url)) frame.executeJavaScript(adoptSheet).catch(() => {});
  });
});

require("@main@");
