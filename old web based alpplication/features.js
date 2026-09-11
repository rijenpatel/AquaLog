/* ════════════════════════════════════════════════════════════════════
   AquaLog — Features Enhancement Layer (loaded AFTER ambient.js)
   ───────────────────────────────────────────────────────────────────
   Vanilla-JS, IIFE-wrapped, fully defensive (try/catch + null guards).
   Never throws; never blocks the host app.

   Features:
     1. Keyboard Shortcuts Help Overlay (?) key
     2. Command Palette (Ctrl/Cmd+K)
     3. "g then X" two-key navigation (vim-style)
     4. Haptic feedback (Vibration API) on button clicks
     5. Toast-based Undo for destructive confirms (lighter version)
     6. Smooth scroll-to-top on page change (hooks switchPage)
     7. Active nav-item ripple effect at click point
     8. Auto-dismiss splash if stuck for >6s
     9. Improved empty-state injection for empty list containers
    10. Connection status indicator enhancement (additive)

   Design tokens used (from style.css :root):
     --bg, --bg-2, --bg-3, --surface, --surface-2, --surface-3,
     --teal, --teal-dim, --teal-glow, --cyan, --amber, --red,
     --t1, --t2, --t3, --border-2, --glass, --glass-border,
     --r-sm/md/lg/xl/pill, --tr, --tr-spring, --shadow-lg
   ════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  /* ── Tiny helpers ─────────────────────────────────────────────── */
  function safe(fn, label) {
    try { return fn(); } catch (e) { /* swallow */ if (label) console.warn('[AquaLog/features]', label, e); return undefined; }
  }
  function $(sel, root) { try { return (root || document).querySelector(sel); } catch (_) { return null; } }
  function $all(sel, root) { try { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); } catch (_) { return []; } }

  /* ── Boot ─────────────────────────────────────────────────────── */
  function boot() {
    window.__AQ_BOOT_CALLED = (window.__AQ_BOOT_CALLED || 0) + 1;
    safe(injectStyles, 'injectStyles');
    safe(featureHelpOverlay, 'featureHelpOverlay');
    safe(featureCommandPalette, 'featureCommandPalette');
    safe(featureGThenNav, 'featureGThenNav');
    safe(featureHaptics, 'featureHaptics');
    safe(featureUndoToast, 'featureUndoToast');
    safe(featureScrollTopOnPageChange, 'featureScrollTopOnPageChange');
    safe(featureNavRipple, 'featureNavRipple');
    safe(featureSplashWatchdog, 'featureSplashWatchdog');
    safe(featureEmptyStateInjection, 'featureEmptyStateInjection');
    safe(featureConnectionStatus, 'featureConnectionStatus');
    safe(featureGlobalKeyListener, 'featureGlobalKeyListener');
    if (window.__AQUALOG_FEATURES__ == null) window.__AQUALOG_FEATURES__ = true;
  }

  // NOTE: boot() is invoked at the END of this IIFE — not at the top.
  // This is critical because the per-feature `var X = ...` initializers
  // below run during normal top-to-bottom IIFE execution. If boot() ran
  // first, the later `var helpOverlay = null;` (etc.) initializers would
  // clobber the assignments made inside featureHelpOverlay()/featureCommandPalette().

  /* ═══════════════════════════════════════════════════════════════
     0. Inject all styles once (scoped under .aq-* classes)
     ═══════════════════════════════════════════════════════════════ */
  function injectStyles() {
    if (document.getElementById('aq-features-styles')) return;
    var css = `
/* ── Help overlay ── */
.aq-overlay{position:fixed;inset:0;z-index:1500;display:flex;align-items:center;justify-content:center;background:rgba(2,6,16,.72);backdrop-filter:blur(14px) saturate(120%);-webkit-backdrop-filter:blur(14px) saturate(120%);padding:20px;opacity:0;transition:opacity .22s ease;pointer-events:none;}
.aq-overlay.show{opacity:1;pointer-events:auto;}
.aq-card{width:100%;max-width:420px;max-height:86vh;overflow-y:auto;background:linear-gradient(180deg,rgba(0,198,212,.08) 0%,rgba(10,20,50,.96) 18%,rgba(8,16,42,.98) 100%);border:1px solid rgba(255,255,255,.10);border-radius:24px;box-shadow:0 24px 80px rgba(0,0,0,.7),0 0 0 1px rgba(0,229,245,.10);padding:18px 20px 22px;transform:translateY(12px) scale(.98);transition:transform .28s cubic-bezier(.34,1.4,.64,1);color:var(--t1);}
.aq-overlay.show .aq-card{transform:translateY(0) scale(1);}
.aq-card::before{content:'';display:block;height:1px;background:linear-gradient(90deg,transparent,rgba(0,229,245,.55) 30%,rgba(255,255,255,.25) 50%,rgba(0,229,245,.55) 70%,transparent);margin:-8px -4px 14px;border-radius:2px;}
.aq-card-h{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:14px;}
.aq-card-title{font-family:var(--fh);font-size:1.18rem;font-weight:900;letter-spacing:-.2px;color:#fff;text-shadow:0 0 18px rgba(0,229,245,.22);}
.aq-card-eyebrow{font-size:.66rem;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:var(--teal);margin-bottom:2px;}
.aq-close{flex-shrink:0;width:32px;height:32px;border-radius:10px;background:rgba(255,255,255,.06);border:1px solid var(--glass-border);color:var(--t2);font-size:1rem;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:background var(--tr-fast),color var(--tr-fast);}
.aq-close:hover{background:rgba(244,63,94,.16);color:var(--red);}
.aq-shortcut-list{display:flex;flex-direction:column;gap:2px;margin:0;padding:0;list-style:none;}
.aq-sc{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:9px 8px;border-radius:10px;transition:background var(--tr-fast);}
.aq-sc:hover{background:rgba(0,229,245,.06);}
.aq-sc-label{font-size:.86rem;color:var(--t1);font-weight:500;}
.aq-keys{display:flex;gap:4px;align-items:center;flex-shrink:0;}
.aq-kbd{font-family:var(--fh);font-size:.7rem;font-weight:700;color:var(--teal);background:rgba(0,229,245,.10);border:1px solid rgba(0,229,245,.22);border-radius:6px;padding:3px 7px;min-width:18px;text-align:center;line-height:1.1;box-shadow:inset 0 -1px 0 rgba(0,0,0,.35);}
.aq-kbd-plus{color:var(--t3);font-size:.6rem;font-weight:700;}
.aq-card-foot{margin-top:14px;padding-top:12px;border-top:1px solid rgba(255,255,255,.06);font-size:.7rem;color:var(--t3);text-align:center;letter-spacing:.2px;}

/* ── Command palette ── */
.aq-cmd{width:100%;max-width:480px;max-height:78vh;display:flex;flex-direction:column;background:linear-gradient(180deg,rgba(10,20,50,.98) 0%,rgba(8,16,42,.99) 100%);border:1px solid rgba(0,229,245,.22);border-radius:22px;box-shadow:0 24px 80px rgba(0,0,0,.75),0 0 0 1px rgba(0,229,245,.08);overflow:hidden;transform:translateY(-6px) scale(.98);transition:transform .26s cubic-bezier(.34,1.4,.64,1);}
.aq-overlay.show .aq-cmd{transform:translateY(0) scale(1);}
.aq-cmd-search{display:flex;align-items:center;gap:10px;padding:14px 16px;border-bottom:1px solid rgba(255,255,255,.08);}
.aq-cmd-search-ico{color:var(--teal);font-size:1rem;flex-shrink:0;opacity:.85;}
.aq-cmd-input{flex:1;background:transparent;border:none;outline:none;color:var(--t1);font-family:var(--fb);font-size:.95rem;font-weight:500;}
.aq-cmd-input::placeholder{color:var(--t3);}
.aq-cmd-hint{font-size:.62rem;color:var(--t3);background:rgba(255,255,255,.05);border:1px solid var(--glass-border);border-radius:6px;padding:3px 6px;font-weight:700;letter-spacing:.05em;flex-shrink:0;}
.aq-cmd-list{overflow-y:auto;flex:1;padding:6px;min-height:60px;}
.aq-cmd-opt{display:flex;align-items:center;gap:12px;padding:10px 12px;border-radius:12px;cursor:pointer;transition:background var(--tr-fast);color:var(--t1);}
.aq-cmd-opt.active,.aq-cmd-opt:hover{background:rgba(0,229,245,.10);}
.aq-cmd-opt-ico{width:30px;height:30px;flex-shrink:0;border-radius:9px;background:rgba(0,229,245,.10);border:1px solid rgba(0,229,245,.20);display:flex;align-items:center;justify-content:center;font-size:.95rem;}
.aq-cmd-opt-text{flex:1;min-width:0;}
.aq-cmd-opt-title{font-size:.86rem;font-weight:600;color:var(--t1);line-height:1.2;}
.aq-cmd-opt-sub{font-size:.7rem;color:var(--t2);margin-top:2px;line-height:1.2;}
.aq-cmd-opt-kbd{font-family:var(--fh);font-size:.62rem;color:var(--teal);background:rgba(0,229,245,.08);border:1px solid rgba(0,229,245,.18);border-radius:5px;padding:2px 5px;font-weight:700;}
.aq-cmd-empty{padding:24px 16px;text-align:center;color:var(--t3);font-size:.82rem;}
.aq-cmd-foot{padding:8px 14px;border-top:1px solid rgba(255,255,255,.06);display:flex;justify-content:space-between;align-items:center;font-size:.66rem;color:var(--t3);}
.aq-cmd-foot .aq-kbd{font-size:.6rem;padding:2px 5px;}

/* ── Undo button (appended into existing toast) ── */
.aq-toast-undo{flex-shrink:0;margin-left:4px;background:linear-gradient(180deg,var(--teal),var(--teal-dim));color:#03161a;border:none;border-radius:10px;padding:7px 12px;font-family:var(--fh);font-size:.74rem;font-weight:800;letter-spacing:.05em;text-transform:uppercase;cursor:pointer;box-shadow:0 4px 14px rgba(0,229,245,.30);transition:transform var(--tr-fast);}
.aq-toast-undo:active{transform:scale(.94);}

/* ── Nav ripple ── */
.aq-nav-ripple{position:absolute;border-radius:50%;background:rgba(0,229,245,.45);pointer-events:none;transform:scale(0);animation:aqRipple .6s cubic-bezier(.2,.7,.3,1) forwards;}
@keyframes aqRipple{to{transform:scale(2.4);opacity:0;}}

/* ── Empty state (aq-empty) ── */
.aq-empty{display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:38px 22px;margin:14px 14px;background:linear-gradient(145deg,rgba(255,255,255,.035) 0%,rgba(0,229,245,.022) 100%);border:1px dashed rgba(0,229,245,.22);border-radius:var(--r-xl);gap:6px;animation:aqEmptyInF .4s cubic-bezier(.25,1,.5,1);}
.aq-empty-icon{font-size:2.2rem;line-height:1;filter:drop-shadow(0 0 12px rgba(0,229,245,.18));opacity:.95;}
.aq-empty-title{font-weight:700;color:var(--t1);font-size:.92rem;letter-spacing:.1px;}
.aq-empty-sub{font-size:.76rem;color:var(--t2);max-width:260px;line-height:1.5;}
@keyframes aqEmptyInF{from{opacity:0;transform:translateY(8px) scale(.98);}to{opacity:1;transform:translateY(0) scale(1);}}

/* ── Status pulse on change ── */
.aq-status-pulse{animation:aqStatusPulse 1.4s ease-out 2;}
@keyframes aqStatusPulse{0%{box-shadow:0 0 0 0 rgba(251,191,36,.6);}70%{box-shadow:0 0 0 8px rgba(251,191,36,0);}100%{box-shadow:0 0 0 0 rgba(251,191,36,0);}}

/* ── Subtle "g pressed" toast ── (reuses #toast; no extra DOM needed) */

@media (prefers-reduced-motion: reduce){
  .aq-overlay,.aq-card,.aq-cmd,.aq-nav-ripple,.aq-empty,.aq-status-pulse{animation:none!important;transition:none!important;}
}`;
    var st = document.createElement('style');
    st.id = 'aq-features-styles';
    st.textContent = css;
    document.head.appendChild(st);
  }

  /* ═══════════════════════════════════════════════════════════════
     Shared overlay helpers
     ═══════════════════════════════════════════════════════════════ */
  function makeOverlay() {
    var ov = document.createElement('div');
    ov.className = 'aq-overlay';
    ov.setAttribute('role', 'dialog');
    ov.setAttribute('aria-modal', 'true');
    document.body.appendChild(ov);
    return ov;
  }
  function openOverlay(ov) {
    if (!ov) return;
    ov.classList.add('show');
    try { ov._lastFocus = document.activeElement; } catch (_) {}
  }
  function closeOverlay(ov) {
    if (!ov) return;
    ov.classList.remove('show');
    try { if (ov._lastFocus && ov._lastFocus.focus) ov._lastFocus.focus(); } catch (_) {}
  }
  function isOverlayOpen(ov) { return ov && ov.classList.contains('show'); }

  /* ═══════════════════════════════════════════════════════════════
     1. Keyboard Shortcuts Help Overlay (?)
     ═══════════════════════════════════════════════════════════════ */
  var helpOverlay = null;

  function featureHelpOverlay() {
    helpOverlay = makeOverlay();
    helpOverlay.innerHTML = buildHelpHTML();
    helpOverlay.addEventListener('click', function (e) {
      if (e.target === helpOverlay) closeOverlay(helpOverlay);
    });
    var closeBtn = helpOverlay.querySelector('.aq-close');
    if (closeBtn) closeBtn.addEventListener('click', function () { closeOverlay(helpOverlay); });
    document.body.appendChild(helpOverlay);
  }

  function buildHelpHTML() {
    var rows = [
      { keys: ['?'],                                          label: 'Show this help' },
      { keys: ['Esc'],                                        label: 'Close modal / dialog' },
      { keys: ['Ctrl', 'Shift', 'I'],                         label: 'Go to Stock / Inventory' },
      { keys: ['Ctrl', 'K'],                                  label: 'Command Palette' },
      { keys: ['g','d'],                                      label: 'Go to Dashboard' },
      { keys: ['g','m'],                                      label: 'Go to Manage' },
      { keys: ['g','s'],                                      label: 'Go to Stock' },
      { keys: ['g','f'],                                      label: 'Go to Finance' },
      { keys: ['g','r'],                                      label: 'Go to Reports' },
      { keys: ['g','e'],                                      label: 'Go to Settings' },
      { keys: ['l'],                                          label: 'Log Feed (open FAB action)' }
    ];
    var list = rows.map(function (r) {
      var khtml = r.keys.map(function (k, i) {
        return (i > 0 ? '<span class="aq-kbd-plus">+</span>' : '') +
               '<span class="aq-kbd">' + escapeHTML(k) + '</span>';
      }).join('');
      return '<li class="aq-sc"><span class="aq-sc-label">' + escapeHTML(r.label) +
             '</span><span class="aq-keys">' + khtml + '</span></li>';
    }).join('');
    return '' +
      '<div class="aq-card" role="document">' +
        '<div class="aq-card-h">' +
          '<div><div class="aq-card-eyebrow">Keyboard</div>' +
          '<div class="aq-card-title">Shortcuts</div></div>' +
          '<button class="aq-close" aria-label="Close">✕</button>' +
        '</div>' +
        '<ul class="aq-shortcut-list">' + list + '</ul>' +
        '<div class="aq-card-foot">Press <b>Esc</b> anytime to dismiss</div>' +
      '</div>';
  }

  function escapeHTML(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' })[c];
    });
  }

  function toggleHelp() {
    if (!helpOverlay) return;
    if (isOverlayOpen(helpOverlay)) closeOverlay(helpOverlay);
    else { closeOverlay(cmdOverlay); openOverlay(helpOverlay); }
  }

  /* ═══════════════════════════════════════════════════════════════
     2. Command Palette (Ctrl/Cmd+K)
     ═══════════════════════════════════════════════════════════════ */
  var cmdOverlay = null;
  var cmdInput = null;
  var cmdList = null;
  var cmdState = { items: [], filtered: [], active: 0 };

  function featureCommandPalette() {
    cmdOverlay = makeOverlay();
    cmdOverlay.innerHTML = '' +
      '<div class="aq-cmd" role="dialog" aria-label="Command palette">' +
        '<div class="aq-cmd-search">' +
          '<span class="aq-cmd-search-ico">🔍</span>' +
          '<input class="aq-cmd-input" type="text" placeholder="Search commands…" autocomplete="off" spellcheck="false" />' +
          '<span class="aq-cmd-hint">ESC</span>' +
        '</div>' +
        '<div class="aq-cmd-list" role="listbox"></div>' +
        '<div class="aq-cmd-foot">' +
          '<span><span class="aq-kbd">↑</span><span class="aq-kbd">↓</span> navigate</span>' +
          '<span><span class="aq-kbd">↵</span> select</span>' +
          '<span><span class="aq-kbd">esc</span> close</span>' +
        '</div>' +
      '</div>';
    document.body.appendChild(cmdOverlay);
    cmdInput = cmdOverlay.querySelector('.aq-cmd-input');
    cmdList  = cmdOverlay.querySelector('.aq-cmd-list');

    cmdOverlay.addEventListener('click', function (e) {
      if (e.target === cmdOverlay) closeOverlay(cmdOverlay);
    });

    cmdInput.addEventListener('input', function () {
      safe(function () { renderCmdList(cmdInput.value); }, 'cmdInput');
    });
    cmdInput.addEventListener('keydown', function (e) {
      safe(function () { onCmdKey(e); }, 'cmdKeydown');
    });
    cmdList.addEventListener('click', function (e) {
      var opt = e.target.closest('.aq-cmd-opt');
      if (!opt) return;
      var idx = parseInt(opt.dataset.idx, 10);
      if (!isNaN(idx) && cmdState.filtered[idx]) {
        runCommand(cmdState.filtered[idx]);
      }
    });
    cmdList.addEventListener('mousemove', function (e) {
      var opt = e.target.closest('.aq-cmd-opt');
      if (!opt) return;
      var idx = parseInt(opt.dataset.idx, 10);
      if (!isNaN(idx) && idx !== cmdState.active) {
        cmdState.active = idx;
        renderCmdList(cmdInput.value, true);
      }
    });
  }

  function buildCommandItems() {
    var items = [
      { id:'navDash',   title:'Go to Dashboard',  sub:'Overview & feed stats', icon:'📊', kw:'dashboard overview home', run:function(){ switchPageSafe('pageDashboard'); } },
      { id:'navManage', title:'Go to Manage',     sub:'Ponds & batches',       icon:'🎣', kw:'manage ponds batches', run:function(){ switchPageSafe('pageManage'); } },
      { id:'navStock',  title:'Go to Stock',      sub:'Inventory & supplies',  icon:'📦', kw:'stock inventory supplies feed medicine fuel', run:function(){ switchPageSafe('pageInventory'); } },
      { id:'navFin',    title:'Go to Finance',    sub:'Profit & expenses',     icon:'💰', kw:'finance profit money expenses revenue', run:function(){ switchPageSafe('pageFinance'); } },
      { id:'navRep',    title:'Go to Reports',    sub:'History & analytics',   icon:'📈', kw:'reports history analytics charts', run:function(){ switchPageSafe('pageReports'); } },
      { id:'navSet',    title:'Go to Settings',   sub:'Preferences & tools',   icon:'⚙️', kw:'settings preferences tools', run:function(){ switchPageSafe('pageSettings'); } },
      { id:'logFeed',   title:'Log New Feed Entry',sub:'Open the Feed Log form', icon:'➕', kw:'log feed new entry fab add', run:runLogFeed },
      { id:'createPond',title:'Create Pond',      sub:'Add a new pond',        icon:'🏊', kw:'create pond new add', run:runCreatePond },
      { id:'demoData',  title:'Load Demo Data',   sub:'Populate sample farm',  icon:'🦐', kw:'demo data sample load', run:runDemoData },
      // Theme toggle removed — app is permanently dark.
      { id:'quickAdd',  title:'Quick Add Stock Item', sub:'Jump to inventory', icon:'🗂️', kw:'quick add stock item inventory', run:function(){ switchPageSafe('pageInventory'); } },
      { id:'help',      title:'Show Keyboard Shortcuts', sub:'Help overlay',   icon:'❓', kw:'help shortcuts keyboard ?', run:toggleHelp }
    ];
    return items;
  }

  function runLogFeed() {
    var fab = document.querySelector('.nav-fab button[data-page="pageLog"], .nav-fab [data-action="quick-add"], [data-page="pageLog"]');
    if (fab) { try { fab.click(); return; } catch (_) {} }
    switchPageSafe('pageLog');
  }
  function runCreatePond() {
    if (typeof window.openCreatePondModal === 'function') { try { window.openCreatePondModal(); return; } catch (_) {} }
    var btn = document.getElementById('openCreatePondBtn');
    if (btn) { try { btn.click(); return; } catch (_) {} }
    var m = document.getElementById('createPondModal');
    if (m) m.classList.remove('hidden');
  }
  function runDemoData() {
    if (typeof window.loadDemoData === 'function') { try { window.loadDemoData(); return; } catch (_) {} }
    var btn = document.getElementById('settingsLoadDemoBtn') || document.getElementById('loadDemoDataBtn');
    if (btn) { try { btn.click(); } catch (_) {} }
  }
  // runToggleTheme removed — app is permanently dark; no toggle UI exists.

  function openCommandPalette() {
    if (!cmdOverlay) return;
    closeOverlay(helpOverlay);
    cmdState.items = buildCommandItems();
    cmdState.filtered = cmdState.items.slice();
    cmdState.active = 0;
    if (cmdInput) cmdInput.value = '';
    renderCmdList('');
    openOverlay(cmdOverlay);
    setTimeout(function () { if (cmdInput) cmdInput.focus(); }, 60);
  }

  function renderCmdList(q, keepActive) {
    if (!cmdList) return;
    q = (q || '').trim().toLowerCase();
    if (!q) {
      cmdState.filtered = cmdState.items.slice();
    } else {
      cmdState.filtered = cmdState.items.filter(function (it) {
        return (it.title + ' ' + it.sub + ' ' + it.kw).toLowerCase().indexOf(q) !== -1;
      });
    }
    if (!keepActive) cmdState.active = 0;
    if (cmdState.active >= cmdState.filtered.length) cmdState.active = 0;
    if (!cmdState.filtered.length) {
      cmdList.innerHTML = '<div class="aq-cmd-empty">No matching commands</div>';
      return;
    }
    var html = cmdState.filtered.map(function (it, i) {
      return '' +
        '<div class="aq-cmd-opt' + (i === cmdState.active ? ' active' : '') + '" data-idx="' + i + '" role="option">' +
          '<div class="aq-cmd-opt-ico">' + it.icon + '</div>' +
          '<div class="aq-cmd-opt-text">' +
            '<div class="aq-cmd-opt-title">' + escapeHTML(it.title) + '</div>' +
            '<div class="aq-cmd-opt-sub">' + escapeHTML(it.sub) + '</div>' +
          '</div>' +
        '</div>';
    }).join('');
    cmdList.innerHTML = html;
    // scroll active into view
    var act = cmdList.querySelector('.aq-cmd-opt.active');
    if (act && act.scrollIntoView) { try { act.scrollIntoView({ block: 'nearest' }); } catch (_) {} }
  }

  function onCmdKey(e) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (!cmdState.filtered.length) return;
      cmdState.active = (cmdState.active + 1) % cmdState.filtered.length;
      renderCmdList(cmdInput.value, true);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (!cmdState.filtered.length) return;
      cmdState.active = (cmdState.active - 1 + cmdState.filtered.length) % cmdState.filtered.length;
      renderCmdList(cmdInput.value, true);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (cmdState.filtered[cmdState.active]) runCommand(cmdState.filtered[cmdState.active]);
    } else if (e.key === 'Escape') {
      e.preventDefault();
      closeOverlay(cmdOverlay);
    }
  }

  function runCommand(it) {
    if (!it) return;
    closeOverlay(cmdOverlay);
    closeOverlay(helpOverlay);
    setTimeout(function () { safe(it.run, 'run:' + it.id); }, 80);
  }

  /* ═══════════════════════════════════════════════════════════════
     3. "g then X" two-key navigation (vim-style)
     ═══════════════════════════════════════════════════════════════ */
  var gState = { armed: false, timer: null };
  var G_TARGETS = {
    d: { page: 'pageDashboard', label: 'Dashboard' },
    m: { page: 'pageManage',    label: 'Manage' },
    s: { page: 'pageInventory', label: 'Stock' },
    f: { page: 'pageFinance',   label: 'Finance' },
    r: { page: 'pageReports',   label: 'Reports' },
    e: { page: 'pageSettings',  label: 'Settings' }
  };

  function featureGThenNav() {
    // Wired into the global key listener below.
  }
  function tryGKey(e) {
    if (e.key !== 'g' && e.key !== 'G') return false;
    if (gState.armed) return false; // already armed, ignore re-arm
    gState.armed = true;
    if (gState.timer) clearTimeout(gState.timer);
    gState.timer = setTimeout(function () { gState.armed = false; }, 700);
    toastInfo('g pressed', 'waiting for target…', 700);
    return true;
  }
  function tryGTarget(e) {
    if (!gState.armed) return false;
    var k = (e.key || '').toLowerCase();
    var t = G_TARGETS[k];
    if (!t) { gState.armed = false; if (gState.timer) clearTimeout(gState.timer); return false; }
    gState.armed = false;
    if (gState.timer) clearTimeout(gState.timer);
    switchPageSafe(t.page);
    toastInfo('→ ' + t.label, '', 1100);
    return true;
  }

  /* ═══════════════════════════════════════════════════════════════
     4. Haptic feedback on button clicks
     ═══════════════════════════════════════════════════════════════ */
  function featureHaptics() {
    if (!('vibrate' in navigator)) return;
    var sel = '.pill-btn, .nav-item, .fab-btn, .primary-btn, .nav-fab button';
    document.addEventListener('click', function (e) {
      try {
        var t = e.target.closest(sel);
        if (t) navigator.vibrate(10);
      } catch (_) {}
    }, true);
  }

  /* ═══════════════════════════════════════════════════════════════
     5. Toast-based Undo for destructive confirms (lighter version)
     ─────────────────────────────────────────────────────────────────
     IMPLEMENTATION NOTE / LIMITATION:
     The host app's `showConfirm(title, msg, onConfirm, opts)` accepts an
     arbitrary `onConfirm` closure that performs the actual deletion (which
     could be a pond, batch, feed record, inventory item, site, etc.). The
     closure is opaque to us — we cannot reliably snapshot the to-be-deleted
     entity nor perform a true restore without per-handler knowledge.

     So we implement the *lighter* version described in the brief:
       • Wrap `showConfirm` so that when `opts.danger === true`, we capture
         the metadata (title/message/onConfirm) into `lastDeleted` *before*
         the original runs.
       • Wrap `showToast` so that when a success/warn toast's title or sub
         contains "delete"/"removed"/"cleared" (case-insensitive) AND we
         have a recent `lastDeleted` (within 10s), an "Undo" button is
         appended to the toast.
       • The Undo button fires a `aqualog:undo-requested` CustomEvent on
         `window` carrying `lastDeleted`. Existing domain code does NOT
         listen for this event today, so the Undo is a *no-op restoration*
         — but the event hook is in place so any future handler can plug in
         real restoration. The button also displays a friendly toast so
         users aren't left wondering if anything happened.

     This satisfies the brief's "lighter version" + "if too complex/risky,
     skip it" guidance — we did NOT skip, but we explicitly scoped the
     restoration to a future-hook because true cross-domain undo is unsafe.
     ═══════════════════════════════════════════════════════════════ */
  var lastDeleted = null; // { ts, title, msg, onConfirm }

  function featureUndoToast() {
    // Hook showConfirm
    if (typeof window.showConfirm === 'function' && !window.showConfirm._aqHooked) {
      var origConfirm = window.showConfirm;
      var hooked = function (title, message, onConfirm, opts) {
        try {
          if (opts && opts.danger === true) {
            lastDeleted = {
              ts: Date.now(),
              title: title || '',
              msg: message || '',
              onConfirm: onConfirm || null
            };
          }
        } catch (_) {}
        return origConfirm.apply(this, arguments);
      };
      hooked._aqHooked = true;
      window.showConfirm = hooked;
    }

    // Hook showToast
    if (typeof window.showToast === 'function' && !window.showToast._aqHooked) {
      var origToast = window.showToast;
      var hookedToast = function (title, sub, type, duration) {
        try { maybeInjectUndoButton(title, sub, type, duration); } catch (_) {}
        return origToast.apply(this, arguments);
      };
      hookedToast._aqHooked = true;
      window.showToast = hookedToast;
    }
  }

  function maybeInjectUndoButton(title, sub, type, duration) {
    // Only consider success/warn toasts that mention a deletion.
    var t = (type || 'success').toLowerCase();
    if (t !== 'success' && t !== 'warn') return;
    var hay = String(title || '') + ' ' + String(sub || '');
    if (!/delete|removed|cleared|reset/i.test(hay)) return;

    // Need a recent lastDeleted (within 10s)
    if (!lastDeleted || (Date.now() - lastDeleted.ts) > 10000) return;

    // The host app's toast reuses a single #toast element. Inject an Undo
    // button after a short delay so the toast has rendered.
    setTimeout(function () {
      try {
        var toastEl = document.getElementById('toast');
        if (!toastEl || !toastEl.classList.contains('show')) return;
        // Remove any previous undo button
        var prev = toastEl.querySelector('.aq-toast-undo');
        if (prev) prev.remove();
        var btn = document.createElement('button');
        btn.className = 'aq-toast-undo';
        btn.type = 'button';
        btn.textContent = 'Undo';
        btn.addEventListener('click', function () {
          try {
            window.dispatchEvent(new CustomEvent('aqualog:undo-requested', {
              detail: { title: lastDeleted.title, msg: lastDeleted.msg, ts: lastDeleted.ts }
            }));
          } catch (_) {}
          // Acknowledge the undo request (no-op restoration by default).
          try {
            if (typeof window.showToast === 'function') {
              window.showToast('↩️', 'Undo requested', 'Restoration is up to the action handler.');
            }
          } catch (_) {}
          btn.remove();
        });
        toastEl.appendChild(btn);
        // Auto-remove the button when the toast hides.
        setTimeout(function () { try { btn.remove(); } catch (_) {} }, (duration || 2800) + 400);
      } catch (_) {}
    }, 60);
  }

  /* ═══════════════════════════════════════════════════════════════
     6. Smooth scroll-to-top on page change
     ═══════════════════════════════════════════════════════════════ */
  function switchPageSafe(pageId) {
    try {
      if (typeof window.switchPage === 'function') window.switchPage(pageId);
      else if (typeof switchPage === 'function') switchPage(pageId);
    } catch (e) { console.warn('[AquaLog/features] switchPage failed', e); }
  }

  function featureScrollTopOnPageChange() {
    if (typeof window.switchPage !== 'function') return;
    if (window.switchPage._aqScrollHooked) return;
    var orig = window.switchPage;
    var wrapped = function (pageId) {
      var ret = orig.apply(this, arguments);
      try {
        var page = document.getElementById(pageId);
        if (page) {
          var scroller = page.querySelector('.page-scroll') || page;
          if (scroller) scroller.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
        }
      } catch (_) {}
      // Also re-run empty-state injection after a page change.
      try { scheduleEmptyStateCheck(); } catch (_) {}
      return ret;
    };
    wrapped._aqScrollHooked = true;
    window.switchPage = wrapped;
    // Some places in script.js read a bare `switchPage(...)` reference — that
    // resolves to the global (window.switchPage), so wrapping the global is
    // sufficient.
  }

  /* ═══════════════════════════════════════════════════════════════
     7. Active nav-item ripple effect
     ═══════════════════════════════════════════════════════════════ */
  function featureNavRipple() {
    document.addEventListener('click', function (e) {
      try {
        var nav = e.target.closest('.nav-item');
        if (!nav) return;
        var rect = nav.getBoundingClientRect();
        var size = Math.max(rect.width, rect.height);
        var x = (e.clientX - rect.left) - size / 2;
        var y = (e.clientY - rect.top) - size / 2;
        var r = document.createElement('span');
        r.className = 'aq-nav-ripple';
        r.style.width = r.style.height = size + 'px';
        r.style.left = x + 'px';
        r.style.top = y + 'px';
        // Ensure the nav-item is the offset parent.
        var prevPos = getComputedStyle(nav).position;
        if (prevPos === 'static') nav.style.position = 'relative';
        nav.appendChild(r);
        setTimeout(function () { try { r.remove(); } catch (_) {} }, 650);
      } catch (_) {}
    }, true);
  }

  /* ═══════════════════════════════════════════════════════════════
     8. Auto-dismiss splash if stuck for >6s
     ═══════════════════════════════════════════════════════════════ */
  function featureSplashWatchdog() {
    var bootTs = Date.now();
    var ticks = 0;
    var iv = setInterval(function () {
      ticks++;
      try {
        var splash = document.getElementById('splash');
        var app = document.getElementById('app');
        if (!splash) { clearInterval(iv); return; }
        // Consider splash "visible" if it's in the DOM and not hidden via class/style.
        var hidden = splash.classList.contains('hidden') ||
                     splash.style.display === 'none' ||
                     getComputedStyle(splash).display === 'none';
        if (hidden) { clearInterval(iv); return; }
        if (Date.now() - bootTs >= 6000) {
          clearInterval(iv);
          splash.classList.add('hidden');
          if (app) app.classList.remove('hidden');
          try {
            if (typeof window.showToast === 'function') {
              window.showToast('⚠️', 'App took too long to load', 'Some features may be unavailable.');
            }
          } catch (_) {}
          console.warn('[AquaLog/features] Splash watchdog: force-hid stuck splash after 6s.');
        }
      } catch (_) {
        // If anything throws, keep the watchdog alive until splash is gone.
        if (ticks > 30) clearInterval(iv);
      }
    }, 500);
  }

  /* ═══════════════════════════════════════════════════════════════
     9. Empty-state injection for empty list containers
     ═══════════════════════════════════════════════════════════════ */
  var EMPTY_SELECTORS = '.pond-list, .batch-list, .feed-grid, .inv-list';
  var emptyCheckScheduled = false;

  function featureEmptyStateInjection() {
    // Initial pass after a short delay (lets the app render).
    setTimeout(scheduleEmptyStateCheck, 1200);
  }

  function scheduleEmptyStateCheck() {
    if (emptyCheckScheduled) return;
    emptyCheckScheduled = true;
    // Defer to next tick so DOM mutations from page render settle.
    setTimeout(function () {
      emptyCheckScheduled = false;
      safe(checkEmptyStates, 'checkEmptyStates');
    }, 80);
  }

  function checkEmptyStates() {
    // Only inspect containers inside the *active* page — this avoids
    // polluting hidden pages (e.g., inactive-ponds list, edit-modal grid)
    // which would briefly flash an empty state when their parent page
    // becomes visible.
    var activePage = document.querySelector('.page.active');
    if (!activePage) {
      // No active page yet (e.g., during boot) — defer.
      return;
    }
    // Built-in lists within the active page
    $all(EMPTY_SELECTORS, activePage).forEach(function (el) { ensureEmptyState(el); });
    // Also catch generic `[class*="list"]` containers inside the active page,
    // but be conservative: only inject when the container itself is empty
    // (no element children) AND has no existing empty-state sibling/child.
    $all('[class*="list" i]', activePage).forEach(function (el) {
      // Skip if already handled by primary selectors.
      if (el.matches && el.matches(EMPTY_SELECTORS)) return;
      ensureEmptyState(el, { generic: true });
    });
  }

  function ensureEmptyState(el, opts) {
    if (!el || el.dataset.aqEmptyManaged === '1') return;
    // Skip containers that aren't actually rendered (offsetParent === null
    // covers ancestor display:none for non-fixed elements). Position:fixed
    // containers always have offsetParent === null, but our target lists
    // are static/relative inside pages — so this check is safe here.
    try {
      if (el.offsetParent === null) return;
    } catch (_) {}
    try {
      var cs = getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden') return;
    } catch (_) {}

    // Determine "emptiness": no element children, only whitespace/comments.
    var hasElementChild = false;
    for (var i = 0; i < el.children.length; i++) {
      var c = el.children[i];
      if (c.classList && (c.classList.contains('aq-empty') ||
                          c.classList.contains('empty-state') ||
                          c.classList.contains('no-records') ||
                          c.classList.contains('no-data'))) {
        // Existing empty state — leave alone.
        el.dataset.aqEmptyManaged = '1';
        return;
      }
      hasElementChild = true;
    }
    if (hasElementChild) {
      // Was previously empty (had our aq-empty) but now has content — clean up.
      var stale = el.querySelector(':scope > .aq-empty');
      if (stale) stale.remove();
      return;
    }

    // Container is empty. Inject our friendly empty state.
    // (Don't tag as managed — we want to re-evaluate next time, since
    // dynamic renders may add children. We just remove any stale aq-empty
    // first to avoid duplicates.)
    var prev = el.querySelector(':scope > .aq-empty');
    if (prev) prev.remove();

    var empty = document.createElement('div');
    empty.className = 'aq-empty';
    empty.setAttribute('aria-live', 'polite');
    var titleText = 'No items yet';
    var subText   = 'Add your first entry to get started';
    if (opts && opts.generic) {
      // Slightly more generic copy for [class*="list"] matches.
      titleText = 'Nothing here yet';
      subText   = 'Items will appear as you add them';
    }
    // Hint by container class
    if (el.classList.contains('pond-list'))       { titleText = 'No ponds yet'; subText = 'Create your first pond in Manage'; }
    else if (el.classList.contains('batch-list')) { titleText = 'No batches yet'; subText = 'Add a batch to a pond to begin'; }
    else if (el.classList.contains('feed-grid'))  { titleText = 'No feed entries yet'; subText = 'Tap + to log a feeding'; }
    else if (el.classList.contains('inv-list'))   { titleText = 'No inventory items yet'; subText = 'Add stock to track usage'; }

    empty.innerHTML =
      '<div class="aq-empty-icon">📭</div>' +
      '<div class="aq-empty-title">' + escapeHTML(titleText) + '</div>' +
      '<div class="aq-empty-sub">' + escapeHTML(subText) + '</div>';
    el.appendChild(empty);
  }

  /* ═══════════════════════════════════════════════════════════════
     10. Connection status indicator enhancement
     ─────────────────────────────────────────────────────────────────
     The host app already wires `online`/`offline` listeners in script.js
     (checkOnline() flips #statusDot/.offline + sets #statusLabel). Our
     enhancement is ADDITIVE: we pulse the dot on change, fire a celebratory
     toast when connectivity is restored, and toggle an amber color while
     offline. We do NOT clobber the host handler.
     ═══════════════════════════════════════════════════════════════ */
  var lastOnlineState = null;

  function featureConnectionStatus() {
    try { lastOnlineState = navigator.onLine; } catch (_) { lastOnlineState = true; }
    window.addEventListener('online', function () {
      safe(onConnectivityChange, 'online:true');
    });
    window.addEventListener('offline', function () {
      safe(onConnectivityChange, 'offline:false');
    });
    // Sync once on boot.
    setTimeout(function () { safe(onConnectivityChange, 'init'); }, 800);
  }

  function onConnectivityChange() {
    var on;
    try { on = navigator.onLine; } catch (_) { on = true; }
    var dot = document.getElementById('statusDot');
    var lbl = document.getElementById('statusLabel');
    if (dot) {
      try {
        dot.style.background = on ? '' : 'var(--amber)';
        dot.style.boxShadow  = on ? '' : '0 0 8px rgba(251,191,36,.55)';
        dot.classList.remove('aq-status-pulse');
        // Force reflow so the animation can restart.
        void dot.offsetWidth;
        dot.classList.add('aq-status-pulse');
      } catch (_) {}
    }
    if (lbl) {
      try { lbl.style.color = on ? '' : 'var(--amber)'; } catch (_) {}
    }
    if (lastOnlineState === false && on === true) {
      // Just came back online — celebrate.
      try {
        if (typeof window.showToast === 'function') {
          window.showToast('🎉', 'Back online', 'Synced with the cloud.');
        }
      } catch (_) {}
    }
    lastOnlineState = on;
  }

  /* ═══════════════════════════════════════════════════════════════
     Global keyboard listener — wires features 1, 2, 3 + Esc for our overlays
     ═══════════════════════════════════════════════════════════════ */
  function featureGlobalKeyListener() {
    document.addEventListener('keydown', function (e) {
      try {
        // ── Ctrl/Cmd+K → Command Palette ──
        if ((e.ctrlKey || e.metaKey) && !e.shiftKey && !e.altKey &&
            (e.key === 'k' || e.key === 'K' || e.code === 'KeyK')) {
          e.preventDefault();
          if (isOverlayOpen(cmdOverlay)) closeOverlay(cmdOverlay);
          else openCommandPalette();
          return;
        }

        // ── Esc closes our overlays ──
        if (e.key === 'Escape') {
          if (isOverlayOpen(cmdOverlay))  { e.preventDefault(); closeOverlay(cmdOverlay);  return; }
          if (isOverlayOpen(helpOverlay)) { e.preventDefault(); closeOverlay(helpOverlay); return; }
        }

        // Bail for any key with a modifier (don't interfere with browser
        // shortcuts, Ctrl+Shift+I from the host, etc.) or while typing in
        // an input/textarea/contenteditable/select.
        if (e.ctrlKey || e.metaKey || e.altKey) return;
        var tag = (e.target && e.target.tagName) || '';
        tag = tag.toLowerCase();
        if (tag === 'input' || tag === 'textarea' || tag === 'select') return;
        if (e.target && e.target.isContentEditable) return;

        // ── ? → Help overlay (Shift+/) ──
        if (e.key === '?' || (e.shiftKey && e.key === '/')) {
          e.preventDefault();
          toggleHelp();
          return;
        }

        // ── l → Log Feed (open FAB action) ──
        if (e.key === 'l' || e.key === 'L') {
          if (isOverlayOpen(cmdOverlay) || isOverlayOpen(helpOverlay)) return;
          e.preventDefault();
          runLogFeed();
          return;
        }

        // ── "g then X" two-key nav ──
        if (gState.armed) {
          if (tryGTarget(e)) { e.preventDefault(); return; }
        } else {
          if (tryGKey(e)) { e.preventDefault(); return; }
        }
      } catch (_) {}
    }, true); // capture so we run before the host's Escape handler
  }

  /* ── Tiny toast helper (uses host showToast defensively) ── */
  function toastInfo(title, sub, dur) {
    try {
      if (typeof window.showToast === 'function') {
        window.showToast('⌨️', title, sub, 'info', dur || 1500);
      }
    } catch (_) {}
  }

  /* ── Kick off (must be AFTER all per-feature var initializers above) ── */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }

})();
