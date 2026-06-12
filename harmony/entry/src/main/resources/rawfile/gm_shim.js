// ============================================================
// betterxny HarmonyOS — GM_* API shim
//   Equivalent to the Tampermonkey GM_* set used by main_pack.js / pack2.js.
//   Backed by ArkTS `AndroidBridge` exposed via Web.javaScriptProxy.
//
//   AndroidBridge methods (see entry/ets/bridge/AndroidBridge.ets):
//     getValue(key)        -> string (raw JSON; '' if absent)
//     setValue(key, value) -> void
//     showNotification(title, text) -> void
//     xhrRequest(reqJson)  -> void (resolves via window.__gm_xhr_resolve)
// ============================================================
(function () {
  if (window.__gm_injected) return;
  window.__gm_injected = true;
  window.unsafeWindow = window;

  function nativeBridge() {
    return (typeof AndroidBridge !== 'undefined') ? AndroidBridge : null;
  }

  // GM_addStyle: pure-JS style injection.
  window.GM_addStyle = function (css) {
    try {
      var s = document.createElement('style');
      s.type = 'text/css';
      s.textContent = css;
      (document.head || document.documentElement).appendChild(s);
      return s;
    } catch (e) {
      console.warn('[GM_addStyle] failed:', e);
      return null;
    }
  };

  // GM_setValue / GM_getValue: backed by ArkTS preferences.
  window.GM_setValue = function (key, value) {
    var b = nativeBridge();
    if (!b) return;
    try {
      b.setValue(String(key), JSON.stringify(value));
    } catch (e) {
      console.warn('[GM_setValue] failed:', e);
    }
  };

  window.GM_getValue = function (key, defaultValue) {
    var b = nativeBridge();
    if (!b) return defaultValue;
    try {
      var raw = b.getValue(String(key));
      if (raw === null || raw === undefined || raw === '') return defaultValue;
      try { return JSON.parse(raw); }
      catch (_) { return raw; }
    } catch (e) {
      console.warn('[GM_getValue] failed:', e);
      return defaultValue;
    }
  };

  window.GM_deleteValue = function (key) {
    var b = nativeBridge();
    if (!b) return;
    try { b.setValue(String(key), ''); } catch (e) { /* ignore */ }
  };

  window.GM_listValues = function () { return []; };

  // GM_notification: ArkTS native notification.
  window.GM_notification = function (details, ondone) {
    var b = nativeBridge();
    var title = '';
    var text = '';
    if (typeof details === 'string') {
      text = details;
    } else if (details && typeof details === 'object') {
      title = details.title || '';
      text = details.text || '';
    }
    try {
      if (b) b.showNotification(title, text);
    } catch (e) {
      console.warn('[GM_notification] failed:', e);
    }
    if (typeof ondone === 'function') {
      try { ondone(); } catch (_) { /* ignore */ }
    }
  };

  // GM_xmlhttpRequest: prefer native bridge (no CORS); fall back to fetch().
  window.__gm_xhr_cbs = window.__gm_xhr_cbs || {};
  var __xhr_seq = 0;

  function fallbackFetch(d, id) {
    delete window.__gm_xhr_cbs[id];
    var init = {
      method: d.method || 'GET',
      headers: d.headers || {},
      credentials: 'include'
    };
    if (d.data !== undefined && d.data !== null) {
      init.body = d.data;
    }
    var timedOut = false;
    var timer = null;
    if (d.timeout && d.timeout > 0) {
      timer = setTimeout(function () {
        timedOut = true;
        if (typeof d.ontimeout === 'function') {
          try { d.ontimeout(); } catch (_) { /* ignore */ }
        }
      }, d.timeout);
    }
    fetch(d.url, init).then(function (res) {
      return res.text().then(function (text) {
        if (timedOut) return;
        if (timer) clearTimeout(timer);
        if (typeof d.onload === 'function') {
          try {
            d.onload({
              status: res.status,
              statusText: res.statusText || '',
              responseText: text,
              response: text,
              responseHeaders: '',
              finalUrl: res.url || d.url
            });
          } catch (_) { /* ignore */ }
        }
      });
    }).catch(function (err) {
      if (timedOut) return;
      if (timer) clearTimeout(timer);
      if (typeof d.onerror === 'function') {
        try { d.onerror({ error: String(err && err.message || err) }); }
        catch (_) { /* ignore */ }
      }
    });
  }

  window.GM_xmlhttpRequest = function (details) {
    var d = details || {};
    var id = 'xhr_' + (++__xhr_seq) + '_' + Date.now();
    window.__gm_xhr_cbs[id] = d;
    var b = nativeBridge();
    if (b && typeof b.xhrRequest === 'function') {
      try {
        b.xhrRequest(JSON.stringify({
          id: id,
          url: d.url,
          method: d.method || 'GET',
          headers: d.headers || {},
          data: (d.data === undefined ? null : d.data),
          timeout: d.timeout || 0,
          responseType: d.responseType || 'text'
        }));
        return { abort: function () { delete window.__gm_xhr_cbs[id]; } };
      } catch (e) {
        console.warn('[GM_xmlhttpRequest] native bridge failed, fallback to fetch:', e);
      }
    }
    fallbackFetch(d, id);
    return { abort: function () { /* fetch fallback cannot abort */ } };
  };

  // ArkTS calls this when an http request completes/fails/times out.
  window.__gm_xhr_resolve = function (id, payload) {
    var cb = window.__gm_xhr_cbs[id];
    if (!cb) return;
    delete window.__gm_xhr_cbs[id];
    payload = payload || {};
    try {
      if (payload.timeout) {
        if (typeof cb.ontimeout === 'function') cb.ontimeout();
        return;
      }
      if (payload.error) {
        if (typeof cb.onerror === 'function') cb.onerror({ error: payload.error });
        return;
      }
      if (typeof cb.onload === 'function') {
        cb.onload({
          status: payload.status || 0,
          statusText: payload.statusText || '',
          responseText: payload.responseText || '',
          response: payload.responseText || '',
          responseHeaders: payload.responseHeaders || '',
          finalUrl: payload.finalUrl || ''
        });
      }
    } catch (_) { /* ignore */ }
  };

  // Tampermonkey misc helpers some scripts probe for.
  window.GM_info = {
    scriptHandler: 'BetterXNY-HarmonyOS',
    version: '1.0.0',
    script: { name: 'betterxny', version: '1.0.0' }
  };
  window.GM_registerMenuCommand = function () { /* no-op */ };
  window.GM_unregisterMenuCommand = function () { /* no-op */ };

  // Console heartbeat — handy for `hilog` log filtering.
  try { console.log('[betterxny] GM shim ready'); } catch (_) { /* ignore */ }
})();
