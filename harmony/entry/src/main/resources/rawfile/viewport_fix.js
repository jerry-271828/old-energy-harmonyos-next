// ============================================================
// betterxny HarmonyOS — viewport / safe-area fix
//   Goal: make sure the H5 page (a) declares viewport-fit=cover so
//   env(safe-area-inset-*) variables become resolvable, and (b)
//   actually consumes the top inset so its header buttons clear the
//   status bar in the immersive (expandSafeArea) WebView.
//
//   Runs via javaScriptOnDocumentStart — before the page's own scripts,
//   which is earlier than onPageBegin or onPageEnd.
// ============================================================
(function () {
  var DESIRED_FIT = 'viewport-fit=cover';
  var DEFAULT_CONTENT =
    'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes, ' + DESIRED_FIT;
  var STYLE_ID = '__bxny_safe_area_css__';

  function ensureViewport() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      // No tag — create one with sensible mobile defaults.
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      meta.setAttribute('content', DEFAULT_CONTENT);
      (document.head || document.documentElement).appendChild(meta);
      return true;
    }
    var current = meta.getAttribute('content') || '';
    if (current.indexOf('viewport-fit=cover') !== -1) {
      return false; // already configured
    }
    var next;
    if (/viewport-fit\s*=/.test(current)) {
      // Tag has some other viewport-fit value — replace it with cover.
      next = current.replace(/viewport-fit\s*=\s*[^,;\s]+/i, DESIRED_FIT);
    } else if (current.trim().length === 0) {
      next = DEFAULT_CONTENT;
    } else {
      // Preserve original content (page-set width/scale etc.); append.
      var sep = /[,;]\s*$/.test(current) ? ' ' : ', ';
      next = current + sep + DESIRED_FIT;
    }
    meta.setAttribute('content', next);
    return true;
  }

  function ensureSafeAreaCss() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    // padding-top on body is what the spec says will use env() once
    // viewport-fit=cover is in effect. We use !important so a page
    // rule like `body { padding: 0 }` doesn't undo us. We deliberately
    // leave left/right/bottom padding alone to avoid layout shifts on
    // pages that don't expect them.
    style.textContent =
      'body{padding-top:env(safe-area-inset-top)!important;' +
      'padding-top:constant(safe-area-inset-top)!important;' +
      'box-sizing:border-box!important;}';
    (document.head || document.documentElement).appendChild(style);
  }

  function apply() {
    try {
      var changed = ensureViewport();
      ensureSafeAreaCss();
      if (changed) {
        // Nudge layout engines that cache viewport dims.
        window.dispatchEvent(new Event('resize'));
      }
    } catch (e) {
      try { console.warn('[viewport_fix] failed:', e && e.message); } catch (_) {}
    }
  }

  // First pass — as early as document allows.
  apply();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', apply, { once: true });
  }

  // SPA defence: if the page later replaces <meta name="viewport"> or
  // mutates its content (some frameworks rewrite head on route change),
  // re-apply our preferences.
  function startObserver() {
    if (!document.head) {
      // head not parsed yet; try again on next microtask.
      setTimeout(startObserver, 30);
      return;
    }
    try {
      var obs = new MutationObserver(function (records) {
        for (var i = 0; i < records.length; i++) {
          var r = records[i];
          if (r.type === 'childList') {
            for (var j = 0; j < r.addedNodes.length; j++) {
              var n = r.addedNodes[j];
              if (n && n.nodeType === 1 && n.tagName === 'META' &&
                  n.getAttribute && n.getAttribute('name') === 'viewport') {
                apply();
                return;
              }
            }
          } else if (r.type === 'attributes' && r.target &&
                     r.target.tagName === 'META' &&
                     r.target.getAttribute &&
                     r.target.getAttribute('name') === 'viewport') {
            apply();
            return;
          }
        }
      });
      obs.observe(document.head, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['content', 'name']
      });
    } catch (e) {
      try { console.warn('[viewport_fix] observer failed:', e && e.message); } catch (_) {}
    }
  }
  startObserver();
})();
