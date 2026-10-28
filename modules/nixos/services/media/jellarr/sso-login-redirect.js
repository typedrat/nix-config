// Sends anyone who reaches the web client's login page to the SSO provider
// instead. Loaded ahead of the client's own bundles so that it can see every
// route change.
//
// Left on the login form:
// - Jellyfin's native apps, which embed this client and define NativeShell.
// - `#/login?local`, for password logins.
// - A browser that was signed in earlier in this page's lifetime. Jellyfin
//   lands on the login page after a logout, and redirecting then would sign
//   the user straight back in through the provider's still-open session.
(function () {
  "use strict";

  var target = "../sso/OID/start/@provider@";

  function signedIn() {
    try {
      var credentials = JSON.parse(
        localStorage.getItem("jellyfin_credentials") || "{}",
      );
      return (credentials.Servers || []).some(function (server) {
        return !!server.AccessToken;
      });
    } catch (e) {
      return false;
    }
  }

  var wasSignedIn = signedIn();

  function check() {
    if (signedIn()) {
      wasSignedIn = true;
      return;
    }

    var hash = window.location.hash;
    if (!/^#\/login(\?|$)/.test(hash)) return;
    if (window.NativeShell || wasSignedIn) return;
    if (new URLSearchParams(hash.split("?")[1] || "").has("local")) return;

    window.location.replace(target);
  }

  // The client's router navigates with the History API, which never fires
  // hashchange.
  ["pushState", "replaceState"].forEach(function (name) {
    var original = history[name];
    history[name] = function () {
      var result = original.apply(this, arguments);
      check();
      return result;
    };
  });
  window.addEventListener("popstate", check);
  window.addEventListener("hashchange", check);
  // NativeShell is injected by a deferred script, so the first check waits
  // until deferred scripts have run.
  document.addEventListener("DOMContentLoaded", check);
})();
