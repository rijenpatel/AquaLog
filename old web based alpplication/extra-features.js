/* ════════════════════════════════════════════════════════════════════
   AquaLog — Extra Features Layer (loaded AFTER features.js)
   ───────────────────────────────────────────────────────────────────
   Vanilla-JS, IIFE-wrapped, fully defensive (try/catch + null guards).
   Never throws; never blocks the host app.

   Features:
     A. Full Data Backup (JSON export of all localStorage domain keys)
     B. Feed Records CSV export
     C. Data Restore from JSON backup (with confirmation)
     D. Browser Notifications system (feed time, low stock, sampling due)
     E. Global Search overlay (Ctrl+/ or click search icon) — searches
        across ponds, batches, feed records, and inventory items
     F. "Quick Stats" floating widget on dashboard (today's feed, active
        batches count, low stock count) — tap to expand

   Design tokens used (from style.css :root):
     --bg, --bg-2, --bg-3, --surface, --surface-2, --surface-3,
     --teal, --teal-dim, --teal-glow, --cyan, --amber, --red, --green,
     --t1, --t2, --t3, --border-2, --glass, --glass-border,
     --r-sm/md/lg/xl/pill, --tr, --tr-spring, --shadow-lg
   ════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  /* ── Tiny helpers ─────────────────────────────────────────────── */
  function safe(fn, label) {
    try { return fn(); } catch (e) {
      if (label) console.warn('[AquaLog/extra]', label, e);
      return undefined;
    }
  }
  function $(id) { return document.getElementById(id); }
  function $all(sel, root) {
    try { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
    catch (_) { return []; }
  }

  /* ── Unified Periodic Checker Registry ──────────────────────────
     Instead of each feature creating its own setInterval, features
     register their re-inject function here. A single interval runs
     every 2.5s and calls all registered checkers. This reduces
     overhead from N intervals to 1.
  ═══════════════════════════════════════════════════════════════ */
  var periodicCheckers = [];
  var periodicStarted = false;
  function registerPeriodicCheck(fn, label) {
    if (typeof fn !== 'function') return;
    periodicCheckers.push({ fn: fn, label: label || 'unnamed' });
    // Start the unified interval on first registration
    if (!periodicStarted) {
      periodicStarted = true;
      setInterval(function () {
        for (var i = 0; i < periodicCheckers.length; i++) {
          try { periodicCheckers[i].fn(); } catch (e) { /* swallow */ }
        }
      }, 2500);
    }
  }
  function todayStr() {
    var d = new Date();
    var m = ('0' + (d.getMonth() + 1)).slice(-2);
    var day = ('0' + d.getDate()).slice(-2);
    return d.getFullYear() + '-' + m + '-' + day;
  }

  /* ── Dashboard Context Helper ───────────────────────────────────
     Single source of truth for what the dashboard is currently showing.
     Returns:
       { mode: 'farm' | 'batch',
         batch: batchObj | null,
         pond:  pondObj  | null,
         isCompleted: bool,
         hasPrerequisites: bool  // true only when sites + ponds + active batches all exist
       }
  ═══════════════════════════════════════════════════════════════ */
  function getDashboardContext() {
    var ctx = { mode: 'farm', batch: null, pond: null, isCompleted: false, hasPrerequisites: false };
    safe(function () {
      var sites  = JSON.parse(localStorage.getItem('al_sites')  || '[]') || [];
      var ponds  = JSON.parse(localStorage.getItem('al_ponds')  || '[]') || [];
      var batches = JSON.parse(localStorage.getItem('al_batches') || '[]') || [];
      var activeBatches = batches.filter(function (b) { return b && b.status === 'active'; });
      ctx.hasPrerequisites = sites.length > 0 && ponds.length > 0 && activeBatches.length > 0;

      var sel = document.getElementById('dashboardContextSelect');
      var val = sel ? sel.value : 'farm';
      if (val && val.indexOf('batch_') === 0) {
        var id = val.replace('batch_', '');
        var b = batches.filter(function (x) { return x.id === id; })[0];
        if (b) {
          ctx.mode = 'batch';
          ctx.batch = b;
          ctx.isCompleted = b.status === 'completed';
          ctx.pond = ponds.filter(function (p) { return p.id === b.pondId; })[0] || null;
        }
      }
    });
    return ctx;
  }

  /* ── Schema-aware feed record access ────────────────────────────
     Records use capitalised keys (Date/Time/PondId/BatchId) in script.js,
     but the old extra-features.js used lowercase (date/time/pondId/batchId).
     These helpers normalise so we can read either form safely.
  ═══════════════════════════════════════════════════════════════ */
  function recDate(r)  { return r.Date || r.date || ''; }
  function recTime(r)  { return r.Time || r.time || ''; }
  function recPondId(r){ return r.PondId || r.pondId || ''; }
  function recBatchId(r){return r.BatchId || r.batchId || ''; }
  function recQty(r)   {
    if (typeof r.totalQty === 'number') return r.totalQty;
    if (typeof r.total   === 'number') return r.total;
    // Real records store per-feed-size columns; sum them
    var s = 0;
    for (var i = 1; i <= 5; i++) s += parseFloat(r['Feed Size ' + i + ' Gram']) || 0;
    s += parseFloat(r['Other Feed Gram']) || 0;
    return s;
  }

  function parseTimeToHour(timeStr) {
    if (!timeStr) return -1;
    var m = String(timeStr).match(/(\d+):(\d+)\s*(AM|PM)?/i);
    if (!m) return -1;
    var h = parseInt(m[1], 10);
    var ap = m[3] ? m[3].toUpperCase() : null;
    if (ap === 'PM' && h !== 12) h += 12;
    if (ap === 'AM' && h === 12) h = 0;
    return h;
  }

  /* ── Domain storage keys (must match script.js KEYS) ─────────── */
  var DOMAIN_KEYS = [
    'al_records', 'al_ponds', 'al_batches', 'al_growth', 'al_hapa',
    'al_biomass', 'al_sampling', 'al_queue', 'al_inventory',
    'al_sites', 'al_weather_cache', 'al_weather_history',
    'al_inventory_thresholds', 'al_inventory_migrated_v1',
    'al_finance_expenses', 'al_finance_revenue', 'al_finance_prices',
    'al_water_quality', 'al_notif_settings',
    'al_feed_templates'
    // 'al_theme_pref' removed — app is permanently dark, no preference to persist
  ];

  /* ═══════════════════════════════════════════════════════════════
     A. DATA BACKUP — Export all domain keys as a single JSON file
     ═══════════════════════════════════════════════════════════════ */
  function exportFullBackup() {
    safe(function () {
      var backup = {
        _meta: {
          app: 'AquaLog',
          version: '2.1',
          exportedAt: new Date().toISOString(),
          keyCount: 0,
          totalBytes: 0
        }
      };
      var bytes = 0;
      DOMAIN_KEYS.forEach(function (k) {
        var raw = localStorage.getItem(k);
        if (raw !== null) {
          backup[k] = raw; // keep as string to preserve exact shape
          bytes += raw.length;
          backup._meta.keyCount++;
        }
      });
      backup._meta.totalBytes = bytes;

      var json = JSON.stringify(backup, null, 2);
      var blob = new Blob([json], { type: 'application/json;charset=utf-8;' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = 'aqualog-backup-' + todayStr() + '.json';
      document.body.appendChild(a);
      a.click();
      setTimeout(function () {
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }, 200);

      if (typeof window.showToast === 'function') {
        var kb = Math.round(bytes / 1024);
        window.showToast('📥', 'Backup Exported',
          backup._meta.keyCount + ' data keys · ' + kb + ' KB saved', 'success', 3200);
      }
    }, 'exportFullBackup');
  }

  /* ═══════════════════════════════════════════════════════════════
     B. FEED CSV EXPORT — al_records → CSV
     ═══════════════════════════════════════════════════════════════ */
  function escapeCsv(val) {
    if (val === null || val === undefined) return '';
    var s = String(val);
    if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }
  function exportFeedCsv() {
    safe(function () {
      var raw = localStorage.getItem('al_records');
      var records = [];
      try { records = raw ? JSON.parse(raw) : []; } catch (_) { records = []; }
      if (!Array.isArray(records) || records.length === 0) {
        if (typeof window.showToast === 'function') {
          window.showToast('⚠️', 'No Feed Records', 'There are no feed logs to export.', 'warn', 2800);
        }
        return;
      }

      // Build a lookup of pond names for richer CSV
      var pondMap = {};
      try {
        var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]');
        (ponds || []).forEach(function (p) { pondMap[p.id] = p.name || p.id; });
      } catch (_) {}

      var headers = ['Date', 'Time', 'Pond', 'Feed Size', 'Quantity (g)', 'Notes', 'Medicine'];
      var rows = records.map(function (r) {
        var sizes = [];
        if (r.qty) {
          Object.keys(r.qty).forEach(function (k) {
            if (r.qty[k] && parseFloat(r.qty[k]) > 0) sizes.push(k + ':' + r.qty[k]);
          });
        }
        return [
          r.date || '',
          r.time || '',
          pondMap[r.pondId] || r.pondId || '',
          sizes.join('; '),
          (r.totalQty || r.total || ''),
          (r.notes || ''),
          (r.med && r.med.name ? r.med.name + ' (' + (r.med.qty || '') + ')' : '')
        ];
      });

      var csv = [headers.map(escapeCsv).join(',')];
      rows.forEach(function (row) { csv.push(row.map(escapeCsv).join(',')); });
      var csvContent = csv.join('\r\n');

      var blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = 'aqualog-feed-records-' + todayStr() + '.csv';
      document.body.appendChild(a);
      a.click();
      setTimeout(function () {
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }, 200);

      if (typeof window.showToast === 'function') {
        window.showToast('📊', 'CSV Exported',
          records.length + ' feed records saved', 'success', 3000);
      }
    }, 'exportFeedCsv');
  }

  /* ═══════════════════════════════════════════════════════════════
     C. DATA RESTORE — Import JSON backup, replace all domain data
     ═══════════════════════════════════════════════════════════════ */
  function restoreFromBackup(file) {
    safe(function () {
      var status = $('aqRestoreStatus');
      var reader = new FileReader();
      reader.onload = function (e) {
        safe(function () {
          var data;
          try { data = JSON.parse(e.target.result); }
          catch (err) {
            showRestoreStatus(status, 'error', '❌ Invalid file: Not valid JSON.');
            return;
          }
          if (!data || typeof data !== 'object' || !data._meta || data._meta.app !== 'AquaLog') {
            showRestoreStatus(status, 'error', '❌ This is not an AquaLog backup file (missing _meta.app marker).');
            return;
          }

          // Use the host's confirm dialog if available, else native confirm
          var doRestore = function () {
            safe(function () {
              var restored = 0;
              // Clear existing domain keys first
              DOMAIN_KEYS.forEach(function (k) {
                try { localStorage.removeItem(k); } catch (_) {}
              });
              // Write each key present in the backup
              DOMAIN_KEYS.forEach(function (k) {
                if (data[k] !== undefined && data[k] !== null) {
                  try { localStorage.setItem(k, data[k]); restored++; } catch (_) {}
                }
              });
              showRestoreStatus(status, 'success',
                '✅ Restored ' + restored + ' data keys from backup dated ' +
                new Date(data._meta.exportedAt).toLocaleString() +
                '. Reloading the app…');
              if (typeof window.showToast === 'function') {
                window.showToast('✅', 'Restore Complete',
                  'Reloading app with restored data…', 'success', 2600);
              }
              setTimeout(function () { window.location.reload(); }, 1800);
            }, 'doRestore inner');
          };

          if (typeof window.showConfirm === 'function') {
            window.showConfirm(
              'Restore Backup?',
              'This will PERMANENTLY REPLACE all current data with the backup from ' +
              new Date(data._meta.exportedAt).toLocaleString() + ' (' +
              data._meta.keyCount + ' keys, ' + Math.round(data._meta.totalBytes / 1024) +
              ' KB). This cannot be undone.',
              doRestore,
              { icon: '📤', danger: true, confirmLabel: 'Restore Now', cancelLabel: 'Cancel' }
            );
          } else {
            if (confirm('Restore backup? This will REPLACE all current data.')) doRestore();
          }
        }, 'restoreFromBackup parse');
      };
      reader.onerror = function () {
        showRestoreStatus(status, 'error', '❌ Could not read the file.');
      };
      reader.readAsText(file);
    }, 'restoreFromBackup');
  }

  function showRestoreStatus(el, type, msg) {
    if (!el) return;
    el.style.display = 'block';
    if (type === 'error') {
      el.style.background = 'rgba(244,63,94,0.1)';
      el.style.border = '1px solid rgba(244,63,94,0.3)';
      el.style.color = 'var(--red)';
    } else {
      el.style.background = 'rgba(16,185,129,0.1)';
      el.style.border = '1px solid rgba(16,185,129,0.3)';
      el.style.color = 'var(--green)';
    }
    el.textContent = msg;
  }

  /* ═══════════════════════════════════════════════════════════════
     D. NOTIFICATIONS SYSTEM
     ═══════════════════════════════════════════════════════════════ */
  var Notif = {
    SETTINGS_KEY: 'al_notif_settings',
    feedTimes: ['7:00 AM', '11:00 AM', '4:00 PM', '7:00 PM'],
    feedTimes24: [7, 11, 16, 19],
    lastCheckKey: 'al_notif_last_check',

    getSettings: function () {
      try {
        return JSON.parse(localStorage.getItem(this.SETTINGS_KEY)) || {};
      } catch (_) { return {}; }
    },
    saveSettings: function (s) {
      try { localStorage.setItem(this.SETTINGS_KEY, JSON.stringify(s)); } catch (_) {}
    },
    requestPermission: function (cb) {
      if (!('Notification' in window)) { cb && cb('unsupported'); return; }
      if (Notification.permission === 'granted') { cb && cb('granted'); return; }
      if (Notification.permission === 'denied') { cb && cb('denied'); return; }
      Notification.requestPermission().then(function (p) { cb && cb(p); });
    },
    show: function (title, body, opts) {
      opts = opts || {};
      safe(function () {
        if (!('Notification' in window)) {
          // Fallback: in-app toast
          if (typeof window.showToast === 'function') {
            window.showToast('🔔', title, body, opts.type || 'info', 5000);
          }
          return;
        }
        if (Notification.permission === 'granted') {
          try {
            var n = new Notification(title, {
              body: body,
              icon: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 192 192"%3E%3Crect width="192" height="192" rx="32" fill="%230d1117"/%3E%3Ctext x="96" y="130" font-size="100" text-anchor="middle"%3E%F0%9F%A6%90%3C/text%3E%3C/svg%3E',
              tag: opts.tag || 'aqualog',
              silent: opts.silent || false
            });
            n.onclick = function () { window.focus(); n.close(); };
            setTimeout(function () { try { n.close(); } catch (_) {} }, 8000);
          } catch (_) {}
        }
        // Also always show in-app toast
        if (typeof window.showToast === 'function') {
          window.showToast('🔔', title, body, opts.type || 'info', 4500);
        }
      }, 'Notif.show');
    },

    /* Periodic checker — runs every 60s, looks for due events */
    startChecker: function () {
      var self = Notif;
      function check() {
        safe(function () {
          var s = self.getSettings();
          var now = new Date();
          var lastRaw = localStorage.getItem(self.lastCheckKey);
          var last = lastRaw ? new Date(parseInt(lastRaw, 10)) : new Date(0);
          var nowKey = now.getFullYear() + '-' + now.getMonth() + '-' + now.getDate() + '-' + now.getHours() + '-' + now.getMinutes();

          // Feed time reminders (only check at the top of each feed hour)
          if (s.feed && self.feedTimes24.indexOf(now.getHours()) !== -1 && now.getMinutes() < 2) {
            var timeIdx = self.feedTimes24.indexOf(now.getHours());
            self.show('🍽 Feed Time Reminder',
              'Time for the ' + self.feedTimes[timeIdx] + ' feeding session. Don\'t forget to log it!',
              { tag: 'feed-' + nowKey, type: 'info' });
          }

          // Low stock check (every 30 min)
          if (s.lowStock && (now.getTime() - last.getTime() > 30 * 60 * 1000)) {
            var lowCount = self.countLowStock();
            if (lowCount > 0) {
              self.show('📦 Low Stock Alert',
                lowCount + ' item(s) are running low. Check the Stock page to restock.',
                { tag: 'lowstock-' + todayStr(), type: 'warn' });
            }
          }

          // Sampling due check (once per day)
          if (s.sampling && now.getHours() === 9 && now.getMinutes() < 2) {
            var dueCount = self.countSamplingDue();
            if (dueCount > 0) {
              self.show('🔬 Sampling Due',
                dueCount + ' batch(es) are due for growth sampling today.',
                { tag: 'sampling-' + todayStr(), type: 'info' });
            }
          }

          localStorage.setItem(self.lastCheckKey, String(now.getTime()));
        }, 'Notif.check');
      }
      check(); // run once immediately
      setInterval(check, 60000);
    },

    countLowStock: function () {
      try {
        var inv = JSON.parse(localStorage.getItem('al_inventory') || '[]');
        var count = 0;
        (inv || []).forEach(function (t) {
          // crude heuristic: items with low current stock
          if (t && t.current !== undefined && t.threshold !== undefined) {
            if (parseFloat(t.current) <= parseFloat(t.threshold) && parseFloat(t.threshold) > 0) count++;
          }
        });
        return count;
      } catch (_) { return 0; }
    },

    countSamplingDue: function () {
      try {
        var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
        var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
        var count = 0;
        var today = new Date();
        (batches || []).forEach(function (b) {
          if (!b || b.completed) return;
          if (!b.startDate) return;
          var start = new Date(b.startDate);
          var doc = Math.floor((today - start) / (1000 * 60 * 60 * 24));
          // Sampling typically every 15 days
          if (doc > 0 && doc % 15 < 2) {
            // Check if a sampling entry exists in the last 2 days for this batch
            var hasRecent = (sampling || []).some(function (s) {
              if (s.batchId !== b.id) return false;
              var sd = new Date(s.date);
              return (today - sd) / (1000 * 60 * 60 * 24) < 2;
            });
            if (!hasRecent) count++;
          }
        });
        return count;
      } catch (_) { return 0; }
    }
  };

  function initNotifications() {
    safe(function () {
      var s = Notif.getSettings();
      // Initialize defaults
      if (Object.keys(s).length === 0) {
        s = { feed: false, lowStock: false, sampling: false };
        Notif.saveSettings(s);
      }

      var permNote = $('aqNotifPermissionNote');

      function paintToggle(toggleId, trackId, on) {
        var toggle = $(toggleId);
        if (toggle) toggle.checked = on;
        var track = $(trackId);
        if (track) {
          track.style.background = on ? 'linear-gradient(135deg, var(--teal), var(--teal-dim))' : '#d0d0d0';
          var thumb = track.querySelector('.toggle-thumb');
          if (thumb) thumb.style.transform = on ? 'translateX(24px)' : 'translateX(0)';
        }
      }

      // Paint initial states (re-runs safely each time, no listener stacking)
      paintToggle('aqNotifFeedToggle', 'aqNotifFeedTrack', !!s.feed);
      paintToggle('aqNotifLowStockToggle', 'aqNotifLowStockTrack', !!s.lowStock);
      paintToggle('aqNotifSamplingToggle', 'aqNotifSamplingTrack', !!s.sampling);

      function handleToggleChange(key, toggle, trackId) {
        var on = toggle.checked;
        s[key] = on;
        Notif.saveSettings(s);
        paintToggle(toggle.id, trackId, on);
        if (on) {
          Notif.requestPermission(function (perm) {
            if (perm === 'denied' && permNote) permNote.style.display = 'block';
            else if (permNote) permNote.style.display = 'none';
            Notif.show('🔔 Notifications Enabled',
              'You will receive ' + key + ' reminders.',
              { type: 'success' });
          });
        } else {
          if (typeof window.showToast === 'function') {
            window.showToast('🔕', 'Notifications Off',
              key + ' reminders disabled.', 'info', 2000);
          }
        }
      }

      // Use event delegation for change events on the toggle checkboxes
      // (survives React re-renders that replace DOM nodes)
      document.body.addEventListener('change', function (e) {
        var t = e.target;
        if (t.id === 'aqNotifFeedToggle') handleToggleChange('feed', t, 'aqNotifFeedTrack');
        else if (t.id === 'aqNotifLowStockToggle') handleToggleChange('lowStock', t, 'aqNotifLowStockTrack');
        else if (t.id === 'aqNotifSamplingToggle') handleToggleChange('sampling', t, 'aqNotifSamplingTrack');
      });

      // Test button handled via delegation in bindSettingsButtons
      // Show permission note if already denied
      if ('Notification' in window && Notification.permission === 'denied' && permNote) {
        permNote.style.display = 'block';
      }

      // Repaint toggles whenever the Settings page becomes active (handles
      // cases where React re-renders the DOM and resets inline styles)
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqNotifHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageSettings') {
            setTimeout(function () {
              paintToggle('aqNotifFeedToggle', 'aqNotifFeedTrack', !!s.feed);
              paintToggle('aqNotifLowStockToggle', 'aqNotifLowStockTrack', !!s.lowStock);
              paintToggle('aqNotifSamplingToggle', 'aqNotifSamplingTrack', !!s.sampling);
            }, 50);
          }
          return r;
        };
        window.switchPage._aqNotifHooked = true;
      }

      // Start the periodic checker
      Notif.startChecker();
    }, 'initNotifications');
  }

  /* ═══════════════════════════════════════════════════════════════
     E. GLOBAL SEARCH OVERLAY (Ctrl+/ or search icon)
     Searches across: ponds, batches, feed records (recent), inventory
     ═══════════════════════════════════════════════════════════════ */
  var searchOverlay = null;

  function buildSearchIndex() {
    var index = [];
    safe(function () {
      // Ponds
      var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]');
      (ponds || []).forEach(function (p) {
        index.push({
          type: 'pond', id: p.id,
          title: p.name || 'Pond',
          sub: (p.site || '') + (p.sizeSqFt ? ' · ' + p.sizeSqFt + ' sq ft' : ''),
          icon: '🛢',
          action: function () { switchPage('pageManage'); }
        });
      });

      // Batches
      var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
      (batches || []).forEach(function (b) {
        if (!b) return;
        var pondName = '';
        try {
          var p = ponds.find(function (x) { return x.id === b.pondId; });
          if (p) pondName = p.name;
        } catch (_) {}
        index.push({
          type: 'batch', id: b.id,
          title: (b.name || 'Batch') + (b.completed ? ' ✓' : ''),
          sub: (pondName || b.pondId || '') + (b.startDate ? ' · started ' + b.startDate : ''),
          icon: b.completed ? '📋' : '🐟',
          action: function () {
            if (typeof window.setViewBatchId === 'function') {
              window.setViewBatchId(b.id);
              if (typeof window.showBatchView === 'function') window.showBatchView(b.id);
            }
            switchPage('pageDashboard');
          }
        });
      });

      // Recent feed records (last 50)
      var records = JSON.parse(localStorage.getItem('al_records') || '[]');
      var recent = (records || []).slice(-50).reverse();
      var pondMap = {};
      (ponds || []).forEach(function (p) { pondMap[p.id] = p.name; });
      recent.forEach(function (r) {
        if (!r) return;
        index.push({
          type: 'record',
          title: (pondMap[r.pondId] || r.pondId || 'Pond') + ' · ' + (r.date || ''),
          sub: (r.time || '') + ' · ' + (r.totalQty || r.total || 0) + 'g feed',
          icon: '🍽',
          action: function () { switchPage('pageReports'); }
        });
      });

      // Inventory items (aggregate by name)
      var inv = JSON.parse(localStorage.getItem('al_inventory') || '[]');
      var invMap = {};
      (inv || []).forEach(function (t) {
        if (!t || !t.name) return;
        if (!invMap[t.name]) {
          invMap[t.name] = { name: t.name, type: t.type || 'item', qty: 0 };
        }
        if (t.qty) invMap[t.name].qty += parseFloat(t.qty) || 0;
      });
      Object.keys(invMap).forEach(function (k) {
        var it = invMap[k];
        index.push({
          type: 'inventory',
          title: it.name,
          sub: it.type + ' · stock ~' + Math.round(it.qty) + (it.type === 'feed' ? ' kg' : ''),
          icon: it.type === 'medicine' ? '💊' : (it.type === 'fuel' ? '⛽' : '📦'),
          action: function () { switchPage('pageInventory'); }
        });
      });

      // Sites
      var sites = JSON.parse(localStorage.getItem('al_sites') || '[]');
      (sites || []).forEach(function (st) {
        index.push({
          type: 'site', id: st.id,
          title: st.name || 'Site',
          sub: (st.location || '') + (st.ponds && st.ponds.length ? ' · ' + st.ponds.length + ' ponds' : ''),
          icon: '🏭',
          action: function () { switchPage('pageManage'); }
        });
      });
    });
    return index;
  }

  function openGlobalSearch() {
    safe(function () {
      if (searchOverlay) { closeGlobalSearch(); return; }

      var index = buildSearchIndex();
      var overlay = document.createElement('div');
      overlay.className = 'aq-search-overlay';
      overlay.innerHTML =
        '<div class="aq-search-box">' +
          '<div class="aq-search-header">' +
            '<span class="aq-search-icon">🔍</span>' +
            '<input type="text" class="aq-search-input" placeholder="Search ponds, batches, records, inventory…" autocomplete="off" />' +
            '<button class="aq-search-close" aria-label="Close">✕</button>' +
          '</div>' +
          '<div class="aq-search-results"></div>' +
          '<div class="aq-search-footer">↑↓ navigate · ↵ open · esc close</div>' +
        '</div>';
      document.body.appendChild(overlay);
      searchOverlay = overlay;

      var input = overlay.querySelector('.aq-search-input');
      var results = overlay.querySelector('.aq-search-results');
      var closeBtn = overlay.querySelector('.aq-search-close');
      var selectedIdx = -1;
      var filtered = [];

      function render(query) {
        query = (query || '').toLowerCase().trim();
        if (!query) {
          filtered = index.slice(0, 20);
          results.innerHTML = '<div class="aq-search-hint">Start typing to search across ' + index.length + ' items…</div>' +
            filtered.map(function (r) { return resultHtml(r); }).join('');
        } else {
          filtered = index.filter(function (r) {
            return (r.title + ' ' + r.sub + ' ' + r.type).toLowerCase().indexOf(query) !== -1;
          }).slice(0, 30);
          if (filtered.length === 0) {
            results.innerHTML = '<div class="aq-search-empty">No matches found for "' + escapeHtml(query) + '"</div>';
          } else {
            results.innerHTML = filtered.map(function (r) { return resultHtml(r); }).join('');
          }
        }
        selectedIdx = -1;
        updateSelected();
      }

      function resultHtml(r) {
        return '<div class="aq-search-result" data-type="' + r.type + '">' +
          '<span class="aq-search-result-icon">' + r.icon + '</span>' +
          '<div class="aq-search-result-info">' +
            '<div class="aq-search-result-title">' + escapeHtml(r.title) + '</div>' +
            '<div class="aq-search-result-sub">' + escapeHtml(r.sub) + '</div>' +
          '</div>' +
          '<span class="aq-search-result-type">' + r.type + '</span>' +
        '</div>';
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      function updateSelected() {
        var items = results.querySelectorAll('.aq-search-result');
        items.forEach(function (el, i) {
          el.classList.toggle('aq-search-selected', i === selectedIdx);
        });
        if (selectedIdx >= 0 && items[selectedIdx]) {
          items[selectedIdx].scrollIntoView({ block: 'nearest' });
        }
      }

      input.addEventListener('input', function () { render(input.value); });

      input.addEventListener('keydown', function (e) {
        if (e.key === 'ArrowDown') {
          e.preventDefault();
          selectedIdx = Math.min(selectedIdx + 1, filtered.length - 1);
          updateSelected();
        } else if (e.key === 'ArrowUp') {
          e.preventDefault();
          selectedIdx = Math.max(selectedIdx - 1, 0);
          updateSelected();
        } else if (e.key === 'Enter') {
          e.preventDefault();
          if (filtered[selectedIdx] && filtered[selectedIdx].action) {
            filtered[selectedIdx].action();
            closeGlobalSearch();
          } else if (filtered[0] && filtered[0].action) {
            filtered[0].action();
            closeGlobalSearch();
          }
        } else if (e.key === 'Escape') {
          e.preventDefault();
          closeGlobalSearch();
        }
      });

      // Click on result
      results.addEventListener('click', function (e) {
        var item = e.target.closest('.aq-search-result');
        if (!item) return;
        var items = Array.prototype.slice.call(results.querySelectorAll('.aq-search-result'));
        var idx = items.indexOf(item);
        if (idx >= 0 && filtered[idx] && filtered[idx].action) {
          filtered[idx].action();
          closeGlobalSearch();
        }
      });

      closeBtn.addEventListener('click', closeGlobalSearch);
      overlay.addEventListener('click', function (e) {
        if (e.target === overlay) closeGlobalSearch();
      });

      // Animate in
      requestAnimationFrame(function () { overlay.classList.add('aq-search-open'); });
      setTimeout(function () { input.focus(); render(''); }, 100);
    }, 'openGlobalSearch');
  }

  function closeGlobalSearch() {
    if (searchOverlay) {
      searchOverlay.classList.remove('aq-search-open');
      var el = searchOverlay;
      setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 220);
      searchOverlay = null;
    }
  }

  /* ═══════════════════════════════════════════════════════════════
     F. QUICK STATS FLOATING WIDGET on dashboard
     ═══════════════════════════════════════════════════════════════ */
  function initQuickStatsWidget() {
    safe(function () {
      // Only show on dashboard
      var widget = document.createElement('div');
      widget.className = 'aq-quickstats';
      widget.innerHTML =
        '<div class="aq-quickstats-toggle" aria-label="Toggle quick stats">' +
          '<span class="aq-quickstats-icon">📊</span>' +
        '</div>' +
        '<div class="aq-quickstats-panel">' +
          '<div class="aq-quickstats-row" data-nav="pageReports">' +
            '<span class="aq-quickstats-label">Today\'s Feed</span>' +
            '<span class="aq-quickstats-value" id="aqQsTodayFeed">—</span>' +
          '</div>' +
          '<div class="aq-quickstats-row" data-nav="pageDashboard">' +
            '<span class="aq-quickstats-label">Active Batches</span>' +
            '<span class="aq-quickstats-value" id="aqQsActiveBatches">—</span>' +
          '</div>' +
          '<div class="aq-quickstats-row" data-nav="pageInventory">' +
            '<span class="aq-quickstats-label">Low Stock</span>' +
            '<span class="aq-quickstats-value" id="aqQsLowStock">—</span>' +
          '</div>' +
          '<div class="aq-quickstats-row" data-nav="pageFinance">' +
            '<span class="aq-quickstats-label">Net Profit</span>' +
            '<span class="aq-quickstats-value" id="aqQsProfit">—</span>' +
          '</div>' +
        '</div>';
      document.body.appendChild(widget);

      var toggle = widget.querySelector('.aq-quickstats-toggle');
      var panel = widget.querySelector('.aq-quickstats-panel');
      var expanded = false;

      toggle.addEventListener('click', function () {
        expanded = !expanded;
        widget.classList.toggle('aq-quickstats-expanded', expanded);
        if (expanded) refreshQuickStats();
      });

      // Navigate when rows clicked
      panel.addEventListener('click', function (e) {
        var row = e.target.closest('.aq-quickstats-row');
        if (row && row.dataset.nav) {
          switchPage(row.dataset.nav);
        }
      });

      function refreshQuickStats() {
        safe(function () {
          // Today's feed total
          var records = JSON.parse(localStorage.getItem('al_records') || '[]');
          var today = todayStr();
          var todayTotal = 0;
          (records || []).forEach(function (r) {
            if (r && r.date === today) {
              todayTotal += parseFloat(r.totalQty || r.total || 0);
            }
          });
          var tfEl = $('aqQsTodayFeed');
          if (tfEl) tfEl.textContent = todayTotal > 0 ? Math.round(todayTotal / 1000) + ' kg' : '0 g';

          // Active batches
          var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
          var active = (batches || []).filter(function (b) { return b && !b.completed; }).length;
          var abEl = $('aqQsActiveBatches');
          if (abEl) abEl.textContent = active;

          // Low stock
          var lsEl = $('aqQsLowStock');
          if (lsEl) lsEl.textContent = Notif.countLowStock();

          // Net profit
          var exp = JSON.parse(localStorage.getItem('al_finance_expenses') || '[]');
          var rev = JSON.parse(localStorage.getItem('al_finance_revenue') || '[]');
          var totalExp = 0, totalRev = 0;
          (exp || []).forEach(function (e) { if (e && e.amount) totalExp += parseFloat(e.amount); });
          (rev || []).forEach(function (r) { if (r && r.amount) totalRev += parseFloat(r.amount); });
          var profit = totalRev - totalExp;
          var pEl = $('aqQsProfit');
          if (pEl) {
            pEl.textContent = (profit >= 0 ? '+₹' : '-₹') + Math.abs(Math.round(profit)).toLocaleString('en-IN');
            pEl.style.color = profit >= 0 ? 'var(--green)' : 'var(--red)';
          }
        }, 'refreshQuickStats');
      }

      // Refresh every 30s when dashboard is visible
      setInterval(function () {
        if (expanded) refreshQuickStats();
      }, 30000);
    }, 'initQuickStatsWidget');
  }

  /* ═══════════════════════════════════════════════════════════════
     STYLES for all new features
     ═══════════════════════════════════════════════════════════════ */
  function injectStyles() {
    if (document.getElementById('aq-extra-styles')) return;
    var css = document.createElement('style');
    css.id = 'aq-extra-styles';
    css.textContent = `
/* ── Global Search Overlay ── */
.aq-search-overlay {
  position: fixed; inset: 0; z-index: 9999;
  background: rgba(4,9,20,0.7);
  backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px);
  display: flex; align-items: flex-start; justify-content: center;
  padding-top: 12vh; opacity: 0; transition: opacity .22s ease;
}
.aq-search-overlay.aq-search-open { opacity: 1; }
.aq-search-box {
  width: 92%; max-width: 560px;
  background: linear-gradient(180deg, rgba(18,26,48,0.97), rgba(10,16,36,0.97));
  border: 1px solid rgba(0,229,245,0.2);
  border-radius: 20px;
  box-shadow: 0 24px 60px rgba(0,0,0,0.6), 0 0 40px rgba(0,229,245,0.1);
  overflow: hidden;
  transform: translateY(-16px) scale(0.98);
  transition: transform .28s cubic-bezier(0.34,1.56,0.64,1);
}
.aq-search-overlay.aq-search-open .aq-search-box { transform: translateY(0) scale(1); }
.aq-search-header {
  display: flex; align-items: center; gap: 12px;
  padding: 16px 18px;
  border-bottom: 1px solid rgba(255,255,255,0.06);
}
.aq-search-icon { font-size: 1.3rem; opacity: 0.7; }
.aq-search-input {
  flex: 1; background: transparent; border: none; outline: none;
  color: var(--t1, #f1f5f9); font-size: 1rem; font-family: inherit;
}
.aq-search-input::placeholder { color: var(--t3, #475569); }
.aq-search-close {
  background: rgba(255,255,255,0.06); border: none; color: var(--t2, #94a3b8);
  width: 30px; height: 30px; border-radius: 50%; cursor: pointer;
  font-size: 0.9rem; transition: background .2s;
}
.aq-search-close:hover { background: rgba(244,63,94,0.2); color: var(--red); }
.aq-search-results {
  max-height: 50vh; overflow-y: auto;
  padding: 8px;
}
.aq-search-results::-webkit-scrollbar { width: 6px; }
.aq-search-results::-webkit-scrollbar-thumb { background: rgba(0,229,245,0.3); border-radius: 3px; }
.aq-search-hint {
  padding: 16px 14px; color: var(--t2, #94a3b8); font-size: 0.85rem; text-align: center;
}
.aq-search-empty {
  padding: 24px 14px; color: var(--t3, #475569); font-size: 0.9rem; text-align: center;
}
.aq-search-result {
  display: flex; align-items: center; gap: 12px;
  padding: 10px 12px; border-radius: 12px; cursor: pointer;
  transition: background .15s;
}
.aq-search-result:hover, .aq-search-result.aq-search-selected {
  background: rgba(0,229,245,0.1);
}
.aq-search-result-icon { font-size: 1.3rem; flex-shrink: 0; }
.aq-search-result-info { flex: 1; min-width: 0; }
.aq-search-result-title {
  color: var(--t1, #f1f5f9); font-size: 0.9rem; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.aq-search-result-sub {
  color: var(--t2, #94a3b8); font-size: 0.76rem; margin-top: 2px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.aq-search-result-type {
  font-size: 0.65rem; text-transform: uppercase; letter-spacing: 0.05em;
  color: var(--teal, #00e5f5); background: rgba(0,229,245,0.1);
  padding: 3px 8px; border-radius: 100px; flex-shrink: 0;
}
.aq-search-footer {
  padding: 10px 16px; border-top: 1px solid rgba(255,255,255,0.06);
  color: var(--t3, #475569); font-size: 0.72rem; text-align: center;
}

/* ── Quick Stats Floating Widget ── */
.aq-quickstats {
  position: fixed; right: 14px; bottom: 96px; z-index: 90;
  font-family: 'Plus Jakarta Sans', sans-serif;
}
.aq-quickstats-toggle {
  width: 44px; height: 44px; border-radius: 50%;
  background: linear-gradient(135deg, var(--teal, #00e5f5), var(--teal-dim, #0097a7));
  box-shadow: 0 6px 20px rgba(0,229,245,0.4), 0 0 0 1px rgba(255,255,255,0.1) inset;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: transform .2s;
}
.aq-quickstats-toggle:active { transform: scale(0.92); }
.aq-quickstats-icon { font-size: 1.3rem; }
.aq-quickstats-panel {
  position: absolute; right: 0; bottom: 52px;
  width: 230px;
  background: linear-gradient(180deg, rgba(18,26,48,0.98), rgba(10,16,36,0.98));
  border: 1px solid rgba(0,229,245,0.25);
  border-radius: 16px;
  box-shadow: 0 16px 40px rgba(0,0,0,0.6), 0 0 24px rgba(0,229,245,0.1);
  padding: 10px;
  opacity: 0; transform: translateY(8px) scale(0.95);
  pointer-events: none;
  transition: opacity .22s ease, transform .22s cubic-bezier(0.34,1.56,0.64,1);
}
.aq-quickstats.aq-quickstats-expanded .aq-quickstats-panel {
  opacity: 1; transform: translateY(0) scale(1); pointer-events: auto;
}
.aq-quickstats-row {
  display: flex; justify-content: space-between; align-items: center;
  padding: 9px 10px; border-radius: 10px; cursor: pointer;
  transition: background .15s;
}
.aq-quickstats-row:hover { background: rgba(0,229,245,0.08); }
.aq-quickstats-row + .aq-quickstats-row { border-top: 1px solid rgba(255,255,255,0.04); }
.aq-quickstats-label {
  font-size: 0.75rem; color: var(--t2, #94a3b8); font-weight: 500;
}
.aq-quickstats-value {
  font-size: 0.95rem; color: var(--t1, #f1f5f9); font-weight: 700;
  font-variant-numeric: tabular-nums;
}

/* ── Search trigger button (added to status bar) ── */
.aq-search-trigger {
  background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.08);
  color: var(--t2, #94a3b8); padding: 4px 10px; border-radius: 100px;
  font-size: 0.72rem; cursor: pointer; transition: all .2s;
  display: inline-flex; align-items: center; gap: 5px;
}
.aq-search-trigger:hover {
  background: rgba(0,229,245,0.12); color: var(--teal, #00e5f5);
  border-color: rgba(0,229,245,0.3);
}

/* ── Restore status box ── */
#aqRestoreStatus { transition: opacity .2s; }
`;
    document.head.appendChild(css);
  }

  /* ═══════════════════════════════════════════════════════════════
     BOOT
     ═══════════════════════════════════════════════════════════════ */
  function bindSettingsButtons() {
    safe(function () {
      // Use event delegation on document.body so listeners survive React re-renders
      // that may replace the DOM nodes from dangerouslySetInnerHTML.
      document.body.addEventListener('click', function (e) {
        var t = e.target.closest('#aqExportJsonBtn, #aqExportCsvBtn, #aqImportBtn, #aqNotifTestBtn');
        if (!t) return;
        if (t.id === 'aqExportJsonBtn') { exportFullBackup(); }
        else if (t.id === 'aqExportCsvBtn') { exportFeedCsv(); }
        else if (t.id === 'aqImportBtn') {
          var input = document.getElementById('aqImportFileInput');
          if (input) input.click();
        }
        else if (t.id === 'aqNotifTestBtn') {
          Notif.requestPermission(function (perm) {
            var pn = document.getElementById('aqNotifPermissionNote');
            if (perm === 'denied' && pn) pn.style.display = 'block';
            Notif.show('🦐 AquaLog Test Notification',
              'Notifications are working! You\'ll see reminders here when feed times arrive or stock runs low.',
              { type: 'success', tag: 'test-' + Date.now() });
          });
        }
      });

      // File input change (also delegated via body)
      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'aqImportFileInput' && e.target.files && e.target.files[0]) {
          restoreFromBackup(e.target.files[0]);
          e.target.value = ''; // reset so same file can be re-selected
        }
      });

      console.log('[AquaLog/extra] settings buttons bound via delegation');
    }, 'bindSettingsButtons');
  }

  function addSearchTrigger() {
    safe(function () {
      // Add a search button to the status bar.
      // Re-injects periodically to survive React re-renders.
      function inject() {
        var statusRight = document.querySelector('.status-right');
        if (!statusRight) return;
        if (statusRight.querySelector('.aq-search-trigger')) return;
        var btn = document.createElement('button');
        btn.className = 'aq-search-trigger';
        btn.innerHTML = '🔍 <span style="opacity:0.6">⌘/</span>';
        btn.title = 'Global Search (Ctrl+/)';
        btn.addEventListener('click', openGlobalSearch);
        statusRight.insertBefore(btn, statusRight.firstChild);
      }
      inject();
      registerPeriodicCheck(inject, 'searchTrigger');
    }, 'addSearchTrigger');
  }

  function bindKeyboardShortcuts() {
    safe(function () {
      // Ctrl+/ or Cmd+/ opens global search
      document.addEventListener('keydown', function (e) {
        if ((e.ctrlKey || e.metaKey) && e.key === '/') {
          e.preventDefault();
          openGlobalSearch();
        }
      }, true);
    }, 'bindKeyboardShortcuts');
  }

  /* ═══════════════════════════════════════════════════════════════
     G. THEME SYSTEM (dark-only)
     Light theme and the Appearance settings section have been removed.
     The app now permanently uses the dark theme defined in :root.
     This stub keeps applyThemePref callable from elsewhere in the codebase
     without breaking — it just ensures data-theme="dark" is set.
     ═══════════════════════════════════════════════════════════════ */
  function applyThemePref() {
    document.documentElement.setAttribute('data-theme', 'dark');
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', '#0d1117');
  }
  function getThemePref() { return 'dark'; }
  function saveThemePref() { /* no-op — dark is the only theme */ }

  function initThemeSystem() {
    safe(function () {
      applyThemePref('dark');
      // Hook the host's applyTheme so any future call still forces dark
      if (typeof window.applyTheme === 'function' && !window.applyTheme._aqHooked) {
        window.applyTheme = function () { applyThemePref('dark'); };
        window.applyTheme._aqHooked = true;
      }
    }, 'initThemeSystem');
  }

  /* ═══════════════════════════════════════════════════════════════
     H. TODAY'S TASKS WIDGET — Smart actionable checklist
     Inserted at the top of the Dashboard, shows: pending feed sessions,
     sampling-due batches, low-stock items, and recent activity.
     ═══════════════════════════════════════════════════════════════ */
  function buildTodaysTasks() {
    var tasks = [];
    safe(function () {
      var ctx = getDashboardContext();

      // ── Prerequisite check (Fix #1) ──
      // Today's tasks are batch-dependent (feed schedules belong to active batches).
      // If user has no sites, no ponds, or no active batches yet, return an empty
      // list — refreshTasksCard() will detect the empty state + missing
      // prerequisites and show the appropriate "create setup" message instead.
      if (!ctx.hasPrerequisites) return;

      // ── Completed batch: no live tasks (Fix #11) ──
      if (ctx.mode === 'batch' && ctx.isCompleted) return;

      // ── Pond/Batch filter (Fix #10) ──
      // When a specific batch is selected, only show tasks for that batch's pond.
      var filterBatchId = ctx.batch ? ctx.batch.id : null;
      var filterPondId  = ctx.batch ? ctx.batch.pondId : null;

      var today = new Date();
      var todayKey = todayStr();
      var hour = today.getHours();

      // 1. Feed sessions — which scheduled feed times haven't been logged yet today
      var records = JSON.parse(localStorage.getItem('al_records') || '[]') || [];
      var todayRecords = records.filter(function (r) {
        if (!r || recDate(r) !== todayKey) return false;
        if (filterBatchId && recBatchId(r) !== filterBatchId) return false;
        if (filterPondId  && recPondId(r)  !== filterPondId)  return false;
        return true;
      });
      var loggedTimes = todayRecords.map(function (r) { return recTime(r); });

      var feedSchedule = [
        { time: '7:00 AM',  hour: 7,  label: 'Morning Feed' },
        { time: '11:00 AM', hour: 11, label: 'Midday Feed' },
        { time: '4:00 PM',  hour: 16, label: 'Afternoon Feed' },
        { time: '7:00 PM',  hour: 19, label: 'Evening Feed' }
      ];

      feedSchedule.forEach(function (fs) {
        var logged = loggedTimes.indexOf(fs.time) !== -1 ||
                     todayRecords.some(function (r) { return parseTimeToHour(recTime(r)) === fs.hour; });
        var isPast = hour >= fs.hour;
        var isCurrent = hour >= fs.hour && hour < fs.hour + 3;
        if (!logged) {
          tasks.push({
            type: 'feed',
            icon: '🍽',
            title: fs.label + ' (' + fs.time + ')',
            sub: isPast ? 'Overdue — log it now' : (isCurrent ? 'Time to feed!' : 'Upcoming'),
            priority: isPast ? 'high' : (isCurrent ? 'medium' : 'low'),
            done: false,
            action: 'pageLog'
          });
        }
      });

      // 2. Sampling due batches (filtered by selected pond when applicable)
      var batches = JSON.parse(localStorage.getItem('al_batches') || '[]') || [];
      var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]') || [];
      batches.forEach(function (b) {
        if (!b || b.status !== 'active' || !b.stockingDate) return;
        if (filterBatchId && b.id !== filterBatchId) return;
        var start = new Date(b.stockingDate);
        var doc = Math.floor((today - start) / (1000 * 60 * 60 * 24));
        if (doc > 0 && doc % 15 < 2) {
          var hasRecent = sampling.some(function (s) {
            if (s.batchId !== b.id) return false;
            var sd = new Date(s.date);
            return (today - sd) / (1000 * 60 * 60 * 24) < 2;
          });
          if (!hasRecent) {
            var pondName = b.pond || 'Pond';
            tasks.push({
              type: 'sampling',
              icon: '🔬',
              title: 'Sampling Due: ' + pondName,
              sub: 'Day ' + doc + ' · growth check recommended',
              priority: 'medium',
              done: false,
              action: 'pageDashboard'
            });
          }
        }
      });

      // 3. Low stock items — only on Farm view (cross-cutting inventory issue)
      if (ctx.mode === 'farm' && typeof Notif !== 'undefined' && Notif.countLowStock) {
        var lowCount = Notif.countLowStock();
        if (lowCount > 0) {
          tasks.push({
            type: 'stock',
            icon: '📦',
            title: lowCount + ' Item' + (lowCount > 1 ? 's' : '') + ' Low on Stock',
            sub: 'Restock soon to avoid shortages',
            priority: 'medium',
            done: false,
            action: 'pageInventory'
          });
        }
      }

      // 4. Completed feed sessions today (shown as done)
      if (todayRecords.length > 0) {
        tasks.push({
          type: 'done',
          icon: '✅',
          title: todayRecords.length + ' Feed Session' + (todayRecords.length > 1 ? 's' : '') + ' Logged',
          sub: 'Great work! Keep it up.',
          priority: 'low',
          done: true,
          action: 'pageReports'
        });
      }

      // Sort: high priority first, then medium, then low/done
      var order = { high: 0, medium: 1, low: 2 };
      tasks.sort(function (a, b) { return (order[a.priority] || 3) - (order[b.priority] || 3); });
    });
    return tasks;
  }

  function initTodaysTasksWidget() {
    safe(function () {
      // Insert the widget at the top of the Dashboard page, after the context selector
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-tasks-card')) return; // already inserted

        var contextCard = scroll.querySelector('.context-selector-card');
        var card = document.createElement('div');
        card.className = 'aq-tasks-card';
        card.innerHTML = renderTasksCard();
        if (contextCard && contextCard.nextSibling) {
          scroll.insertBefore(card, contextCard.nextSibling);
        } else {
          scroll.insertBefore(card, scroll.firstChild);
        }
        refreshTasksCard();
      }

      function renderTasksCard() {
        return '<div class="aq-tasks-inner">' +
          '<div class="aq-tasks-header">' +
            '<div class="aq-tasks-title">' +
              '<span class="aq-tasks-icon">📋</span>' +
              '<span>Today\'s Tasks · आज के काम</span>' +
            '</div>' +
            '<span class="aq-tasks-count" id="aqTasksCount">0</span>' +
          '</div>' +
          '<div class="aq-tasks-list" id="aqTasksList"></div>' +
        '</div>';
      }

      function refreshTasksCard() {
        var card  = document.querySelector('.aq-tasks-card');
        var list  = document.getElementById('aqTasksList');
        var countEl = document.getElementById('aqTasksCount');
        var titleEl = card ? card.querySelector('.aq-tasks-title span:last-child') : null;
        if (!list) return;

        var ctx = getDashboardContext();

        // ── Fix #11: Hide Today's Tasks for completed batches ──
        if (ctx.mode === 'batch' && ctx.isCompleted) {
          if (card) card.style.display = 'none';
          return;
        }
        if (card) card.style.display = '';

        // ── Fix #10: Update title to reflect context ──
        if (titleEl) {
          titleEl.textContent = ctx.mode === 'batch' && ctx.pond
            ? "Today's Tasks · " + ctx.pond.name
            : "Today's Tasks · आज के काम";
        }

        var tasks = buildTodaysTasks();
        var pending = tasks.filter(function (t) { return !t.done; }).length;

        if (countEl) {
          countEl.textContent = pending > 0 ? pending + ' pending' : 'All done! 🎉';
          countEl.className = 'aq-tasks-count' + (pending === 0 ? ' aq-tasks-done' : '');
        }

        // ── Fix #1: Prerequisite empty state ──
        if (!ctx.hasPrerequisites) {
          list.innerHTML = '<div class="aq-tasks-empty aq-tasks-empty--setup">' +
            '<span class="aq-tasks-empty-icon">🦐</span>' +
            '<span class="aq-tasks-empty-text">Create a Site, Pond, and Active Batch to view today\'s tasks.</span>' +
            '<span class="aq-tasks-empty-sub">Feed schedules are batch-dependent — once you stock a batch, today\'s feed tasks will appear here.</span>' +
          '</div>';
          if (countEl) {
            countEl.textContent = 'Setup needed';
            countEl.className = 'aq-tasks-count aq-tasks-done';
          }
          return;
        }

        // ── Fix #10: Pond-level empty state ──
        if (ctx.mode === 'batch' && tasks.length === 0) {
          // If the batch is active and tasks are empty, all today's feed sessions
          // are likely logged. If the batch isn't active, prompt to stock one.
          var pondEmptyIcon = ctx.batch && ctx.batch.status === 'active' ? '✅' : '🌿';
          var pondEmptyText = ctx.batch && ctx.batch.status === 'active'
            ? 'All caught up for this pond.'
            : 'No active batch in this pond.';
          var pondEmptySub = ctx.batch && ctx.batch.status === 'active'
            ? 'Every scheduled feed session for today has been logged. Great work!'
            : 'Stock a new batch in this pond to see today\'s feed tasks here.';
          list.innerHTML = '<div class="aq-tasks-empty">' +
            '<span class="aq-tasks-empty-icon">' + pondEmptyIcon + '</span>' +
            '<span class="aq-tasks-empty-text">' + pondEmptyText + '</span>' +
            '<span class="aq-tasks-empty-sub">' + pondEmptySub + '</span>' +
          '</div>';
          return;
        }

        if (tasks.length === 0) {
          list.innerHTML = '<div class="aq-tasks-empty">No tasks for today. Enjoy a quiet day! 🌿</div>';
          return;
        }
        list.innerHTML = tasks.map(function (t) {
          return '<div class="aq-task-item aq-task-' + t.priority + (t.done ? ' aq-task-completed' : '') + '" data-action="' + (t.action || '') + '">' +
            '<span class="aq-task-icon">' + t.icon + '</span>' +
            '<div class="aq-task-info">' +
              '<div class="aq-task-title">' + escapeHtml(t.title) + '</div>' +
              '<div class="aq-task-sub">' + escapeHtml(t.sub) + '</div>' +
            '</div>' +
            (t.done ? '<span class="aq-task-check">✓</span>' : '<span class="aq-task-arrow">→</span>') +
          '</div>';
        }).join('');

        // Wire up click to navigate
        list.querySelectorAll('.aq-task-item').forEach(function (el) {
          el.addEventListener('click', function () {
            var action = el.getAttribute('data-action');
            if (action && typeof window.switchPage === 'function') {
              window.switchPage(action);
            }
          });
        });
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      // Inject and refresh when dashboard becomes active
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqTasksHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(function () { inject(); refreshTasksCard(); }, 80);
          }
          return r;
        };
        window.switchPage._aqTasksHooked = true;
      }

      // Expose refresh globally so the dashboard context-change listener can call it
      window.refreshAquaTasks = function () {
        try { inject(); refreshTasksCard(); } catch (e) {}
      };

      // Initial inject
      setTimeout(function () { inject(); refreshTasksCard(); }, 500);

      // Refresh every 5 minutes
      setInterval(refreshTasksCard, 5 * 60 * 1000);
    }, 'initTodaysTasksWidget');
  }

  /* ═══════════════════════════════════════════════════════════════
     I. DASHBOARD INSIGHTS CARD — Smart trend analysis
     Shows: 7-day feed trend (up/down %), best/worst performing batch,
     growth rate insight, and a smart recommendation.
     ═══════════════════════════════════════════════════════════════ */
  function initInsightsCard() {
    safe(function () {
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-insights-card')) return;

        // Insert after the tasks card (or after context selector if no tasks card)
        var tasksCard = scroll.querySelector('.aq-tasks-card');
        var contextCard = scroll.querySelector('.context-selector-card');
        var anchor = tasksCard ? tasksCard.nextSibling : (contextCard ? contextCard.nextSibling : scroll.firstChild);

        var card = document.createElement('div');
        card.className = 'aq-insights-card';
        card.innerHTML = '<div class="aq-insights-inner">' +
          '<div class="aq-insights-header">' +
            '<span class="aq-insights-icon">💡</span>' +
            '<span>Smart Insights · समझदारी</span>' +
          '</div>' +
          '<div class="aq-insights-list" id="aqInsightsList"></div>' +
        '</div>';
        scroll.insertBefore(card, anchor);
        refreshInsights();
      }

      function refreshInsights() {
        var card  = document.querySelector('.aq-insights-card');
        var list  = document.getElementById('aqInsightsList');
        var titleEl = card ? card.querySelector('.aq-insights-header span:last-child') : null;
        if (!list) return;

        var ctx = getDashboardContext();

        // ── Fix #11: Hide Smart Insights for completed batches ──
        if (ctx.mode === 'batch' && ctx.isCompleted) {
          if (card) card.style.display = 'none';
          return;
        }
        if (card) card.style.display = '';

        // ── Fix #10: Update title to reflect context ──
        if (titleEl) {
          titleEl.textContent = ctx.mode === 'batch' && ctx.pond
            ? 'Smart Insights · ' + ctx.pond.name
            : 'Smart Insights · समझदारी';
        }

        var insights = generateInsights();
        if (insights.length === 0) {
          list.innerHTML = '<div class="aq-insights-empty">' +
            (ctx.mode === 'batch'
              ? 'No data available for this pond yet. Log feed, weights, and sampling to see insights.'
              : 'Add more data to see smart insights.') +
          '</div>';
          return;
        }
        list.innerHTML = insights.map(function (ins) {
          return '<div class="aq-insight-item aq-insight-' + ins.type + '">' +
            '<span class="aq-insight-icon">' + ins.icon + '</span>' +
            '<div class="aq-insight-body">' +
              '<div class="aq-insight-title">' + escapeHtml(ins.title) + '</div>' +
              '<div class="aq-insight-sub">' + escapeHtml(ins.sub) + '</div>' +
            '</div>' +
          '</div>';
        }).join('');
      }

      function generateInsights() {
        var insights = [];
        safe(function () {
          var ctx = getDashboardContext();
          var records   = JSON.parse(localStorage.getItem('al_records') || '[]') || [];
          var batches   = JSON.parse(localStorage.getItem('al_batches') || '[]') || [];
          var sampling  = JSON.parse(localStorage.getItem('al_sampling') || '[]') || [];
          var growth    = JSON.parse(localStorage.getItem('al_growth') || '[]') || [];
          var today = new Date();

          function isoDate(d) {
            return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2);
          }

          // ── POND/BATCH VIEW (Fix #10) ──
          if (ctx.mode === 'batch' && ctx.batch) {
            var batch = ctx.batch;
            var filterBatchId = batch.id;
            var filterPondId  = batch.pondId;
            var pondName = (ctx.pond && ctx.pond.name) || batch.pond || 'Pond';

            // 1. Feed status (today)
            var todayKey = isoDate(today);
            var todayRecs = records.filter(function (r) {
              return r && recDate(r) === todayKey && recBatchId(r) === filterBatchId;
            });
            var todayG = todayRecs.reduce(function (s, r) { return s + recQty(r); }, 0);
            insights.push({
              type: todayG > 0 ? 'good' : 'warn',
              icon: todayG > 0 ? '🍽' : '⏰',
              title: 'Feed Status',
              sub: todayG > 0
                ? todayRecs.length + ' session' + (todayRecs.length > 1 ? 's' : '') + ' logged · ' + (todayG / 1000).toFixed(2) + ' kg today'
                : 'No feed logged yet today. Add a feed session to keep DOC on track.'
            });

            // 2. DOC
            if (batch.stockingDate) {
              var doc = Math.floor((today - new Date(batch.stockingDate)) / (1000 * 60 * 60 * 24));
              insights.push({
                type: 'info',
                icon: '📅',
                title: 'DOC · Day of Culture',
                sub: 'Day ' + doc + ' for ' + pondName + ' · Batch #' + (batch.batchNumber || '?') +
                  (doc > 100 ? ' · Harvest approaching — plan ahead!' : (doc > 30 ? ' · Growing well.' : ' · Early stage.'))
              });
            }

            // 3. Growth trend (last 2 sampling or visual entries)
            var batchSampling = sampling.filter(function (s) { return s.batchId === filterBatchId; })
                                        .sort(function (a, b) { return new Date(a.date) - new Date(b.date); });
            var batchGrowth = growth.filter(function (g) { return g.batchId === filterBatchId; })
                                    .sort(function (a, b) { return new Date(a.date) - new Date(b.date); });
            if (batchSampling.length >= 2) {
              var last = batchSampling[batchSampling.length - 1];
              var prev = batchSampling[batchSampling.length - 2];
              var delta = last.abw - prev.abw;
              var daysBetween = Math.max(1, Math.round((new Date(last.date) - new Date(prev.date)) / (1000 * 60 * 60 * 24)));
              var weeklyRate = (delta / daysBetween) * 7;
              insights.push({
                type: weeklyRate > 0 ? 'up' : (weeklyRate < 0 ? 'down' : 'stable'),
                icon: weeklyRate > 0 ? '📈' : (weeklyRate < 0 ? '📉' : '➡️'),
                title: 'Growth Trend',
                sub: 'ABW ' + last.abw.toFixed(2) + 'g (was ' + prev.abw.toFixed(2) + 'g). ' +
                     (weeklyRate >= 0 ? '+' : '') + weeklyRate.toFixed(2) + 'g/week trend.'
              });
            } else if (batchGrowth.length >= 2) {
              var l2 = batchGrowth[batchGrowth.length - 1];
              var p2 = batchGrowth[batchGrowth.length - 2];
              var d2 = l2.weightGrams - p2.weightGrams;
              var db2 = Math.max(1, Math.round((new Date(l2.date) - new Date(p2.date)) / (1000 * 60 * 60 * 24)));
              var wr2 = (d2 / db2) * 7;
              insights.push({
                type: wr2 > 0 ? 'up' : (wr2 < 0 ? 'down' : 'stable'),
                icon: wr2 > 0 ? '📈' : (wr2 < 0 ? '📉' : '➡️'),
                title: 'Growth Trend (Visual)',
                sub: 'Latest visual weight: ' + l2.weightGrams.toFixed(2) + 'g. ' +
                     (wr2 >= 0 ? '+' : '') + wr2.toFixed(2) + 'g/week. Run a sampling for accurate ABW.'
              });
            } else if (batchGrowth.length === 1 || batchSampling.length === 1) {
              var w = batchSampling.length === 1 ? batchSampling[0].abw : batchGrowth[0].weightGrams;
              insights.push({
                type: 'info',
                icon: '⚖',
                title: 'Latest Weight',
                sub: 'Current weight: ' + w.toFixed(2) + 'g. Add another sampling entry in 7-10 days to see growth trend.'
              });
            }

            // 4. Survival
            if (batch.harvestWeightKg && batch.survivalPercent !== undefined) {
              insights.push({
                type: batch.survivalPercent >= 70 ? 'good' : (batch.survivalPercent >= 50 ? 'warn' : 'down'),
                icon: '🦐',
                title: 'Survival Rate',
                sub: batch.survivalPercent.toFixed(1) + '% survival at harvest · ' + batch.harvestWeightKg + ' kg harvested.'
              });
            }

            // 5. Sampling due
            if (batch.stockingDate && batch.status === 'active') {
              var doc2 = Math.floor((today - new Date(batch.stockingDate)) / (1000 * 60 * 60 * 24));
              if (doc2 > 0 && doc2 % 15 < 2) {
                var hasRecent = batchSampling.some(function (s) {
                  return (today - new Date(s.date)) / (1000 * 60 * 60 * 24) < 2;
                });
                if (!hasRecent) {
                  insights.push({
                    type: 'warn',
                    icon: '🔬',
                    title: 'Sampling Due',
                    sub: 'Day ' + doc2 + ' · growth check recommended. Regular sampling every 15 days keeps growth tracking accurate.'
                  });
                }
              }
            }

            // 6. Feed increase/decrease suggestion
            var last7Batch = [];
            var prev7Batch = [];
            for (var i = 0; i < 7; i++) {
              var d = new Date(today); d.setDate(d.getDate() - i);
              var k = isoDate(d);
              var t = records.filter(function (r) { return r && recDate(r) === k && recBatchId(r) === filterBatchId; })
                             .reduce(function (s, r) { return s + recQty(r); }, 0);
              last7Batch.push(t);
            }
            for (var j = 7; j < 14; j++) {
              var dj = new Date(today); dj.setDate(dj.getDate() - j);
              var kj = isoDate(dj);
              var tj = records.filter(function (r) { return r && recDate(r) === kj && recBatchId(r) === filterBatchId; })
                              .reduce(function (s, r) { return s + recQty(r); }, 0);
              prev7Batch.push(tj);
            }
            var thisWeekBatch = last7Batch.reduce(function (a, b) { return a + b; }, 0);
            var lastWeekBatch = prev7Batch.reduce(function (a, b) { return a + b; }, 0);
            if (lastWeekBatch > 0 && thisWeekBatch > 0) {
              var changeBatch = ((thisWeekBatch - lastWeekBatch) / lastWeekBatch * 100);
              if (Math.abs(changeBatch) >= 5) {
                insights.push({
                  type: changeBatch > 0 ? 'up' : 'down',
                  icon: changeBatch > 0 ? '📈' : '📉',
                  title: 'Feed Suggestion',
                  sub: changeBatch > 0
                    ? 'Feed up ' + changeBatch.toFixed(1) + '% vs last week. Confirm growth justifies the increase; otherwise reduce to protect FCR.'
                    : 'Feed down ' + Math.abs(changeBatch).toFixed(1) + '% vs last week. If growth is on track, this efficiency is good. If slow, consider a small bump.'
                });
              }
            }
            return;
          }

          // ── FARM VIEW (original logic, schema-corrected) ──
          // 1. 7-day feed trend (farm-wide)
          var last7 = [];
          var prev7 = [];
          for (var i = 0; i < 7; i++) {
            var d = new Date(today); d.setDate(d.getDate() - i);
            var key = isoDate(d);
            var dayTotal = records.filter(function (r) { return r && recDate(r) === key; })
                                  .reduce(function (s, r) { return s + recQty(r); }, 0);
            last7.push(dayTotal);
          }
          for (var i = 7; i < 14; i++) {
            var d = new Date(today); d.setDate(d.getDate() - i);
            var key = isoDate(d);
            var dayTotal = records.filter(function (r) { return r && recDate(r) === key; })
                                  .reduce(function (s, r) { return s + recQty(r); }, 0);
            prev7.push(dayTotal);
          }
          var thisWeek = last7.reduce(function (a, b) { return a + b; }, 0);
          var lastWeek = prev7.reduce(function (a, b) { return a + b; }, 0);
          if (lastWeek > 0) {
            var change = ((thisWeek - lastWeek) / lastWeek * 100);
            var trend = change > 5 ? 'up' : (change < -5 ? 'down' : 'stable');
            var icon = trend === 'up' ? '📈' : (trend === 'down' ? '📉' : '➡️');
            var msg;
            if (trend === 'up') {
              msg = 'Feed usage increased ' + Math.abs(change).toFixed(1) + '% vs last week. Monitor FCR closely.';
            } else if (trend === 'down') {
              msg = 'Feed usage decreased ' + Math.abs(change).toFixed(1) + '% vs last week. Good efficiency!';
            } else {
              msg = 'Feed usage is stable (±' + Math.abs(change).toFixed(1) + '% vs last week).';
            }
            insights.push({ type: trend, icon: icon, title: '7-Day Feed Trend', sub: msg });
          }

          // 2. Active batch count and avg DOC
          var activeBatches = batches.filter(function (b) { return b && b.status === 'active'; });
          if (activeBatches.length > 0) {
            var totalDoc = 0;
            var counted = 0;
            activeBatches.forEach(function (b) {
              if (b.stockingDate) {
                totalDoc += Math.floor((today - new Date(b.stockingDate)) / (1000 * 60 * 60 * 24));
                counted++;
              }
            });
            if (counted > 0) {
              var avgDoc = Math.round(totalDoc / counted);
              insights.push({
                type: 'info',
                icon: '🐟',
                title: activeBatches.length + ' Active Batches',
                sub: 'Average age: ' + avgDoc + ' days. ' + (avgDoc > 100 ? 'Harvest approaching — plan ahead!' : 'Growing well.')
              });
            }
          }

          // 3. Finance insight (farm-wide)
          var exp = JSON.parse(localStorage.getItem('al_finance_expenses') || '[]') || [];
          var rev = JSON.parse(localStorage.getItem('al_finance_revenue') || '[]') || [];
          var totalExp = exp.reduce(function (s, e) { return s + (parseFloat(e && e.amount) || 0); }, 0);
          var totalRev = rev.reduce(function (s, r) { return s + (parseFloat(r && r.amount) || 0); }, 0);
          var profit = totalRev - totalExp;
          if (totalExp > 0 || totalRev > 0) {
            var margin = totalRev > 0 ? (profit / totalRev * 100).toFixed(1) : 'N/A';
            insights.push({
              type: profit >= 0 ? 'good' : 'warn',
              icon: profit >= 0 ? '💰' : '⚠️',
              title: 'Profitability',
              sub: (profit >= 0 ? 'Profit' : 'Loss') + ': ₹' + Math.abs(Math.round(profit)).toLocaleString('en-IN') +
                ' · Margin: ' + margin + '%'
            });
          }

          // 4. Recommendation
          if (activeBatches.length > 0 && thisWeek > 0) {
            var avgDailyFeed = thisWeek / 7;
            insights.push({
              type: 'tip',
              icon: '💡',
              title: 'Smart Tip',
              sub: 'Avg daily feed: ' + Math.round(avgDailyFeed / 1000) + ' kg. ' +
                (avgDailyFeed > 50000 ? 'Consider splitting into more sessions for better FCR.' : 'Feed volume looks optimal.')
            });
          }
        });
        return insights;
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      // Hook switchPage to inject when dashboard is shown
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqInsightsHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(function () { inject(); refreshInsights(); }, 120);
          }
          return r;
        };
        window.switchPage._aqInsightsHooked = true;
      }

      // Expose refresh globally so the dashboard context-change listener can call it
      window.refreshAquaInsights = function () {
        try { inject(); refreshInsights(); } catch (e) {}
      };

      setTimeout(function () { inject(); refreshInsights(); }, 600);
    }, 'initInsightsCard');
  }

  /* ═══════════════════════════════════════════════════════════════
     J. POND HEALTH SCORE — Visual 0-100 score on each pond card
     Computes a health score based on:
       - Feed consistency (regular logging vs gaps)
       - Growth rate (sampling data trend)
       - Survival rate (if harvest data exists for past batches)
       - Activity level (recent feed sessions)
     Renders as a circular progress ring with color-coded score.
     ═══════════════════════════════════════════════════════════════ */
  function calcPondHealthScore(pondId) {
    var score = 0;
    var breakdown = {};
    safe(function () {
      var records = JSON.parse(localStorage.getItem('al_records') || '[]');
      var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
      var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
      var today = new Date();

      // 1. Feed consistency (0-35 pts) — last 7 days logging rate
      var pondRecords = (records || []).filter(function (r) {
        return r && r.pondId === pondId;
      });
      var daysLogged = 0;
      for (var i = 0; i < 7; i++) {
        var d = new Date(today); d.setDate(d.getDate() - i);
        var key = d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2);
        if (pondRecords.some(function (r) { return r.date === key; })) daysLogged++;
      }
      var feedScore = Math.round((daysLogged / 7) * 35);
      score += feedScore;
      breakdown.feed = { pts: feedScore, max: 35, detail: daysLogged + '/7 days logged' };

      // 2. Activity level (0-20 pts) — sessions in last 3 days
      var recentSessions = 0;
      for (var i = 0; i < 3; i++) {
        var d = new Date(today); d.setDate(d.getDate() - i);
        var key = d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2);
        recentSessions += pondRecords.filter(function (r) { return r.date === key; }).length;
      }
      var activityScore = Math.min(20, recentSessions * 3);
      score += activityScore;
      breakdown.activity = { pts: activityScore, max: 20, detail: recentSessions + ' sessions (3d)' };

      // 3. Growth rate (0-25 pts) — from sampling data
      var pondBatches = (batches || []).filter(function (b) {
        return b && b.pondId === pondId && !b.completedAt;
      });
      var pondSampling = (sampling || []).filter(function (s) {
        if (!s || !s.batchId) return false;
        return pondBatches.some(function (b) { return b.id === s.batchId; });
      });
      if (pondSampling.length >= 2) {
        // Check if growth is positive between last 2 samplings
        var sorted = pondSampling.sort(function (a, b) {
          return new Date(a.date) - new Date(b.date);
        });
        var last = sorted[sorted.length - 1];
        var prev = sorted[sorted.length - 2];
        if (last.avgWeight && prev.avgWeight && last.avgWeight > prev.avgWeight) {
          var growthRate = ((last.avgWeight - prev.avgWeight) / prev.avgWeight * 100);
          var growthScore = Math.min(25, Math.round(growthRate * 2.5));
          score += growthScore;
          breakdown.growth = { pts: growthScore, max: 25, detail: '+' + growthRate.toFixed(1) + '% growth' };
        } else {
          breakdown.growth = { pts: 0, max: 25, detail: 'No growth data' };
        }
      } else {
        // Give partial credit if batch is active but no sampling yet
        if (pondBatches.length > 0) {
          score += 12;
          breakdown.growth = { pts: 12, max: 25, detail: 'Batch active, awaiting sampling' };
        } else {
          breakdown.growth = { pts: 0, max: 25, detail: 'No active batch' };
        }
      }

      // 4. Survival history (0-20 pts) — from completed batches
      var completedBatches = (batches || []).filter(function (b) {
        return b && b.pondId === pondId && b.completedAt && b.survivalPercent !== undefined;
      });
      if (completedBatches.length > 0) {
        var avgSurvival = completedBatches.reduce(function (s, b) {
          return s + (b.survivalPercent || 0);
        }, 0) / completedBatches.length;
        var survivalScore = Math.round((avgSurvival / 100) * 20);
        score += survivalScore;
        breakdown.survival = { pts: survivalScore, max: 20, detail: avgSurvival.toFixed(0) + '% avg survival' };
      } else {
        breakdown.survival = { pts: 10, max: 20, detail: 'No harvest history' };
        score += 10;
      }
    });
    return { score: Math.min(100, score), breakdown: breakdown };
  }

  function healthScoreColor(score) {
    if (score >= 75) return { color: '#10b981', label: 'Healthy', icon: '💪' };
    if (score >= 50) return { color: '#fbbf24', label: 'Fair', icon: '⚠️' };
    if (score >= 25) return { color: '#f59e0b', label: 'Attention', icon: '⚡' };
    return { color: '#f43f5e', label: 'Critical', icon: '🚨' };
  }

  function initPondHealthScore() {
    safe(function () {
      function injectBadges() {
        var managePage = document.getElementById('pageManage');
        if (!managePage || !managePage.classList.contains('active')) return;

        var pondCards = managePage.querySelectorAll('.pond-card');
        pondCards.forEach(function (card) {
          if (card.querySelector('.aq-health-badge')) return; // already injected

          // Find pond ID — check for a data attribute or extract from the card's onclick/context
          var pondNameEl = card.querySelector('.pond-card-name');
          if (!pondNameEl) return;
          var pondName = pondNameEl.textContent.trim();

          // Find the pond in storage by name
          var ponds = [];
          try { ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]'); } catch (_) {}
          var pond = ponds.find(function (p) { return p.name === pondName; });
          if (!pond) return;

          var result = calcPondHealthScore(pond.id);
          var info = healthScoreColor(result.score);

          // Create the health badge
          var badge = document.createElement('div');
          badge.className = 'aq-health-badge';
          badge.innerHTML =
            '<div class="aq-health-ring" style="--score: ' + result.score + '; --health-color: ' + info.color + ';">' +
              '<svg viewBox="0 0 40 40">' +
                '<circle class="aq-health-bg" cx="20" cy="20" r="16" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="3.5"/>' +
                '<circle class="aq-health-fg" cx="20" cy="20" r="16" fill="none" stroke="' + info.color + '" stroke-width="3.5" stroke-linecap="round" stroke-dasharray="' + (result.score / 100 * 100.5) + ' 100.5" transform="rotate(-90 20 20)"/>' +
              '</svg>' +
              '<span class="aq-health-score">' + result.score + '</span>' +
            '</div>' +
            '<div class="aq-health-info">' +
              '<div class="aq-health-label" style="color: ' + info.color + ';">' + info.icon + ' ' + info.label + '</div>' +
              '<div class="aq-health-detail" id="aq-health-detail-' + pond.id + '">Tap for breakdown</div>' +
            '</div>';

          // Insert into the pond card top area
          var top = card.querySelector('.pond-card-top');
          if (top) {
            top.appendChild(badge);
          } else {
            card.insertBefore(badge, card.firstChild);
          }

          // Click handler to show breakdown
          badge.addEventListener('click', function (e) {
            e.stopPropagation();
            showHealthBreakdown(pond.name, result, info);
          });
        });
      }

      function showHealthBreakdown(pondName, result, info) {
        // Use a simple modal-like overlay
        var overlay = document.createElement('div');
        overlay.className = 'aq-health-overlay';
        var b = result.breakdown;
        overlay.innerHTML =
          '<div class="aq-health-modal">' +
            '<div class="aq-health-modal-header">' +
              '<span class="aq-health-modal-icon">' + info.icon + '</span>' +
              '<div>' +
                '<div class="aq-health-modal-title">Pond Health: ' + escapeHtml(pondName) + '</div>' +
                '<div class="aq-health-modal-score" style="color:' + info.color + ';">Score: ' + result.score + '/100 · ' + info.label + '</div>' +
              '</div>' +
              '<button class="aq-health-modal-close">✕</button>' +
            '</div>' +
            '<div class="aq-health-modal-body">' +
              renderBar('Feed Consistency', b.feed) +
              renderBar('Activity Level', b.activity) +
              renderBar('Growth Rate', b.growth) +
              renderBar('Survival History', b.survival) +
            '</div>' +
            '<div class="aq-health-modal-footer">' +
              'Score updates automatically based on feed logs, sampling data, and harvest history.' +
            '</div>' +
          '</div>';

        function renderBar(label, item) {
          if (!item) return '';
          var pct = (item.pts / item.max * 100);
          var color = pct >= 70 ? '#10b981' : (pct >= 40 ? '#fbbf24' : '#f43f5e');
          return '<div class="aq-health-bar-item">' +
            '<div class="aq-health-bar-row">' +
              '<span class="aq-health-bar-label">' + label + '</span>' +
              '<span class="aq-health-bar-pts">' + item.pts + '/' + item.max + '</span>' +
            '</div>' +
            '<div class="aq-health-bar-track">' +
              '<div class="aq-health-bar-fill" style="width:' + pct + '%; background:' + color + ';"></div>' +
            '</div>' +
            '<div class="aq-health-bar-detail">' + escapeHtml(item.detail) + '</div>' +
          '</div>';
        }

        document.body.appendChild(overlay);
        requestAnimationFrame(function () { overlay.classList.add('aq-health-open'); });

        function close() {
          overlay.classList.remove('aq-health-open');
          setTimeout(function () { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, 250);
        }
        overlay.querySelector('.aq-health-modal-close').addEventListener('click', close);
        overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });

        var escHandler = function (e) { if (e.key === 'Escape') { close(); document.removeEventListener('keydown', escHandler); } };
        document.addEventListener('keydown', escHandler);
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      // Inject when Manage page becomes active
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqHealthHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageManage') {
            setTimeout(injectBadges, 200);
          }
          return r;
        };
        window.switchPage._aqHealthHooked = true;
      }

      // Initial inject
      setTimeout(injectBadges, 800);
    }, 'initPondHealthScore');
  }

  /* ═══════════════════════════════════════════════════════════════
     K. FEED COST CALCULATOR — Live cost estimate on Log Feed page
     Shows estimated cost as user enters feed quantities. Uses inventory
     purchase prices for each feed size. Falls back to ₹34.5/kg if no data.
     ═══════════════════════════════════════════════════════════════ */
  function getFeedPriceMap() {
    var priceMap = {
      fs1: 34.5, fs2: 34.5, fs3: 34.5, fs4: 34.5, fs5: 34.5, fso: 34.5
    };
    safe(function () {
      var inv = JSON.parse(localStorage.getItem('al_inventory') || '[]');
      var sizeMap = { 'Feed Size 1': 'fs1', 'Feed Size 2': 'fs2', 'Feed Size 3': 'fs3', 'Feed Size 4': 'fs4', 'Feed Size 5': 'fs5' };
      (inv || []).forEach(function (t) {
        if (t && t.type === 'purchase' && t.category === 'feed' && t.unitPrice) {
          var key = sizeMap[t.itemName];
          if (key) priceMap[key] = t.unitPrice;
        }
      });
    });
    return priceMap;
  }

  function initFeedCostCalculator() {
    safe(function () {
      function injectCalculator() {
        var logPage = document.getElementById('pageLog');
        if (!logPage || !logPage.classList.contains('active')) return;
        var form = document.getElementById('feedForm');
        if (!form) return;
        if (form.querySelector('.aq-cost-calc')) return; // already injected

        var calc = document.createElement('div');
        calc.className = 'aq-cost-calc';
        calc.innerHTML =
          '<div class="aq-cost-calc-header">' +
            '<span class="aq-cost-calc-icon">💰</span>' +
            '<span class="aq-cost-calc-title">Cost Estimate · लागत</span>' +
          '</div>' +
          '<div class="aq-cost-calc-body">' +
            '<div class="aq-cost-calc-row" id="aqCostBreakdown"></div>' +
            '<div class="aq-cost-calc-total">' +
              '<span class="aq-cost-calc-total-label">Total</span>' +
              '<span class="aq-cost-calc-total-value" id="aqCostTotal">₹0</span>' +
            '</div>' +
          '</div>';
        form.insertBefore(calc, form.querySelector('.form-actions') || form.lastChild);

        updateCalculator();
      }

      function updateCalculator() {
        var breakdown = document.getElementById('aqCostBreakdown');
        var totalEl = document.getElementById('aqCostTotal');
        if (!breakdown || !totalEl) return;

        var prices = getFeedPriceMap();
        var total = 0;
        var lines = [];

        ['fs1', 'fs2', 'fs3', 'fs4', 'fs5'].forEach(function (fs) {
          var cb = document.getElementById('cb_' + fs);
          var qty = document.getElementById('qty_' + fs);
          if (cb && cb.checked && qty && qty.value && parseFloat(qty.value) > 0) {
            var grams = parseFloat(qty.value);
            var kg = grams / 1000;
            var cost = kg * prices[fs];
            total += cost;
            lines.push('<div class="aq-cost-line">' +
              '<span class="aq-cost-line-label">Size ' + fs.slice(-1) + '</span>' +
              '<span class="aq-cost-line-qty">' + grams + 'g (' + kg.toFixed(2) + ' kg)</span>' +
              '<span class="aq-cost-line-price">₹' + cost.toFixed(2) + '</span>' +
            '</div>');
          }
        });

        // Other feed
        var otherCb = document.getElementById('cb_other');
        var otherQty = document.getElementById('otherFeedQty');
        if (otherCb && otherCb.checked && otherQty && otherQty.value && parseFloat(otherQty.value) > 0) {
          var grams = parseFloat(otherQty.value);
          var kg = grams / 1000;
          var cost = kg * prices.fso;
          total += cost;
          lines.push('<div class="aq-cost-line">' +
            '<span class="aq-cost-line-label">Other</span>' +
            '<span class="aq-cost-line-qty">' + grams + 'g (' + kg.toFixed(2) + ' kg)</span>' +
            '<span class="aq-cost-line-price">₹' + cost.toFixed(2) + '</span>' +
          '</div>');
        }

        if (lines.length === 0) {
          breakdown.innerHTML = '<div class="aq-cost-empty">Check a feed size and enter quantity to see cost estimate</div>';
          totalEl.textContent = '₹0';
          totalEl.style.color = 'var(--t2)';
        } else {
          breakdown.innerHTML = lines.join('');
          totalEl.textContent = '₹' + total.toFixed(2);
          totalEl.style.color = 'var(--teal)';
        }
      }

      // Use event delegation for checkbox changes and input events
      document.body.addEventListener('change', function (e) {
        if (e.target.id && e.target.id.indexOf('cb_') === 0) {
          setTimeout(updateCalculator, 100); // wait for qty field to appear
        }
      });
      document.body.addEventListener('input', function (e) {
        if (e.target.id && (e.target.id.indexOf('qty_') === 0 || e.target.id === 'otherFeedQty')) {
          updateCalculator();
        }
      });

      // Inject when Log page becomes active
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqCostHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageLog') {
            setTimeout(injectCalculator, 300);
          }
          return r;
        };
        window.switchPage._aqCostHooked = true;
      }
    }, 'initFeedCostCalculator');
  }

  /* ═══════════════════════════════════════════════════════════════
     L. ACTIVITY TIMELINE — Chronological feed of recent actions
     Shows on the Dashboard (below Insights card). Aggregates:
     - Recent feed logs (last 5)
     - Recent batch events (created, completed)
     - Recent finance entries (expenses, revenue)
     - Recent inventory purchases
     Displays as a vertical timeline with icons and timestamps.
     ═══════════════════════════════════════════════════════════════ */
  function initActivityTimeline() {
    safe(function () {
      // ── Fix #7: Move Recent Activity to BOTTOM of dashboard ──
      // Previously inserted after the insights card (top of page). Now we
      // append it as the LAST visible child of .page-scroll so it appears
      // below all operational modules (tasks, insights, hero, batches,
      // sessions, analytics, etc.).
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-timeline-card')) return; // already inserted

        var card = document.createElement('div');
        card.className = 'aq-timeline-card aq-timeline-card--bottom';
        card.innerHTML =
          '<div class="aq-timeline-inner">' +
            '<div class="aq-timeline-header">' +
              '<span class="aq-timeline-icon">📜</span>' +
              '<span class="aq-timeline-title">Recent Activity</span>' +
            '</div>' +
            '<div class="aq-timeline-list" id="aqTimelineList"></div>' +
          '</div>';
        // Append at the bottom — Fix #7
        scroll.appendChild(card);
        refreshTimeline();
      }

      function refreshTimeline() {
        var card  = document.querySelector('.aq-timeline-card');
        var list  = document.getElementById('aqTimelineList');
        var titleEl = card ? card.querySelector('.aq-timeline-title') : null;
        var iconEl  = card ? card.querySelector('.aq-timeline-icon') : null;
        if (!list) return;

        var ctx = getDashboardContext();

        // ── Fix #11: For completed batches, render the Complete Batch Activity Log ──
        if (ctx.mode === 'batch' && ctx.isCompleted) {
          if (titleEl) titleEl.textContent = 'Complete Batch Activity Log';
          if (iconEl)  iconEl.textContent = '📒';
          var logEvents = buildCompletedBatchLog(ctx.batch);
          if (logEvents.length === 0) {
            list.innerHTML = '<div class="aq-timeline-empty">No historical events recorded for this batch.</div>';
            return;
          }
          list.innerHTML = logEvents.map(function (ev, i) {
            return '<div class="aq-timeline-item" style="animation-delay:' + (i * 0.04) + 's">' +
              '<div class="aq-timeline-dot aq-timeline-' + ev.type + '">' + ev.icon + '</div>' +
              '<div class="aq-timeline-content">' +
                '<div class="aq-timeline-title">' + escapeHtml(ev.title) + '</div>' +
                '<div class="aq-timeline-sub">' + escapeHtml(ev.sub) + '</div>' +
                '<div class="aq-timeline-time">' + escapeHtml(ev.timeAgo) + '</div>' +
              '</div>' +
            '</div>';
          }).join('');
          return;
        }

        // Default title
        if (titleEl) {
          titleEl.textContent = ctx.mode === 'batch' && ctx.pond
            ? 'Recent Activity · ' + ctx.pond.name
            : 'Recent Activity · हाल की गतिविधि';
        }
        if (iconEl) iconEl.textContent = '📜';

        var events = buildTimelineEvents();
        if (events.length === 0) {
          list.innerHTML = '<div class="aq-timeline-empty">' +
            (ctx.mode === 'batch'
              ? 'No data available for this pond yet.'
              : 'No recent activity. Start logging feed to see your timeline!') +
          '</div>';
          return;
        }
        list.innerHTML = events.map(function (ev, i) {
          return '<div class="aq-timeline-item" style="animation-delay:' + (i * 0.05) + 's">' +
            '<div class="aq-timeline-dot aq-timeline-' + ev.type + '">' + ev.icon + '</div>' +
            '<div class="aq-timeline-content">' +
              '<div class="aq-timeline-title">' + escapeHtml(ev.title) + '</div>' +
              '<div class="aq-timeline-sub">' + escapeHtml(ev.sub) + '</div>' +
              '<div class="aq-timeline-time">' + escapeHtml(ev.timeAgo) + '</div>' +
            '</div>' +
          '</div>';
        }).join('');
      }

      // ── Fix #10: buildTimelineEvents filters by selected batch/pond when in batch mode ──
      function buildTimelineEvents() {
        var events = [];
        safe(function () {
          var ctx = getDashboardContext();
          var now = new Date();
          var records   = JSON.parse(localStorage.getItem('al_records') || '[]') || [];
          var batches   = JSON.parse(localStorage.getItem('al_batches') || '[]') || [];
          var expenses  = JSON.parse(localStorage.getItem('al_finance_expenses') || '[]') || [];
          var revenue   = JSON.parse(localStorage.getItem('al_finance_revenue') || '[]') || [];
          var inv       = JSON.parse(localStorage.getItem('al_inventory') || '[]') || [];
          var sampling  = JSON.parse(localStorage.getItem('al_sampling') || '[]') || [];
          var growth    = JSON.parse(localStorage.getItem('al_growth') || '[]') || [];
          var mortality = JSON.parse(localStorage.getItem('al_mortality') || '[]') || [];
          var water     = JSON.parse(localStorage.getItem('al_water_quality') || '[]') || [];

          // Build a pond name map
          var pondMap = {};
          try {
            var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]') || [];
            ponds.forEach(function (p) { pondMap[p.id] = p.name; });
          } catch (_) {}

          // ── Pond/Batch filter (Fix #10) ──
          var filterBatchId = ctx.batch ? ctx.batch.id : null;
          var filterPondId  = ctx.batch ? ctx.batch.pondId : null;

          // Recent feed logs — filtered by batch when applicable
          var batchRecs = filterBatchId
            ? records.filter(function (r) { return r && recBatchId(r) === filterBatchId; })
            : records;
          var recentRecords = batchRecs.slice(-8).reverse();
          recentRecords.forEach(function (r) {
            if (!r) return;
            var pondName = pondMap[recPondId(r)] || recPondId(r) || 'Pond';
            var qty = recQty(r);
            events.push({
              type: 'feed',
              icon: '🍽',
              title: 'Feed logged: ' + pondName,
              sub: (recTime(r) || '') + ' · ' + (qty > 1000 ? (qty / 1000).toFixed(1) + ' kg' : qty + ' g'),
              timestamp: parseFeedDate(recDate(r), recTime(r)),
              sortKey: recDate(r) + recTime(r)
            });
          });

          // Recent batch events
          batches.forEach(function (b) {
            if (!b) return;
            if (filterBatchId && b.id !== filterBatchId) return;
            if (b.createdAt) {
              events.push({
                type: 'batch',
                icon: '🐟',
                title: 'Batch created: ' + (b.pond || 'Pond'),
                sub: 'Batch #' + (b.batchNumber || '?') + ' · ' + (b.shrimpCount || 0).toLocaleString() + ' shrimp stocked',
                timestamp: new Date(b.createdAt),
                sortKey: b.createdAt
              });
            }
            if (b.completedAt) {
              events.push({
                type: 'harvest',
                icon: '🎯',
                title: 'Batch harvested: ' + (b.pond || 'Pond'),
                sub: 'Batch #' + (b.batchNumber || '?') + ' · ' + (b.harvestWeightKg || 0) + ' kg · ' + (b.survivalPercent || 0) + '% survival',
                timestamp: new Date(b.completedAt),
                sortKey: b.completedAt
              });
            }
          });

          // Recent sampling events (filtered by batch when applicable)
          var batchSampling = filterBatchId
            ? sampling.filter(function (s) { return s && s.batchId === filterBatchId; })
            : sampling;
          var recentSampling = batchSampling.slice(-5).reverse();
          recentSampling.forEach(function (s) {
            if (!s || !s.date) return;
            var pondName = filterBatchId && ctx.pond ? ctx.pond.name : (s.pondName || 'Pond');
            events.push({
              type: 'sampling',
              icon: '🔬',
              title: 'Sampling: ' + pondName,
              sub: 'ABW ' + (s.abw || 0).toFixed(2) + 'g · ' + (s.survivalPercent !== undefined ? s.survivalPercent + '% survival · ' : '') + 'DOC ' + (s.doc || '?'),
              timestamp: new Date(s.date + 'T12:00:00'),
              sortKey: s.date + '_sampling'
            });
          });

          // Recent visual weight entries (filtered by batch when applicable)
          var batchGrowth = filterBatchId
            ? growth.filter(function (g) { return g && g.batchId === filterBatchId; })
            : growth;
          var recentGrowth = batchGrowth.slice(-5).reverse();
          recentGrowth.forEach(function (g) {
            if (!g || !g.date) return;
            var pondName = filterBatchId && ctx.pond ? ctx.pond.name : (g.pondName || 'Pond');
            events.push({
              type: 'weight',
              icon: '⚖',
              title: 'Visual weight: ' + pondName,
              sub: (g.weightGrams || 0).toFixed(2) + 'g · DOC ' + (g.doc || '?'),
              timestamp: new Date(g.date + 'T11:00:00'),
              sortKey: g.date + '_weight'
            });
          });

          // Recent mortality events (filtered by batch when applicable)
          var batchMort = filterBatchId
            ? mortality.filter(function (m) { return m && m.batchId === filterBatchId; })
            : mortality;
          batchMort.slice(-5).reverse().forEach(function (m) {
            if (!m || !m.date) return;
            var pondName = filterBatchId && ctx.pond ? ctx.pond.name : (m.pondName || 'Pond');
            events.push({
              type: 'mortality',
              icon: '⚠',
              title: 'Mortality: ' + pondName,
              sub: (m.count || 0) + ' shrimp' + (m.cause ? ' · ' + m.cause : ''),
              timestamp: new Date(m.date + 'T15:00:00'),
              sortKey: m.date + '_mortality'
            });
          });

          // Recent expenses — filter by batch when applicable
          var batchExp = filterBatchId
            ? expenses.filter(function (e) { return e && e.batchId === filterBatchId; })
            : expenses;
          var recentExp = batchExp.slice(-5).reverse();
          recentExp.forEach(function (e) {
            if (!e || !e.date) return;
            events.push({
              type: 'expense',
              icon: '💸',
              title: 'Expense: ' + (e.category || e.description || 'Item'),
              sub: '₹' + (e.amount || 0).toLocaleString('en-IN'),
              timestamp: new Date(e.date),
              sortKey: e.date + '_expense'
            });
          });

          // Recent revenue — filter by batch when applicable
          var batchRev = filterBatchId
            ? revenue.filter(function (r) { return r && r.batchId === filterBatchId; })
            : revenue;
          var recentRev = batchRev.slice(-5).reverse();
          recentRev.forEach(function (r) {
            if (!r || !r.date) return;
            events.push({
              type: 'revenue',
              icon: '💰',
              title: 'Revenue: ' + (r.buyer || r.category || 'Sale'),
              sub: '₹' + (r.amount || 0).toLocaleString('en-IN'),
              timestamp: new Date(r.date),
              sortKey: r.date + '_revenue'
            });
          });

          // Recent water quality (filtered by pond when applicable)
          var batchWater = filterPondId
            ? water.filter(function (w) { return w && (w.pondId === filterPondId || w.PondId === filterPondId); })
            : water;
          batchWater.slice(-5).reverse().forEach(function (w) {
            if (!w) return;
            var d = w.date || w.Date;
            if (!d) return;
            var pondName = filterBatchId && ctx.pond ? ctx.pond.name : (w.pondName || 'Pond');
            var bits = [];
            if (w.ph !== undefined) bits.push('pH ' + w.ph);
            if (w.temperature !== undefined) bits.push(w.temperature + '°C');
            if (w.dissolvedOxygen !== undefined) bits.push('DO ' + w.dissolvedOxygen);
            if (w.ammonia !== undefined) bits.push('NH₃ ' + w.ammonia);
            events.push({
              type: 'water',
              icon: '💧',
              title: 'Water quality: ' + pondName,
              sub: bits.join(' · ') || 'Reading recorded',
              timestamp: new Date(d + 'T10:00:00'),
              sortKey: d + '_water'
            });
          });

          // Recent inventory purchases — only on Farm view (cross-cutting)
          if (ctx.mode === 'farm') {
            var recentInv = inv.filter(function (t) { return t && t.type === 'purchase'; }).slice(-5).reverse();
            recentInv.forEach(function (t) {
              if (!t || !t.purchaseDate) return;
              events.push({
                type: 'purchase',
                icon: '📦',
                title: 'Stock purchased: ' + (t.itemName || 'Item'),
                sub: (t.quantity || 0) + ' ' + (t.unit || '') + ' · ₹' + (t.totalCost || 0).toLocaleString('en-IN'),
                timestamp: new Date(t.purchaseDate),
                sortKey: t.purchaseDate + '_purchase'
              });
            });
          }

          // Sort by timestamp descending
          events.sort(function (a, b) { return b.timestamp - a.timestamp; });

          // Format time ago and take top 12
          events = events.slice(0, 12).map(function (ev) {
            ev.timeAgo = formatTimeAgo(ev.timestamp);
            return ev;
          });
        });
        return events;
      }

      // ── Fix #11: Build full chronological activity log for completed batches ──
      // Includes EVERY recorded event for this batch: creation, feed sessions,
      // sampling records, visual weight updates, mortality entries, medicines/
      // supplements, expenses, water quality records, notes, harvest, completion.
      function buildCompletedBatchLog(batch) {
        var events = [];
        if (!batch) return events;
        safe(function () {
          var batchId = batch.id;
          var records   = JSON.parse(localStorage.getItem('al_records') || '[]') || [];
          var sampling  = JSON.parse(localStorage.getItem('al_sampling') || '[]') || [];
          var growth    = JSON.parse(localStorage.getItem('al_growth') || '[]') || [];
          var mortality = JSON.parse(localStorage.getItem('al_mortality') || '[]') || [];
          var expenses  = JSON.parse(localStorage.getItem('al_finance_expenses') || '[]') || [];
          var revenue   = JSON.parse(localStorage.getItem('al_finance_revenue') || '[]') || [];
          var water     = JSON.parse(localStorage.getItem('al_water_quality') || '[]') || [];
          var pondName  = batch.pond || 'Pond';

          // Batch creation
          if (batch.createdAt) {
            events.push({
              type: 'batch',
              icon: '🐟',
              title: 'Batch created',
              sub: 'Batch #' + (batch.batchNumber || '?') + ' · ' + (batch.shrimpCount || 0).toLocaleString() + ' shrimp stocked on ' + (batch.stockingDate || '?'),
              timestamp: new Date(batch.createdAt),
              sortKey: batch.createdAt
            });
          }

          // All feed sessions
          records.filter(function (r) { return r && recBatchId(r) === batchId; })
                 .forEach(function (r) {
            var qty = recQty(r);
            events.push({
              type: 'feed',
              icon: '🍽',
              title: 'Feed logged',
              sub: (recTime(r) || '') + ' · ' + (qty > 1000 ? (qty / 1000).toFixed(2) + ' kg' : qty + ' g'),
              timestamp: parseFeedDate(recDate(r), recTime(r)),
              sortKey: recDate(r) + recTime(r)
            });
          });

          // All sampling records
          sampling.filter(function (s) { return s && s.batchId === batchId; })
                  .forEach(function (s) {
            events.push({
              type: 'sampling',
              icon: '🔬',
              title: 'Sampling recorded',
              sub: 'ABW ' + (s.abw || 0).toFixed(2) + 'g · DOC ' + (s.doc || '?') + (s.survivalPercent !== undefined ? ' · ' + s.survivalPercent + '% survival' : ''),
              timestamp: new Date(s.date + 'T12:00:00'),
              sortKey: s.date + '_sampling'
            });
          });

          // All visual weight entries
          growth.filter(function (g) { return g && g.batchId === batchId; })
                .forEach(function (g) {
            events.push({
              type: 'weight',
              icon: '⚖',
              title: 'Visual weight logged',
              sub: (g.weightGrams || 0).toFixed(2) + 'g · DOC ' + (g.doc || '?'),
              timestamp: new Date(g.date + 'T11:00:00'),
              sortKey: g.date + '_weight'
            });
          });

          // Mortality entries
          mortality.filter(function (m) { return m && m.batchId === batchId; })
                   .forEach(function (m) {
            events.push({
              type: 'mortality',
              icon: '⚠',
              title: 'Mortality recorded',
              sub: (m.count || 0) + ' shrimp' + (m.cause ? ' · ' + m.cause : ''),
              timestamp: new Date(m.date + 'T15:00:00'),
              sortKey: m.date + '_mortality'
            });
          });

          // Expenses
          expenses.filter(function (e) { return e && e.batchId === batchId; })
                  .forEach(function (e) {
            events.push({
              type: 'expense',
              icon: '💸',
              title: 'Expense: ' + (e.category || e.description || 'Item'),
              sub: '₹' + (e.amount || 0).toLocaleString('en-IN'),
              timestamp: new Date(e.date),
              sortKey: e.date + '_expense'
            });
          });

          // Water quality (by pond)
          water.filter(function (w) { return w && (w.pondId === batch.pondId || w.PondId === batch.pondId); })
               .forEach(function (w) {
            var d = w.date || w.Date;
            if (!d) return;
            var bits = [];
            if (w.ph !== undefined) bits.push('pH ' + w.ph);
            if (w.temperature !== undefined) bits.push(w.temperature + '°C');
            if (w.dissolvedOxygen !== undefined) bits.push('DO ' + w.dissolvedOxygen);
            if (w.ammonia !== undefined) bits.push('NH₃ ' + w.ammonia);
            events.push({
              type: 'water',
              icon: '💧',
              title: 'Water quality recorded',
              sub: bits.join(' · ') || 'Reading recorded',
              timestamp: new Date(d + 'T10:00:00'),
              sortKey: d + '_water'
            });
          });

          // Revenue (sale events for this batch)
          revenue.filter(function (r) { return r && r.batchId === batchId; })
                 .forEach(function (r) {
            events.push({
              type: 'revenue',
              icon: '💰',
              title: 'Sale recorded',
              sub: '₹' + (r.amount || 0).toLocaleString('en-IN') + (r.buyer ? ' · ' + r.buyer : ''),
              timestamp: new Date(r.date),
              sortKey: r.date + '_revenue'
            });
          });

          // Harvest / completion
          if (batch.completedAt) {
            events.push({
              type: 'harvest',
              icon: '🎯',
              title: 'Batch completed (Harvest)',
              sub: 'Batch #' + (batch.batchNumber || '?') + ' · ' + (batch.harvestWeightKg || 0) + ' kg · ' + (batch.survivalPercent || 0) + '% survival' + (batch.harvestDate ? ' · ' + batch.harvestDate : ''),
              timestamp: new Date(batch.completedAt),
              sortKey: batch.completedAt
            });
          }

          // Sort chronologically (oldest first for completed-batch log)
          events.sort(function (a, b) { return a.timestamp - b.timestamp; });
          events.forEach(function (ev) { ev.timeAgo = formatTimeAgo(ev.timestamp); });
        });
        return events;
      }

      function formatTimeAgo(date) {
        try {
          var now = new Date();
          var diff = (now - date) / 1000; // seconds
          if (diff < 60) return 'Just now';
          if (diff < 3600) return Math.floor(diff / 60) + ' min ago';
          if (diff < 86400) return Math.floor(diff / 3600) + ' hr ago';
          if (diff < 604800) return Math.floor(diff / 86400) + ' day' + (Math.floor(diff / 86400) > 1 ? 's' : '') + ' ago';
          if (diff < 2592000) return Math.floor(diff / 604800) + ' wk ago';
          return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
        } catch (_) { return ''; }
      }

      function parseFeedDate(dateStr, timeStr) {
        try {
          if (!dateStr) return new Date(0);
          var timePart = '12:00:00';
          if (timeStr) {
            var m = timeStr.match(/(\d+):(\d+)\s*(AM|PM)/i);
            if (m) {
              var h = parseInt(m[1], 10);
              var min = m[2];
              var ap = m[3].toUpperCase();
              if (ap === 'PM' && h !== 12) h += 12;
              if (ap === 'AM' && h === 12) h = 0;
              timePart = ('0' + h).slice(-2) + ':' + min + ':00';
            }
          }
          return new Date(dateStr + 'T' + timePart);
        } catch (_) { return new Date(0); }
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      // Hook switchPage
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqTimelineHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(function () { inject(); refreshTimeline(); }, 150);
          }
          return r;
        };
        window.switchPage._aqTimelineHooked = true;
      }

      // Expose refresh globally so the dashboard context-change listener can call it
      window.refreshAquaTimeline = function () {
        try { inject(); refreshTimeline(); } catch (e) {}
      };

      setTimeout(function () { inject(); refreshTimeline(); }, 700);
    }, 'initActivityTimeline');
  }

  /* ═══════════════════════════════════════════════════════════════
     M. HARVEST PREDICTOR — Predicts harvest date & weight from growth data
     Shows on batch detail view (when a batch is selected in context selector).
     Uses sampling data (dailyGrowth, abw) to project:
       - Estimated harvest date (when ABW reaches target ~18g)
       - Estimated harvest weight (shrimpCount × target ABW)
       - Days remaining and growth trajectory
     ═══════════════════════════════════════════════════════════════ */
  function calcHarvestPrediction(batchId) {
    var prediction = null;
    safe(function () {
      var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
      var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
      var batch = (batches || []).find(function (b) { return b && b.id === batchId; });
      if (!batch || batch.completedAt) return;

      var batchSampling = (sampling || []).filter(function (s) {
        return s && s.batchId === batchId;
      }).sort(function (a, b) { return new Date(a.date) - new Date(b.date); });

      if (batchSampling.length === 0) return;

      var lastSample = batchSampling[batchSampling.length - 1];
      var currentABW = lastSample.abw || 0;
      var dailyGrowth = lastSample.dailyGrowth || 0.05; // default 0.05g/day if no trend
      var shrimpCount = batch.shrimpCount || batch.finalShrimpCount || 0;

      // Target harvest weight: 18g (standard for shrimp)
      var targetABW = 18;
      var remainingGrowth = targetABW - currentABW;
      var daysToHarvest = dailyGrowth > 0 ? Math.ceil(remainingGrowth / dailyGrowth) : 0;

      var today = new Date();
      var harvestDate = new Date(today);
      harvestDate.setDate(harvestDate.getDate() + daysToHarvest);

      // Estimate survival (use historical average or 85% default)
      var survivalRate = 0.85;
      var completedBatches = (batches || []).filter(function (b) {
        return b && b.pondId === batch.pondId && b.completedAt && b.survivalPercent;
      });
      if (completedBatches.length > 0) {
        survivalRate = completedBatches.reduce(function (s, b) { return s + b.survivalPercent; }, 0) / completedBatches.length / 100;
      }

      var estimatedHarvestWeight = Math.round(shrimpCount * survivalRate * targetABW / 1000); // kg

      // Growth trajectory (last 5 samplings)
      var trajectory = batchSampling.slice(-5).map(function (s) {
        return { doc: s.doc, abw: s.abw };
      });

      prediction = {
        batchName: batch.pond || 'Batch',
        batchNumber: batch.batchNumber,
        currentABW: currentABW,
        targetABW: targetABW,
        dailyGrowth: dailyGrowth,
        daysToHarvest: daysToHarvest,
        harvestDate: harvestDate,
        estimatedWeight: estimatedHarvestWeight,
        shrimpCount: shrimpCount,
        survivalRate: Math.round(survivalRate * 100),
        trajectory: trajectory,
        progress: Math.round((currentABW / targetABW) * 100)
      };
    });
    return prediction;
  }

  function initHarvestPredictor() {
    safe(function () {
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard || !dashboard.classList.contains('active')) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;

        // Only show when a batch is selected (not farm overview)
        var contextSel = document.getElementById('dashboardContextSelect');
        if (!contextSel || contextSel.value === 'farm' || contextSel.value.indexOf('batch_') === -1) {
          var existing = scroll.querySelector('.aq-harvest-card');
          if (existing) existing.remove();
          return;
        }

        // Context selector value has 'batch_' prefix; actual batch ID is after that
        var batchId = contextSel.value.replace(/^batch_/, '');
        var prediction = calcHarvestPrediction(batchId);
        if (!prediction) return;

        // Remove old card, create new
        var old = scroll.querySelector('.aq-harvest-card');
        if (old) old.remove();

        var card = document.createElement('div');
        card.className = 'aq-harvest-card';

        var dateStr = prediction.harvestDate.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
        var daysLabel = prediction.daysToHarvest === 0 ? 'Ready now!' :
          (prediction.daysToHarvest < 0 ? 'Overdue by ' + Math.abs(prediction.daysToHarvest) + ' days' :
           prediction.daysToHarvest + ' days remaining');

        // Build trajectory mini-chart
        var trajectoryHTML = '';
        if (prediction.trajectory.length > 1) {
          var maxABW = Math.max.apply(null, prediction.trajectory.map(function (t) { return t.abw; }));
          var targetABW = prediction.targetABW;
          var chartMax = Math.max(maxABW, targetABW);
          trajectoryHTML = '<div class="aq-harvest-trajectory">' +
            '<div class="aq-harvest-traj-label">Growth Trajectory</div>' +
            '<div class="aq-harvest-traj-chart">' +
              prediction.trajectory.map(function (t) {
                var h = Math.round((t.abw / chartMax) * 60);
                return '<div class="aq-harvest-traj-bar" style="height:' + h + 'px;" title="DOC ' + t.doc + ': ' + t.abw.toFixed(1) + 'g">' +
                  '<span class="aq-harvest-traj-val">' + t.abw.toFixed(1) + '</span>' +
                '</div>';
              }).join('') +
              '<div class="aq-harvest-traj-bar aq-harvest-traj-target" style="height:' + Math.round((targetABW / chartMax) * 60) + 'px;" title="Target: ' + targetABW + 'g">' +
                '<span class="aq-harvest-traj-val">' + targetABW + '</span>' +
              '</div>' +
            '</div>' +
            '<div class="aq-harvest-traj-axis">' +
              prediction.trajectory.map(function (t) { return '<span>D' + t.doc + '</span>'; }).join('') +
              '<span>Target</span>' +
            '</div>' +
          '</div>';
        }

        card.innerHTML =
          '<div class="aq-harvest-inner">' +
            '<div class="aq-harvest-header">' +
              '<span class="aq-harvest-icon">🎯</span>' +
              '<span>Harvest Predictor · कटाई अनुमान</span>' +
            '</div>' +
            '<div class="aq-harvest-body">' +
              '<div class="aq-harvest-progress-ring">' +
                '<svg viewBox="0 0 60 60">' +
                  '<circle cx="30" cy="30" r="24" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="5"/>' +
                  '<circle cx="30" cy="30" r="24" fill="none" stroke="var(--teal)" stroke-width="5" stroke-linecap="round" stroke-dasharray="' + (prediction.progress / 100 * 150.8) + ' 150.8" transform="rotate(-90 30 30)"/>' +
                '</svg>' +
                '<span class="aq-harvest-progress-val">' + prediction.progress + '%</span>' +
              '</div>' +
              '<div class="aq-harvest-stats">' +
                '<div class="aq-harvest-stat">' +
                  '<div class="aq-harvest-stat-label">Current ABW</div>' +
                  '<div class="aq-harvest-stat-value">' + prediction.currentABW.toFixed(2) + 'g</div>' +
                '</div>' +
                '<div class="aq-harvest-stat">' +
                  '<div class="aq-harvest-stat-label">Daily Growth</div>' +
                  '<div class="aq-harvest-stat-value">' + prediction.dailyGrowth.toFixed(3) + 'g/day</div>' +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="aq-harvest-prediction">' +
              '<div class="aq-harvest-pred-row">' +
                '<span class="aq-harvest-pred-icon">📅</span>' +
                '<div><div class="aq-harvest-pred-label">Est. Harvest Date</div>' +
                '<div class="aq-harvest-pred-value">' + dateStr + '</div></div>' +
                '<span class="aq-harvest-pred-badge">' + daysLabel + '</span>' +
              '</div>' +
              '<div class="aq-harvest-pred-row">' +
                '<span class="aq-harvest-pred-icon">⚖️</span>' +
                '<div><div class="aq-harvest-pred-label">Est. Harvest Weight</div>' +
                '<div class="aq-harvest-pred-value">' + prediction.estimatedWeight + ' kg</div></div>' +
                '<span class="aq-harvest-pred-badge">' + prediction.shrimpCount.toLocaleString() + ' shrimp</span>' +
              '</div>' +
              '<div class="aq-harvest-pred-row">' +
                '<span class="aq-harvest-pred-icon">📊</span>' +
                '<div><div class="aq-harvest-pred-label">Est. Survival Rate</div>' +
                '<div class="aq-harvest-pred-value">' + prediction.survivalRate + '%</div></div>' +
              '</div>' +
            '</div>' +
            trajectoryHTML +
          '</div>';

        // Insert after the batch summary card (which is OUTSIDE farmOverviewContent)
        var batchSummary = document.getElementById('batchSummaryCard') || scroll.querySelector('.batch-summary-card');
        if (batchSummary && batchSummary.parentNode) {
          try { batchSummary.parentNode.appendChild(card); } catch (_) { scroll.appendChild(card); }
        } else {
          scroll.appendChild(card);
        }
      }

      // Hook switchPage and context selector change
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqHarvestHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(inject, 600);
            setTimeout(inject, 1500);
          }
          return r;
        };
        window.switchPage._aqHarvestHooked = true;
      }

      // Also hook context selector changes
      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'dashboardContextSelect') {
          setTimeout(inject, 600);
          setTimeout(inject, 1500);
        }
      });

      // Periodic re-inject via unified checker
      registerPeriodicCheck(function () {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard || !dashboard.classList.contains('active')) return;
        var contextSel = document.getElementById('dashboardContextSelect');
        if (!contextSel || contextSel.value.indexOf('batch_') === -1) return;
        if (!dashboard.querySelector('.aq-harvest-card')) {
          inject();
        }
      }, 'harvestPredictor');
    }, 'initHarvestPredictor');
  }

  /* ═══════════════════════════════════════════════════════════════
     N. BATCH COMPARISON TOOL — Side-by-side comparison of active batches
     Accessible via a button on the Manage page. Shows a modal overlay
     comparing all active batches: DOC, ABW, feed total, FCR, health score.
     ═══════════════════════════════════════════════════════════════ */
  function initBatchComparison() {
    safe(function () {
      function injectButton() {
        var managePage = document.getElementById('pageManage');
        if (!managePage || !managePage.classList.contains('active')) return;
        var scroll = managePage.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-compare-btn-wrap')) return;

        var wrap = document.createElement('div');
        wrap.className = 'aq-compare-btn-wrap';
        wrap.innerHTML = '<button class="aq-compare-btn" id="aqBatchCompareBtn">' +
          '<span class="aq-compare-btn-icon">⚖️</span>' +
          '<span>Compare Batches · तुलना</span>' +
        '</button>';
        // Insert at the top of the manage page
        var firstChild = scroll.firstChild;
        scroll.insertBefore(wrap, firstChild);
      }

      function showComparisonModal() {
        var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
        var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
        var records = JSON.parse(localStorage.getItem('al_records') || '[]');
        var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]');

        var pondMap = {};
        (ponds || []).forEach(function (p) { pondMap[p.id] = p.name; });

        var activeBatches = (batches || []).filter(function (b) { return b && !b.completedAt; });
        if (activeBatches.length < 2) {
          if (typeof window.showToast === 'function') {
            window.showToast('⚠️', 'Need 2+ Active Batches', 'Compare requires at least 2 active batches.', 'warn', 2800);
          }
          return;
        }

        var today = new Date();
        var rows = activeBatches.map(function (b) {
          var start = new Date(b.stockingDate || b.createdAt);
          var doc = Math.floor((today - start) / (1000 * 60 * 60 * 24));
          var batchSampling = (sampling || []).filter(function (s) { return s && s.batchId === b.id; });
          var lastSample = batchSampling.length > 0 ? batchSampling[batchSampling.length - 1] : null;
          var abw = lastSample ? lastSample.abw : 0;
          var dailyGrowth = lastSample ? (lastSample.dailyGrowth || 0) : 0;

          // Feed total for this batch's pond
          var batchRecords = (records || []).filter(function (r) {
            return r && r.pondId === b.pondId;
          });
          var feedTotal = batchRecords.reduce(function (s, r) { return s + (parseFloat(r.totalQty || r.total || 0)); }, 0);

          // Health score
          var health = calcPondHealthScore(b.pondId);

          return {
            id: b.id,
            pond: pondMap[b.pondId] || b.pond || 'Pond',
            batchNum: b.batchNumber,
            doc: doc,
            abw: abw,
            dailyGrowth: dailyGrowth,
            feedTotal: feedTotal,
            shrimpCount: b.shrimpCount || 0,
            health: health.score,
            healthInfo: healthScoreColor(health.score)
          };
        });

        var overlay = document.createElement('div');
        overlay.className = 'aq-compare-overlay';
        overlay.innerHTML =
          '<div class="aq-compare-modal">' +
            '<div class="aq-compare-modal-header">' +
              '<span class="aq-compare-modal-icon">⚖️</span>' +
              '<div><div class="aq-compare-modal-title">Batch Comparison</div>' +
              '<div class="aq-compare-modal-sub">' + rows.length + ' active batches · side-by-side</div></div>' +
              '<button class="aq-compare-modal-close">✕</button>' +
            '</div>' +
            '<div class="aq-compare-modal-body">' +
              renderComparisonTable(rows) +
            '</div>' +
          '</div>';

        function renderComparisonTable(rows) {
          // Find best in each metric for highlighting
          var bestABW = Math.max.apply(null, rows.map(function (r) { return r.abw; }));
          var bestGrowth = Math.max.apply(null, rows.map(function (r) { return r.dailyGrowth; }));
          var bestHealth = Math.max.apply(null, rows.map(function (r) { return r.health; }));

          var header = '<div class="aq-compare-row aq-compare-header">' +
            '<div class="aq-compare-cell aq-compare-cell-label">Metric</div>' +
            rows.map(function (r) {
              return '<div class="aq-compare-cell"><div class="aq-compare-cell-pond">' + escapeHtml(r.pond) + '</div><div class="aq-compare-cell-batch">Batch #' + r.batchNum + '</div></div>';
            }).join('') +
          '</div>';

          function metricRow(label, values, best, fmt) {
            return '<div class="aq-compare-row">' +
              '<div class="aq-compare-cell aq-compare-cell-label">' + label + '</div>' +
              values.map(function (v, i) {
                var isBest = v === best && v > 0;
                return '<div class="aq-compare-cell' + (isBest ? ' aq-compare-best' : '') + '">' + fmt(v) + (isBest ? ' <span class="aq-compare-star">★</span>' : '') + '</div>';
              }).join('') +
            '</div>';
          }

          // Health score row with mini rings
          var healthRow = '<div class="aq-compare-row">' +
            '<div class="aq-compare-cell aq-compare-cell-label">Health Score</div>' +
            rows.map(function (r) {
              var isBest = r.health === bestHealth;
              return '<div class="aq-compare-cell' + (isBest ? ' aq-compare-best' : '') + '">' +
                '<div class="aq-compare-health" style="color:' + r.healthInfo.color + ';">' +
                  '<div class="aq-compare-health-ring" style="background: conic-gradient(' + r.healthInfo.color + ' ' + (r.health * 3.6) + 'deg, rgba(255,255,255,0.08) 0deg);">' +
                    '<span>' + r.health + '</span>' +
                  '</div>' +
                  '<span class="aq-compare-health-label">' + r.healthInfo.label + '</span>' +
                '</div>' +
              '</div>';
            }).join('') +
          '</div>';

          return '<div class="aq-compare-table">' +
            header +
            metricRow('DOC (Days)', rows.map(function (r) { return r.doc; }), 999, function (v) { return v; }) +
            metricRow('ABW (g)', rows.map(function (r) { return r.abw; }), bestABW, function (v) { return v.toFixed(2); }) +
            metricRow('Daily Growth', rows.map(function (r) { return r.dailyGrowth; }), bestGrowth, function (v) { return v.toFixed(3) + 'g'; }) +
            metricRow('Shrimp Count', rows.map(function (r) { return r.shrimpCount; }), 0, function (v) { return v.toLocaleString(); }) +
            metricRow('Feed Total', rows.map(function (r) { return r.feedTotal; }), 0, function (v) { return v > 1000 ? (v / 1000).toFixed(0) + ' kg' : v + ' g'; }) +
            healthRow +
          '</div>';
        }

        function escapeHtml(s) {
          return String(s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
          });
        }

        document.body.appendChild(overlay);
        requestAnimationFrame(function () { overlay.classList.add('aq-compare-open'); });

        function close() {
          overlay.classList.remove('aq-compare-open');
          setTimeout(function () { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, 250);
        }
        overlay.querySelector('.aq-compare-modal-close').addEventListener('click', close);
        overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
        var escHandler = function (e) { if (e.key === 'Escape') { close(); document.removeEventListener('keydown', escHandler); } };
        document.addEventListener('keydown', escHandler);
      }

      // Event delegation for the compare button
      document.body.addEventListener('click', function (e) {
        if (e.target.closest('#aqBatchCompareBtn')) {
          showComparisonModal();
        }
      });

      // Inject button when Manage page is active
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqCompareHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageManage') setTimeout(injectButton, 250);
          return r;
        };
        window.switchPage._aqCompareHooked = true;
      }
    }, 'initBatchComparison');
  }

  /* ═══════════════════════════════════════════════════════════════
     O. WEATHER FEED RECOMMENDATION — Smart feed tip based on weather
     Shows on dashboard when weather data is available. Suggests feeding
     adjustments based on temperature, rain probability, and humidity.
     ═══════════════════════════════════════════════════════════════ */
  function initWeatherFeedRec() {
    safe(function () {
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard || !dashboard.classList.contains('active')) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;

        // Only show on farm overview (not batch detail)
        var contextSel = document.getElementById('dashboardContextSelect');
        if (!contextSel || contextSel.value !== 'farm') {
          var existing = scroll.querySelector('.aq-weather-rec-card');
          if (existing) existing.remove();
          return;
        }

        if (scroll.querySelector('.aq-weather-rec-card')) return; // already there

        // Get weather data
        var weatherCache = {};
        try { weatherCache = JSON.parse(localStorage.getItem('al_weather_cache') || '{}'); } catch (_) {}
        var sites = [];
        try { sites = JSON.parse(localStorage.getItem('al_sites') || '[]'); } catch (_) {}
        if (sites.length === 0) return;

        // Get weather for first site
        var firstSite = sites[0];
        var siteWeather = weatherCache[firstSite.id];
        if (!siteWeather) return;
        // Weather cache can be either {temp, humidity, ...} or {current: {...}}
        var w = siteWeather.current || siteWeather;

        // Generate recommendation
        var recs = [];
        var feedAdjustment = 0; // percentage adjustment
        var urgency = 'normal';

        if (w.rainProbability > 70) {
          recs.push({ icon: '🌧', text: 'High rain probability (' + w.rainProbability + '%). Reduce feed by 30-40% — shrimp eat less during rain.', priority: 'high' });
          feedAdjustment -= 35;
          urgency = 'high';
        } else if (w.rainProbability > 40) {
          recs.push({ icon: '🌦', text: 'Moderate rain chance (' + w.rainProbability + '%). Reduce feed by 15-20% and monitor feeding behavior.', priority: 'medium' });
          feedAdjustment -= 18;
          urgency = 'medium';
        }

        if (w.temperature > 34) {
          recs.push({ icon: '🌡', text: 'High temperature (' + w.temperature + '°C). Feed early morning or late evening. Avoid midday feeding.', priority: 'high' });
          urgency = urgency === 'high' ? 'high' : 'medium';
        } else if (w.temperature < 24) {
          recs.push({ icon: '🥶', text: 'Cool temperature (' + w.temperature + '°C). Shrimp metabolism slows — reduce feed by 10%.', priority: 'medium' });
          feedAdjustment -= 10;
        }

        if (w.humidity > 85) {
          recs.push({ icon: '💧', text: 'Very humid (' + w.humidity + '%). Watch for oxygen drops — run aerators longer.', priority: 'low' });
        }

        if (w.windSpeed > 20) {
          recs.push({ icon: '💨', text: 'Strong wind (' + w.windSpeed + ' km/h). Secure feed trays and check for wave damage.', priority: 'low' });
        }

        // If no specific recommendations, add a positive one
        if (recs.length === 0) {
          recs.push({ icon: '✅', text: 'Weather conditions are favorable for normal feeding. No adjustments needed.', priority: 'good' });
        }

        var adjustmentText = feedAdjustment === 0 ? 'Normal feeding' :
          (feedAdjustment < 0 ? 'Reduce feed by ' + Math.abs(feedAdjustment) + '%' : 'Increase feed by ' + feedAdjustment + '%');

        var card = document.createElement('div');
        card.className = 'aq-weather-rec-card aq-weather-rec-' + urgency;
        card.innerHTML =
          '<div class="aq-weather-rec-inner">' +
            '<div class="aq-weather-rec-header">' +
              '<div class="aq-weather-rec-title-wrap">' +
                '<span class="aq-weather-rec-icon">🌤</span>' +
                '<div>' +
                  '<div class="aq-weather-rec-title">Weather Feed Advisory</div>' +
                  '<div class="aq-weather-rec-sub">' + escapeHtml(firstSite.name || 'Farm') + ' · ' + w.condition + '</div>' +
                '</div>' +
              '</div>' +
              '<div class="aq-weather-rec-temp">' +
                '<span class="aq-weather-rec-temp-val">' + w.temperature + '°</span>' +
                '<span class="aq-weather-rec-temp-sub">' + w.humidity + '% humidity</span>' +
              '</div>' +
            '</div>' +
            '<div class="aq-weather-rec-body">' +
              recs.map(function (r) {
                return '<div class="aq-weather-rec-item aq-weather-rec-item-' + r.priority + '">' +
                  '<span class="aq-weather-rec-item-icon">' + r.icon + '</span>' +
                  '<span class="aq-weather-rec-item-text">' + escapeHtml(r.text) + '</span>' +
                '</div>';
              }).join('') +
            '</div>' +
            '<div class="aq-weather-rec-footer">' +
              '<span class="aq-weather-rec-adjust-label">Recommended Feed Adjustment:</span>' +
              '<span class="aq-weather-rec-adjust-val' + (feedAdjustment < 0 ? ' aq-weather-rec-reduce' : (feedAdjustment > 0 ? ' aq-weather-rec-increase' : '')) + '">' + adjustmentText + '</span>' +
            '</div>' +
          '</div>';

        function escapeHtml(s) {
          return String(s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
          });
        }

        // Insert after insights card or timeline
        var anchor = scroll.querySelector('.aq-timeline-card') || scroll.querySelector('.aq-insights-card') || scroll.querySelector('.aq-tasks-card');
        if (anchor && anchor.nextSibling) {
          scroll.insertBefore(card, anchor.nextSibling);
        } else {
          scroll.appendChild(card);
        }
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqWeatherHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') setTimeout(inject, 200);
          return r;
        };
        window.switchPage._aqWeatherHooked = true;
      }
      // Also re-inject on context change
      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'dashboardContextSelect') setTimeout(inject, 200);
      });
    }, 'initWeatherFeedRec');
  }

  /* ═══════════════════════════════════════════════════════════════
     P. COST ANALYTICS DASHBOARD — Feed cost trends, cost per kg, ROI
     Inserts a comprehensive analytics card at the top of the Finance
     Overview tab. Shows: total feed cost, cost per kg shrimp, feed cost
     trend (monthly), ROI metrics, and cost breakdown by category.
     ═══════════════════════════════════════════════════════════════ */
  function initCostAnalytics() {
    safe(function () {
      function inject() {
        var finPage = document.getElementById('pageFinance');
        if (!finPage || !finPage.classList.contains('active')) return;
        // Find the overview tab panel (first visible tab-panel)
        var overviewPanel = finPage.querySelector('.tab-panel:not(.hidden)');
        if (!overviewPanel) return;
        if (overviewPanel.querySelector('.aq-cost-analytics')) return; // already injected

        var data = gatherCostData();
        if (!data) return;

        var card = document.createElement('div');
        card.className = 'aq-cost-analytics';
        card.innerHTML = buildAnalyticsHTML(data);
        overviewPanel.insertBefore(card, overviewPanel.firstChild);
      }

      function gatherCostData() {
        var data = null;
        safe(function () {
          var inv = JSON.parse(localStorage.getItem('al_inventory') || '[]');
          var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
          var expenses = JSON.parse(localStorage.getItem('al_finance_expenses') || '[]');
          var revenue = JSON.parse(localStorage.getItem('al_finance_revenue') || '[]');
          var records = JSON.parse(localStorage.getItem('al_records') || '[]');

          // Feed purchases
          var feedPurchases = (inv || []).filter(function (t) {
            return t && t.type === 'purchase' && t.category === 'feed';
          });
          var totalFeedCost = feedPurchases.reduce(function (s, t) { return s + (t.totalCost || 0); }, 0);
          var totalFeedQty = feedPurchases.reduce(function (s, t) { return s + (t.quantity || 0); }, 0);
          var avgPricePerKg = totalFeedQty > 0 ? totalFeedCost / totalFeedQty : 0;

          // Completed batches
          var completed = (batches || []).filter(function (b) { return b && b.completedAt; });
          var totalHarvestKg = completed.reduce(function (s, b) { return s + (b.harvestWeightKg || 0); }, 0);

          // Total feed consumed (from records)
          var totalFeedConsumed = (records || []).reduce(function (s, r) {
            return s + (parseFloat(r.totalQty || r.total || 0));
          }, 0);

          // Cost per kg shrimp (feed cost / harvest kg)
          var costPerKgShrimp = totalHarvestKg > 0 ? totalFeedCost / totalHarvestKg : 0;

          // Revenue and profit
          var totalRevenue = (revenue || []).reduce(function (s, r) { return s + (r.amount || 0); }, 0);
          var totalExpenses = (expenses || []).reduce(function (s, e) { return s + (e.amount || 0); }, 0);
          var totalAllCosts = totalFeedCost + totalExpenses;
          var netProfit = totalRevenue - totalAllCosts;
          var roi = totalAllCosts > 0 ? (netProfit / totalAllCosts * 100) : 0;
          var profitPerKg = totalHarvestKg > 0 ? netProfit / totalHarvestKg : 0;

          // Monthly feed cost trend (last 6 months)
          var monthlyTrend = [];
          var now = new Date();
          for (var i = 5; i >= 0; i--) {
            var d = new Date(now.getFullYear(), now.getMonth() - i, 1);
            var monthStart = new Date(d.getFullYear(), d.getMonth(), 1);
            var monthEnd = new Date(d.getFullYear(), d.getMonth() + 1, 0);
            var monthCost = feedPurchases.filter(function (t) {
              if (!t.purchaseDate) return false;
              var td = new Date(t.purchaseDate);
              return td >= monthStart && td <= monthEnd;
            }).reduce(function (s, t) { return s + (t.totalCost || 0); }, 0);
            monthlyTrend.push({
              month: d.toLocaleDateString('en-IN', { month: 'short' }),
              cost: monthCost
            });
          }

          // Cost breakdown by category
          var categoryBreakdown = {};
          (inv || []).filter(function (t) { return t && t.type === 'purchase'; }).forEach(function (t) {
            var cat = t.category || 'other';
            if (!categoryBreakdown[cat]) categoryBreakdown[cat] = 0;
            categoryBreakdown[cat] += t.totalCost || 0;
          });

          data = {
            totalFeedCost: totalFeedCost,
            totalFeedQty: totalFeedQty,
            avgPricePerKg: avgPricePerKg,
            totalHarvestKg: totalHarvestKg,
            totalFeedConsumed: totalFeedConsumed,
            costPerKgShrimp: costPerKgShrimp,
            totalRevenue: totalRevenue,
            totalExpenses: totalExpenses,
            totalAllCosts: totalAllCosts,
            netProfit: netProfit,
            roi: roi,
            profitPerKg: profitPerKg,
            monthlyTrend: monthlyTrend,
            categoryBreakdown: categoryBreakdown,
            completedBatches: completed.length
          };
        });
        return data;
      }

      function buildAnalyticsHTML(d) {
        function fmt(n) {
          if (Math.abs(n) >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
          if (Math.abs(n) >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
          if (Math.abs(n) >= 1000) return '₹' + (n / 1000).toFixed(1) + 'K';
          return '₹' + Math.round(n).toLocaleString('en-IN');
        }

        // Monthly trend mini bar chart
        var maxMonthCost = Math.max.apply(null, d.monthlyTrend.map(function (m) { return m.cost; }));
        var trendBars = d.monthlyTrend.map(function (m) {
          var h = maxMonthCost > 0 ? Math.round((m.cost / maxMonthCost) * 50) : 0;
          return '<div class="aq-ca-trend-bar" style="height:' + Math.max(h, 4) + 'px;">' +
            '<span class="aq-ca-trend-val">' + (m.cost > 0 ? fmt(m.cost) : '') + '</span>' +
          '</div>';
        }).join('');
        var trendLabels = d.monthlyTrend.map(function (m) {
          return '<span>' + m.month + '</span>';
        }).join('');

        // Category breakdown
        var totalCatCost = Object.values(d.categoryBreakdown).reduce(function (s, v) { return s + v; }, 0);
        var catColors = { feed: 'var(--teal)', medicine: 'var(--fs5)', fuel: 'var(--amber)', other: 'var(--cyan)' };
        var catRows = Object.keys(d.categoryBreakdown).map(function (cat) {
          var cost = d.categoryBreakdown[cat];
          var pct = totalCatCost > 0 ? (cost / totalCatCost * 100) : 0;
          var color = catColors[cat] || 'var(--t2)';
          return '<div class="aq-ca-cat-row">' +
            '<span class="aq-ca-cat-label">' + cat + '</span>' +
            '<div class="aq-ca-cat-bar-wrap">' +
              '<div class="aq-ca-cat-bar" style="width:' + pct + '%; background:' + color + ';"></div>' +
            '</div>' +
            '<span class="aq-ca-cat-val">' + fmt(cost) + ' (' + pct.toFixed(0) + '%)</span>' +
          '</div>';
        }).join('');

        return '<div class="aq-ca-inner">' +
          '<div class="aq-ca-header">' +
            '<span class="aq-ca-icon">📊</span>' +
            '<span>Cost Analytics · लागत विश्लेषण</span>' +
          '</div>' +
          '<div class="aq-ca-kpi-grid">' +
            '<div class="aq-ca-kpi">' +
              '<div class="aq-ca-kpi-label">Total Feed Cost</div>' +
              '<div class="aq-ca-kpi-value">' + fmt(d.totalFeedCost) + '</div>' +
              '<div class="aq-ca-kpi-sub">' + (d.totalFeedQty / 1000).toFixed(0) + ' T feed</div>' +
            '</div>' +
            '<div class="aq-ca-kpi">' +
              '<div class="aq-ca-kpi-label">Avg Price/kg</div>' +
              '<div class="aq-ca-kpi-value">₹' + d.avgPricePerKg.toFixed(2) + '</div>' +
              '<div class="aq-ca-kpi-sub">feed purchase rate</div>' +
            '</div>' +
            '<div class="aq-ca-kpi">' +
              '<div class="aq-ca-kpi-label">Cost/kg Shrimp</div>' +
              '<div class="aq-ca-kpi-value">' + (d.costPerKgShrimp > 0 ? '₹' + Math.round(d.costPerKgShrimp).toLocaleString('en-IN') : '—') + '</div>' +
              '<div class="aq-ca-kpi-sub">' + d.totalHarvestKg + ' kg harvested</div>' +
            '</div>' +
            '<div class="aq-ca-kpi ' + (d.roi >= 0 ? 'aq-ca-positive' : 'aq-ca-negative') + '">' +
              '<div class="aq-ca-kpi-label">ROI</div>' +
              '<div class="aq-ca-kpi-value">' + d.roi.toFixed(1) + '%</div>' +
              '<div class="aq-ca-kpi-sub">' + (d.netProfit >= 0 ? 'Profit' : 'Loss') + ': ' + fmt(d.netProfit) + '</div>' +
            '</div>' +
          '</div>' +
          '<div class="aq-ca-section">' +
            '<div class="aq-ca-section-title">Monthly Feed Cost Trend</div>' +
            '<div class="aq-ca-trend-chart">' + trendBars + '</div>' +
            '<div class="aq-ca-trend-axis">' + trendLabels + '</div>' +
          '</div>' +
          '<div class="aq-ca-section">' +
            '<div class="aq-ca-section-title">Cost Breakdown by Category</div>' +
            '<div class="aq-ca-cat-list">' + catRows + '</div>' +
          '</div>' +
          '<div class="aq-ca-footer">' +
            '<div class="aq-ca-footer-row">' +
              '<span>Profit/kg Shrimp:</span>' +
              '<span class="' + (d.profitPerKg >= 0 ? 'aq-ca-positive' : 'aq-ca-negative') + '">' +
                (d.profitPerKg >= 0 ? '+' : '') + '₹' + Math.round(d.profitPerKg).toLocaleString('en-IN') +
              '</span>' +
            '</div>' +
            '<div class="aq-ca-footer-row">' +
              '<span>Total Investment:</span>' +
              '<span>' + fmt(d.totalAllCosts) + '</span>' +
            '</div>' +
            '<div class="aq-ca-footer-row">' +
              '<span>Feed Consumed:</span>' +
              '<span>' + (d.totalFeedConsumed / 1000).toFixed(0) + ' kg</span>' +
            '</div>' +
          '</div>' +
        '</div>';
      }

      // Hook switchPage
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqCostAnalyticsHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageFinance') {
            setTimeout(inject, 500);
            setTimeout(inject, 1200);
          }
          return r;
        };
        window.switchPage._aqCostAnalyticsHooked = true;
      }

      // Also re-inject on tab clicks
      document.body.addEventListener('click', function (e) {
        if (e.target.closest('#pageFinance .tab-btn, #pageFinance [class*=tab-btn]')) {
          setTimeout(inject, 300);
        }
      });

      // Periodic re-inject via unified checker
      registerPeriodicCheck(function () {
        var finPage = document.getElementById('pageFinance');
        if (!finPage || !finPage.classList.contains('active')) return;
        var panel = finPage.querySelector('.tab-panel:not(.hidden)');
        if (panel && !panel.querySelector('.aq-cost-analytics')) inject();
      }, 'costAnalytics');
    }, 'initCostAnalytics');
  }

  /* ═══════════════════════════════════════════════════════════════
     Q. GROWTH RATE ALERTS — Warn when growth rate drops below threshold
     Checks all active batches' latest sampling data. If dailyGrowth
     is below 0.03g/day (threshold), shows an alert card on the dashboard.
     Also adds a notification check.
     ═══════════════════════════════════════════════════════════════ */
  function initGrowthAlerts() {
    safe(function () {
      // Use configurable threshold from getAlertThresholds() (falls back to 0.03)
      function getGrowthThreshold() {
        try { return getAlertThresholds().growthRate || 0.03; }
        catch (_) { return 0.03; }
      }

      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard || !dashboard.classList.contains('active')) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;

        // Only show on farm overview
        var contextSel = document.getElementById('dashboardContextSelect');
        if (!contextSel || contextSel.value !== 'farm') {
          var existing = scroll.querySelector('.aq-growth-alert-card');
          if (existing) existing.remove();
          return;
        }

        var alerts = checkGrowthAlerts();
        var old = scroll.querySelector('.aq-growth-alert-card');
        if (old) old.remove();

        if (alerts.length === 0) return;

        var card = document.createElement('div');
        card.className = 'aq-growth-alert-card';
        var alertItems = alerts.map(function (a) {
          return '<div class="aq-growth-alert-item">' +
            '<span class="aq-growth-alert-icon">⚠️</span>' +
            '<div class="aq-growth-alert-info">' +
              '<div class="aq-growth-alert-title">' + escapeHtml(a.pondName) + ' — Batch #' + a.batchNum + '</div>' +
              '<div class="aq-growth-alert-sub">Growth rate: ' + a.dailyGrowth.toFixed(3) + 'g/day (DOC ' + a.doc + ') · below threshold of ' + getGrowthThreshold() + 'g/day</div>' +
            '</div>' +
            '<span class="aq-growth-alert-badge">Slow Growth</span>' +
          '</div>';
        }).join('');

        card.innerHTML =
          '<div class="aq-growth-alert-inner">' +
            '<div class="aq-growth-alert-header">' +
              '<span class="aq-growth-alert-header-icon">📉</span>' +
              '<div>' +
                '<div class="aq-growth-alert-header-title">Growth Rate Alerts · वृद्धि चेतावनी</div>' +
                '<div class="aq-growth-alert-header-sub">' + alerts.length + ' batch' + (alerts.length > 1 ? 'es' : '') + ' need attention</div>' +
              '</div>' +
            '</div>' +
            '<div class="aq-growth-alert-list">' + alertItems + '</div>' +
            '<div class="aq-growth-alert-footer">Tip: Check water quality, feed quality, and stocking density. Consider adjusting feed size or frequency.</div>' +
          '</div>';

        // Insert after tasks card
        var tasksCard = scroll.querySelector('.aq-tasks-card');
        if (tasksCard && tasksCard.parentNode) {
          tasksCard.parentNode.appendChild(card);
        } else {
          scroll.appendChild(card);
        }
      }

      function checkGrowthAlerts() {
        var alerts = [];
        safe(function () {
          var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
          var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
          var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]');
          var pondMap = {};
          (ponds || []).forEach(function (p) { pondMap[p.id] = p.name; });

          var activeBatches = (batches || []).filter(function (b) { return b && !b.completedAt; });
          activeBatches.forEach(function (b) {
            var batchSampling = (sampling || []).filter(function (s) {
              return s && s.batchId === b.id;
            }).sort(function (a, b2) { return new Date(a.date) - new Date(b2.date); });

            if (batchSampling.length === 0) return;
            var last = batchSampling[batchSampling.length - 1];
            if (last.dailyGrowth !== null && last.dailyGrowth !== undefined && last.dailyGrowth < getGrowthThreshold()) {
              var start = new Date(b.stockingDate || b.createdAt);
              var doc = Math.floor((new Date() - start) / (1000 * 60 * 60 * 24));
              alerts.push({
                pondName: pondMap[b.pondId] || b.pond || 'Pond',
                batchNum: b.batchNumber,
                dailyGrowth: last.dailyGrowth,
                doc: doc
              });
            }
          });
        });
        return alerts;
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqGrowthAlertHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(inject, 500);
            setTimeout(inject, 1200);
          }
          return r;
        };
        window.switchPage._aqGrowthAlertHooked = true;
      }

      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'dashboardContextSelect') setTimeout(inject, 500);
      });

      registerPeriodicCheck(function () {
        var d = document.getElementById('pageDashboard');
        if (!d || !d.classList.contains('active')) return;
        var c = document.getElementById('dashboardContextSelect');
        if (!c || c.value !== 'farm') return;
        inject();
      }, 'growthAlerts');
    }, 'initGrowthAlerts');
  }

  /* ═══════════════════════════════════════════════════════════════
     R. POND COMPARISON VIEW — Compare all ponds side-by-side
     Adds a "Compare Ponds" button on the Manage page. Opens a modal
     showing all ponds with: health score, active batches, feed total,
     avg DOC, total shrimp, estimated biomass.
     ═══════════════════════════════════════════════════════════════ */
  function initPondComparison() {
    safe(function () {
      function injectButton() {
        var managePage = document.getElementById('pageManage');
        if (!managePage || !managePage.classList.contains('active')) return;
        var scroll = managePage.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-pond-compare-btn-wrap')) return;

        var wrap = document.createElement('div');
        wrap.className = 'aq-pond-compare-btn-wrap aq-compare-btn-wrap';
        wrap.innerHTML = '<button class="aq-compare-btn" id="aqPondCompareBtn" style="background: linear-gradient(135deg, rgba(16,185,129,0.12) 0%, rgba(0,229,245,0.08) 100%); border-color: rgba(16,185,129,0.2);">' +
          '<span class="aq-compare-btn-icon">🛢</span>' +
          '<span>Compare Ponds · तालाब तुलना</span>' +
        '</button>';
        var firstChild = scroll.firstChild;
        if (firstChild) {
          scroll.insertBefore(wrap, firstChild);
        } else {
          scroll.appendChild(wrap);
        }
      }

      function showPondComparisonModal() {
        var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]');
        var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
        var records = JSON.parse(localStorage.getItem('al_records') || '[]');
        var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');

        if (ponds.length === 0) {
          if (typeof window.showToast === 'function') {
            window.showToast('⚠️', 'No Ponds', 'Add ponds first to compare.', 'warn', 2500);
          }
          return;
        }

        var today = new Date();
        var rows = ponds.map(function (p) {
          var pondBatches = (batches || []).filter(function (b) { return b && b.pondId === p.id; });
          var activeBatches = pondBatches.filter(function (b) { return !b.completedAt; });
          var completedBatches = pondBatches.filter(function (b) { return b.completedAt; });

          // Feed total for this pond
          var pondRecords = (records || []).filter(function (r) { return r && r.pondId === p.id; });
          var feedTotal = pondRecords.reduce(function (s, r) { return s + (parseFloat(r.totalQty || r.total || 0)); }, 0);

          // Avg DOC for active batches
          var totalDoc = 0;
          activeBatches.forEach(function (b) {
            if (b.stockingDate) {
              totalDoc += Math.floor((today - new Date(b.stockingDate)) / (1000 * 60 * 60 * 24));
            }
          });
          var avgDoc = activeBatches.length > 0 ? Math.round(totalDoc / activeBatches.length) : 0;

          // Total shrimp (active)
          var totalShrimp = activeBatches.reduce(function (s, b) { return s + (b.shrimpCount || 0); }, 0);

          // Latest ABW from sampling
          var pondSampling = (sampling || []).filter(function (s) {
            if (!s || !s.batchId) return false;
            return activeBatches.some(function (b) { return b.id === s.batchId; });
          });
          var lastSample = pondSampling.length > 0 ? pondSampling[pondSampling.length - 1] : null;
          var abw = lastSample ? lastSample.abw : 0;

          // Estimated biomass (shrimp × abw in kg)
          var estBiomass = Math.round(totalShrimp * abw / 1000);

          // Health score
          var health = calcPondHealthScore(p.id);
          var healthInfo = healthScoreColor(health.score);

          // Total harvest from completed batches
          var totalHarvest = completedBatches.reduce(function (s, b) { return s + (b.harvestWeightKg || 0); }, 0);

          return {
            pond: p.name,
            site: p.site || '',
            size: p.sizeSqFt || 0,
            activeBatches: activeBatches.length,
            completedBatches: completedBatches.length,
            feedTotal: feedTotal,
            avgDoc: avgDoc,
            totalShrimp: totalShrimp,
            abw: abw,
            estBiomass: estBiomass,
            totalHarvest: totalHarvest,
            health: health.score,
            healthInfo: healthInfo
          };
        });

        var overlay = document.createElement('div');
        overlay.className = 'aq-compare-overlay';
        overlay.innerHTML =
          '<div class="aq-compare-modal">' +
            '<div class="aq-compare-modal-header">' +
              '<span class="aq-compare-modal-icon">🛢</span>' +
              '<div><div class="aq-compare-modal-title">Pond Comparison</div>' +
              '<div class="aq-compare-modal-sub">' + rows.length + ' ponds · side-by-side</div></div>' +
              '<button class="aq-compare-modal-close">✕</button>' +
            '</div>' +
            '<div class="aq-compare-modal-body">' +
              renderPondTable(rows) +
            '</div>' +
          '</div>';

        function renderPondTable(rows) {
          var bestHealth = Math.max.apply(null, rows.map(function (r) { return r.health; }));
          var bestBiomass = Math.max.apply(null, rows.map(function (r) { return r.estBiomass; }));
          var bestHarvest = Math.max.apply(null, rows.map(function (r) { return r.totalHarvest; }));

          function fmtNum(v) {
            if (v >= 1000000) return (v / 1000000).toFixed(1) + 'M';
            if (v >= 1000) return (v / 1000).toFixed(1) + 'K';
            return String(v);
          }

          function metricRow(label, values, best, fmt) {
            return '<div class="aq-compare-row">' +
              '<div class="aq-compare-cell aq-compare-cell-label">' + label + '</div>' +
              values.map(function (v) {
                var isBest = v === best && v > 0;
                return '<div class="aq-compare-cell' + (isBest ? ' aq-compare-best' : '') + '">' + fmt(v) + (isBest ? ' <span class="aq-compare-star">★</span>' : '') + '</div>';
              }).join('') +
            '</div>';
          }

          var header = '<div class="aq-compare-row aq-compare-header">' +
            '<div class="aq-compare-cell aq-compare-cell-label">Pond</div>' +
            rows.map(function (r) {
              return '<div class="aq-compare-cell"><div class="aq-compare-cell-pond">' + escapeHtml(r.pond) + '</div><div class="aq-compare-cell-batch">' + (r.size > 0 ? (r.size / 1000).toFixed(0) + 'K sqft' : '') + '</div></div>';
            }).join('') +
          '</div>';

          var healthRow = '<div class="aq-compare-row">' +
            '<div class="aq-compare-cell aq-compare-cell-label">Health Score</div>' +
            rows.map(function (r) {
              var isBest = r.health === bestHealth;
              return '<div class="aq-compare-cell' + (isBest ? ' aq-compare-best' : '') + '">' +
                '<div class="aq-compare-health" style="color:' + r.healthInfo.color + ';">' +
                  '<div class="aq-compare-health-ring" style="background: conic-gradient(' + r.healthInfo.color + ' ' + (r.health * 3.6) + 'deg, rgba(255,255,255,0.08) 0deg);">' +
                    '<span>' + r.health + '</span>' +
                  '</div>' +
                '</div>' +
              '</div>';
            }).join('') +
          '</div>';

          return '<div class="aq-compare-table">' +
            header +
            metricRow('Active Batches', rows.map(function (r) { return r.activeBatches; }), 0, function (v) { return v; }) +
            metricRow('Avg DOC', rows.map(function (r) { return r.avgDoc; }), 0, function (v) { return v + 'd'; }) +
            metricRow('Total Shrimp', rows.map(function (r) { return r.totalShrimp; }), 0, fmtNum) +
            metricRow('Current ABW', rows.map(function (r) { return r.abw; }), 0, function (v) { return v.toFixed(2) + 'g'; }) +
            metricRow('Est. Biomass', rows.map(function (r) { return r.estBiomass; }), bestBiomass, function (v) { return v + ' kg'; }) +
            metricRow('Feed Total', rows.map(function (r) { return r.feedTotal; }), 0, function (v) { return v > 1000 ? (v / 1000).toFixed(0) + ' kg' : v + ' g'; }) +
            metricRow('Total Harvest', rows.map(function (r) { return r.totalHarvest; }), bestHarvest, function (v) { return v + ' kg'; }) +
            metricRow('Completed', rows.map(function (r) { return r.completedBatches; }), 0, function (v) { return v; }) +
            healthRow +
          '</div>';
        }

        function escapeHtml(s) {
          return String(s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
          });
        }

        document.body.appendChild(overlay);
        requestAnimationFrame(function () { overlay.classList.add('aq-compare-open'); });

        function close() {
          overlay.classList.remove('aq-compare-open');
          setTimeout(function () { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, 250);
        }
        overlay.querySelector('.aq-compare-modal-close').addEventListener('click', close);
        overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
        var escHandler = function (e) { if (e.key === 'Escape') { close(); document.removeEventListener('keydown', escHandler); } };
        document.addEventListener('keydown', escHandler);
      }

      document.body.addEventListener('click', function (e) {
        if (e.target.closest('#aqPondCompareBtn')) {
          showPondComparisonModal();
        }
      });

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqPondCompareHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageManage') setTimeout(injectButton, 300);
          return r;
        };
        window.switchPage._aqPondCompareHooked = true;
      }
    }, 'initPondComparison');
  }

  /* ═══════════════════════════════════════════════════════════════
     S. WATER QUALITY TRACKING — pH, DO, salinity, ammonia, temperature
     Adds a "Water Quality" section on the Manage page with:
       - Form to log readings per pond
       - Recent readings list with color-coded status
       - Alerts when values are out of safe range
     Data stored in al_water_quality localStorage key.
     ═══════════════════════════════════════════════════════════════ */
  var WQ_KEY = 'al_water_quality';
  var WQ_RANGES = {
    ph:       { min: 7.5, max: 8.5, label: 'pH', unit: '', icon: '🧪', criticalMin: 6.5, criticalMax: 9.5 },
    do:       { min: 4.0, max: 8.0, label: 'Dissolved O₂', unit: 'mg/L', icon: '💨', criticalMin: 2.0, criticalMax: 10.0 },
    salinity: { min: 15, max: 35, label: 'Salinity', unit: 'ppt', icon: '🧂', criticalMin: 5, criticalMax: 45 },
    ammonia:  { min: 0, max: 0.5, label: 'Ammonia', unit: 'mg/L', icon: '⚠️', criticalMin: 0, criticalMax: 2.0 },
    temp:     { min: 26, max: 32, label: 'Temperature', unit: '°C', icon: '🌡', criticalMin: 20, criticalMax: 38 }
  };

  function getWaterQualityReadings(pondId) {
    var all = [];
    try { all = JSON.parse(localStorage.getItem(WQ_KEY) || '[]'); } catch (_) {}
    if (!pondId) return all;
    return all.filter(function (r) { return r && r.pondId === pondId; });
  }

  function saveWaterQualityReading(reading) {
    try {
      var all = JSON.parse(localStorage.getItem(WQ_KEY) || '[]');
      reading.id = 'wq_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6);
      reading.createdAt = new Date().toISOString();
      all.push(reading);
      localStorage.setItem(WQ_KEY, JSON.stringify(all));
      return true;
    } catch (_) { return false; }
  }

  function getWQStatus(param, value) {
    var range = WQ_RANGES[param];
    if (!range) return 'normal';
    var v = parseFloat(value);
    if (isNaN(v)) return 'normal';
    // Use user-configured thresholds if available, fall back to defaults
    var min = range.min, max = range.max;
    try {
      var thresholds = getAlertThresholds();
      if (thresholds.wq && thresholds.wq[param]) {
        min = thresholds.wq[param].min;
        max = thresholds.wq[param].max;
      }
    } catch (_) {}
    // Critical range is still based on the default criticalMin/criticalMax
    if (v < range.criticalMin || v > range.criticalMax) return 'critical';
    if (v < min || v > max) return 'warning';
    return 'normal';
  }

  function initWaterQualityTracking() {
    safe(function () {
      function inject() {
        var managePage = document.getElementById('pageManage');
        if (!managePage || !managePage.classList.contains('active')) return;
        var scroll = managePage.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-wq-section')) return; // already injected

        var ponds = [];
        try { ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]'); } catch (_) {}
        if (ponds.length === 0) return;

        var section = document.createElement('div');
        section.className = 'aq-wq-section';
        section.innerHTML = buildSectionHTML(ponds);
        // Insert after the compare buttons, before the pond list
        var heroSm = scroll.querySelector('.page-hero-sm');
        if (heroSm && heroSm.nextSibling) {
          scroll.insertBefore(section, heroSm.nextSibling);
        } else {
          scroll.appendChild(section);
        }

        bindSectionEvents();
        refreshReadings();
      }

      function buildSectionHTML(ponds) {
        var pondOptions = ponds.map(function (p) {
          return '<option value="' + p.id + '">' + escapeHtml(p.name) + '</option>';
        }).join('');

        return '<div class="aq-wq-inner">' +
          '<div class="aq-wq-header">' +
            '<span class="aq-wq-icon">💧</span>' +
            '<div>' +
              '<div class="aq-wq-title">Water Quality · जल गुणवत्ता</div>' +
              '<div class="aq-wq-sub">Track pH, oxygen, salinity, ammonia, temperature</div>' +
            '</div>' +
            '<button class="aq-wq-toggle-btn" id="aqWqToggleBtn">＋ Add Reading</button>' +
          '</div>' +
          '<div class="aq-wq-form hidden" id="aqWqForm">' +
            '<div class="aq-wq-form-row">' +
              '<select class="fi aq-wq-select" id="aqWqPond">' + pondOptions + '</select>' +
              '<input type="date" class="fi aq-wq-date" id="aqWqDate" value="' + new Date().toISOString().slice(0, 10) + '" />' +
            '</div>' +
            '<div class="aq-wq-inputs">' +
              buildWQInput('ph', 'pH') +
              buildWQInput('do', 'DO (mg/L)') +
              buildWQInput('salinity', 'Salinity (ppt)') +
              buildWQInput('ammonia', 'Ammonia (mg/L)') +
              buildWQInput('temp', 'Temp (°C)') +
            '</div>' +
            '<div class="aq-wq-form-actions">' +
              '<button class="pill-btn grey-btn" id="aqWqCancel">Cancel</button>' +
              '<button class="pill-btn green-btn" id="aqWqSave">✓ Save Reading</button>' +
            '</div>' +
          '</div>' +
          '<div class="aq-wq-alerts" id="aqWqAlerts"></div>' +
          '<div class="aq-wq-readings" id="aqWqReadings"></div>' +
        '</div>';
      }

      function buildWQInput(param, label) {
        var range = WQ_RANGES[param];
        return '<div class="aq-wq-input-group">' +
          '<label class="aq-wq-input-label">' + range.icon + ' ' + label + '</label>' +
          '<input type="number" class="fi aq-wq-input" id="aqWq_' + param + '" step="0.01" placeholder="' + range.min + '-' + range.max + '" />' +
          '<span class="aq-wq-input-range">Safe: ' + range.min + '-' + range.max + range.unit + '</span>' +
        '</div>';
      }

      function bindSectionEvents() {
        // Toggle form
        document.body.addEventListener('click', function (e) {
          if (e.target.closest('#aqWqToggleBtn')) {
            var form = document.getElementById('aqWqForm');
            if (form) form.classList.toggle('hidden');
          }
          if (e.target.closest('#aqWqCancel')) {
            var form2 = document.getElementById('aqWqForm');
            if (form2) form2.classList.add('hidden');
          }
          if (e.target.closest('#aqWqSave')) {
            saveReading();
          }
        });
      }

      function saveReading() {
        var pondId = document.getElementById('aqWqPond')?.value;
        var date = document.getElementById('aqWqDate')?.value;
        if (!pondId || !date) {
          if (typeof window.showToast === 'function') {
            window.showToast('⚠️', 'Missing Data', 'Please select pond and date.', 'warn', 2500);
          }
          return;
        }

        var reading = { pondId: pondId, date: date };
        var hasAny = false;
        Object.keys(WQ_RANGES).forEach(function (param) {
          var val = document.getElementById('aqWq_' + param)?.value;
          if (val !== '' && val !== undefined) {
            reading[param] = parseFloat(val);
            hasAny = true;
          }
        });

        if (!hasAny) {
          if (typeof window.showToast === 'function') {
            window.showToast('⚠️', 'No Values', 'Enter at least one measurement.', 'warn', 2500);
          }
          return;
        }

        if (saveWaterQualityReading(reading)) {
          if (typeof window.showToast === 'function') {
            window.showToast('💧', 'Reading Saved', 'Water quality data recorded.', 'success', 2500);
          }
          // Clear form
          Object.keys(WQ_RANGES).forEach(function (param) {
            var el = document.getElementById('aqWq_' + param);
            if (el) el.value = '';
          });
          document.getElementById('aqWqForm')?.classList.add('hidden');
          refreshReadings();
        }
      }

      function refreshReadings() {
        var readingsEl = document.getElementById('aqWqReadings');
        var alertsEl = document.getElementById('aqWqAlerts');
        if (!readingsEl) return;

        var ponds = [];
        try { ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]'); } catch (_) {}
        var pondMap = {};
        ponds.forEach(function (p) { pondMap[p.id] = p.name; });

        var allReadings = [];
        try { allReadings = JSON.parse(localStorage.getItem(WQ_KEY) || '[]'); } catch (_) {}
        allReadings.sort(function (a, b) { return new Date(b.date) - new Date(a.date); });

        if (allReadings.length === 0) {
          readingsEl.innerHTML = '<div class="aq-wq-empty">No readings yet. Click "Add Reading" to start tracking water quality.</div>';
          if (alertsEl) alertsEl.innerHTML = '';
          return;
        }

        // Check for alerts
        var alerts = [];
        allReadings.slice(0, 20).forEach(function (r) {
          Object.keys(WQ_RANGES).forEach(function (param) {
            if (r[param] !== undefined && r[param] !== null) {
              var status = getWQStatus(param, r[param]);
              if (status !== 'normal') {
                alerts.push({
                  pond: pondMap[r.pondId] || 'Pond',
                  param: param,
                  value: r[param],
                  status: status,
                  date: r.date,
                  range: WQ_RANGES[param]
                });
              }
            }
          });
        });

        if (alertsEl) {
          if (alerts.length === 0) {
            alertsEl.innerHTML = '';
          } else {
            alertsEl.innerHTML = '<div class="aq-wq-alert-banner">' +
              '<span class="aq-wq-alert-icon">' + (alerts.length > 2 ? '🚨' : '⚠️') + '</span>' +
              '<span>' + alerts.length + ' water quality alert' + (alerts.length > 1 ? 's' : '') + ' — ' + alerts.slice(0, 3).map(function (a) {
                return a.pond + ' ' + a.range.label + ': ' + a.value + a.range.unit;
              }).join(', ') + (alerts.length > 3 ? '…' : '') + '</span>' +
            '</div>';
          }
        }

        // Show recent readings (top 10)
        var recent = allReadings.slice(0, 10);
        readingsEl.innerHTML = recent.map(function (r) {
          var pondName = pondMap[r.pondId] || 'Pond';
          var params = Object.keys(WQ_RANGES).filter(function (p) { return r[p] !== undefined && r[p] !== null; });
          var paramChips = params.map(function (p) {
            var status = getWQStatus(p, r[p]);
            var range = WQ_RANGES[p];
            return '<span class="aq-wq-chip aq-wq-chip-' + status + '" title="' + range.label + ': safe ' + range.min + '-' + range.max + range.unit + '">' +
              range.icon + ' ' + r[p] + range.unit +
            '</span>';
          }).join('');
          return '<div class="aq-wq-reading">' +
            '<div class="aq-wq-reading-info">' +
              '<div class="aq-wq-reading-pond">' + escapeHtml(pondName) + '</div>' +
              '<div class="aq-wq-reading-date">' + r.date + '</div>' +
            '</div>' +
            '<div class="aq-wq-reading-chips">' + paramChips + '</div>' +
          '</div>';
        }).join('');
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqWQHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageManage') {
            setTimeout(inject, 400);
            setTimeout(inject, 1000);
          }
          return r;
        };
        window.switchPage._aqWQHooked = true;
      }
    }, 'initWaterQualityTracking');
  }

  /* ═══════════════════════════════════════════════════════════════
     T. BATCH TIMELINE VIEW — Visual lifecycle from stocking to harvest
     Shows on batch detail view (below harvest predictor). Displays
     a vertical timeline of key events: stocking, feed logs, sampling,
     growth entries, weather events, harvest.
     ═══════════════════════════════════════════════════════════════ */
  function initBatchTimeline() {
    safe(function () {
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard || !dashboard.classList.contains('active')) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;

        var contextSel = document.getElementById('dashboardContextSelect');
        if (!contextSel || contextSel.value === 'farm' || contextSel.value.indexOf('batch_') === -1) {
          var existing = scroll.querySelector('.aq-batch-timeline-card');
          if (existing) existing.remove();
          return;
        }

        if (scroll.querySelector('.aq-batch-timeline-card')) return;

        var batchId = contextSel.value.replace(/^batch_/, '');
        var events = buildBatchTimeline(batchId);
        if (events.length === 0) return;

        var batch = null;
        try {
          var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
          batch = batches.find(function (b) { return b && b.id === batchId; });
        } catch (_) {}
        if (!batch) return;

        var old = scroll.querySelector('.aq-batch-timeline-card');
        if (old) old.remove();

        var card = document.createElement('div');
        card.className = 'aq-batch-timeline-card';

        // Calculate progress
        var today = new Date();
        var start = new Date(batch.stockingDate || batch.createdAt);
        var doc = Math.floor((today - start) / (1000 * 60 * 60 * 24));
        var isCompleted = !!batch.completedAt;
        var endDate = isCompleted ? new Date(batch.completedAt) : today;
        var totalDays = isCompleted ? Math.floor((endDate - start) / (1000 * 60 * 60 * 24)) : Math.max(doc, 120);
        var progress = Math.min(100, Math.round((doc / totalDays) * 100));

        // Build timeline events HTML
        var eventsHTML = events.slice(0, 15).map(function (ev, i) {
          return '<div class="aq-bt-event" style="animation-delay:' + (i * 0.04) + 's">' +
            '<div class="aq-bt-dot aq-bt-dot-' + ev.type + '">' + ev.icon + '</div>' +
            '<div class="aq-bt-content">' +
              '<div class="aq-bt-title">' + escapeHtml(ev.title) + '</div>' +
              '<div class="aq-bt-sub">' + escapeHtml(ev.sub) + '</div>' +
              '<div class="aq-bt-date">' + ev.dateStr + ' · DOC ' + ev.doc + '</div>' +
            '</div>' +
          '</div>';
        }).join('');

        card.innerHTML =
          '<div class="aq-bt-inner">' +
            '<div class="aq-bt-header">' +
              '<span class="aq-bt-icon">📅</span>' +
              '<span>Batch Timeline · बैच समयरेखा</span>' +
            '</div>' +
            '<div class="aq-bt-progress">' +
              '<div class="aq-bt-progress-info">' +
                '<span>Batch #' + (batch.batchNumber || '?') + '</span>' +
                '<span>' + (isCompleted ? 'Completed' : 'DOC ' + doc + ' · ' + progress + '%') + '</span>' +
              '</div>' +
              '<div class="aq-bt-progress-track">' +
                '<div class="aq-bt-progress-fill" style="width:' + progress + '%;"></div>' +
              '</div>' +
            '</div>' +
            '<div class="aq-bt-list">' + eventsHTML + '</div>' +
          '</div>';

        // Insert after the batch summary card (which is OUTSIDE farmOverviewContent)
        var batchSummary = document.getElementById('batchSummaryCard') || scroll.querySelector('.batch-summary-card');
        if (batchSummary && batchSummary.parentNode) {
          try { batchSummary.parentNode.appendChild(card); } catch (_) { scroll.appendChild(card); }
        } else {
          scroll.appendChild(card);
        }
      }

      function buildBatchTimeline(batchId) {
        var events = [];
        safe(function () {
          var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
          var records = JSON.parse(localStorage.getItem('al_records') || '[]');
          var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
          var growth = JSON.parse(localStorage.getItem('al_growth') || '[]');
          var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]');
          var pondMap = {};
          (ponds || []).forEach(function (p) { pondMap[p.id] = p.name; });

          var batch = (batches || []).find(function (b) { return b && b.id === batchId; });
          if (!batch) return;

          var start = new Date(batch.stockingDate || batch.createdAt);

          // 1. Stocking event
          events.push({
            type: 'stocking',
            icon: '🐟',
            title: 'Batch Stocked',
            sub: (batch.shrimpCount || 0).toLocaleString() + ' shrimp in ' + (pondMap[batch.pondId] || batch.pond || 'Pond'),
            date: start,
            dateStr: start.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }),
            doc: 0
          });

          // 2. Sampling events
          var batchSampling = (sampling || []).filter(function (s) { return s && s.batchId === batchId; });
          batchSampling.forEach(function (s) {
            var sd = new Date(s.date);
            var doc = Math.floor((sd - start) / (1000 * 60 * 60 * 24));
            events.push({
              type: 'sampling',
              icon: '🔬',
              title: 'Sampling Recorded',
              sub: 'ABW: ' + (s.abw || 0).toFixed(2) + 'g' + (s.dailyGrowth ? ' · Growth: ' + s.dailyGrowth.toFixed(3) + 'g/day' : ''),
              date: sd,
              dateStr: sd.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }),
              doc: doc
            });
          });

          // 3. Growth entries
          var batchGrowth = (growth || []).filter(function (g) { return g && g.batchId === batchId; });
          batchGrowth.slice(-5).forEach(function (g) {
            var gd = new Date(g.date || g.createdAt);
            var doc = Math.floor((gd - start) / (1000 * 60 * 60 * 24));
            events.push({
              type: 'growth',
              icon: '📈',
              title: 'Growth Entry',
              sub: 'Weight: ' + (g.weight || g.avgWeight || 0).toFixed(2) + 'g',
              date: gd,
              dateStr: gd.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }),
              doc: doc
            });
          });

          // 4. Feed milestones (first feed, significant feed days)
          var batchRecords = (records || []).filter(function (r) { return r && r.pondId === batch.pondId; });
          if (batchRecords.length > 0) {
            var firstFeed = batchRecords[0];
            var fd = new Date(firstFeed.date);
            var fdoc = Math.floor((fd - start) / (1000 * 60 * 60 * 24));
            events.push({
              type: 'feed',
              icon: '🍽',
              title: 'First Feed Logged',
              sub: 'Started feeding program',
              date: fd,
              dateStr: fd.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }),
              doc: fdoc
            });

            // Total feed
            var totalFeed = batchRecords.reduce(function (s, r) { return s + (parseFloat(r.totalQty || r.total || 0)); }, 0);
            if (totalFeed > 0) {
              events.push({
                type: 'feed',
                icon: '📊',
                title: 'Feed Summary',
                sub: batchRecords.length + ' sessions · ' + (totalFeed / 1000).toFixed(0) + ' kg total',
                date: new Date(),
                dateStr: 'Ongoing',
                doc: Math.floor((new Date() - start) / (1000 * 60 * 60 * 24))
              });
            }
          }

          // 5. Harvest (if completed)
          if (batch.completedAt) {
            var hd = new Date(batch.completedAt);
            var hdoc = Math.floor((hd - start) / (1000 * 60 * 60 * 24));
            events.push({
              type: 'harvest',
              icon: '🎯',
              title: 'Batch Harvested',
              sub: (batch.harvestWeightKg || 0) + ' kg · ' + (batch.survivalPercent || 0) + '% survival · DOC ' + hdoc,
              date: hd,
              dateStr: hd.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }),
              doc: hdoc
            });
          }

          // Sort by date
          events.sort(function (a, b) { return b.date - a.date; });
        });
        return events;
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqBatchTimelineHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(inject, 700);
            setTimeout(inject, 1400);
          }
          return r;
        };
        window.switchPage._aqBatchTimelineHooked = true;
      }

      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'dashboardContextSelect') {
          setTimeout(inject, 700);
        }
      });

      // Periodic re-inject via unified checker
      registerPeriodicCheck(function () {
        var d = document.getElementById('pageDashboard');
        if (!d || !d.classList.contains('active')) return;
        var c = document.getElementById('dashboardContextSelect');
        if (!c || c.value.indexOf('batch_') === -1) return;
        if (!d.querySelector('.aq-batch-timeline-card')) inject();
      }, 'batchTimeline');
    }, 'initBatchTimeline');
  }

  /* ═══════════════════════════════════════════════════════════════
     U. WATER QUALITY TRENDS CHART — pH/DO/temp trends over time
     Shows on the Manage page below the Water Quality section.
     Renders a mini line chart for each parameter showing the last
     14 days of readings, with safe-range shading.
     ═══════════════════════════════════════════════════════════════ */
  function initWQTrendsChart() {
    safe(function () {
      function inject() {
        var managePage = document.getElementById('pageManage');
        if (!managePage || !managePage.classList.contains('active')) return;
        var scroll = managePage.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-wq-trends-card')) return; // already injected

        // Only show if there are readings
        var allReadings = [];
        try { allReadings = JSON.parse(localStorage.getItem(WQ_KEY) || '[]'); } catch (_) {}
        if (allReadings.length < 2) return; // need at least 2 readings for a trend

        var ponds = [];
        try { ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]'); } catch (_) {}
        if (ponds.length === 0) return;

        var card = document.createElement('div');
        card.className = 'aq-wq-trends-card';
        card.innerHTML = buildTrendsHTML(ponds, allReadings);

        // Insert after the water quality section
        var wqSection = scroll.querySelector('.aq-wq-section');
        if (wqSection && wqSection.nextSibling) {
          scroll.insertBefore(card, wqSection.nextSibling);
        } else {
          scroll.appendChild(card);
        }
      }

      function buildTrendsHTML(ponds, allReadings) {
        var pondOptions = ponds.map(function (p, i) {
          return '<option value="' + p.id + '"' + (i === 0 ? ' selected' : '') + '>' + escapeHtml(p.name) + '</option>';
        }).join('');

        var chartsHTML = Object.keys(WQ_RANGES).map(function (param) {
          return '<div class="aq-wq-trend-item" id="aq-wq-trend-' + param + '">' +
            '<div class="aq-wq-trend-label">' + WQ_RANGES[param].icon + ' ' + WQ_RANGES[param].label + '</div>' +
            '<div class="aq-wq-trend-chart" id="aq-wq-trend-chart-' + param + '"></div>' +
            '<div class="aq-wq-trend-range">Safe: ' + WQ_RANGES[param].min + '-' + WQ_RANGES[param].max + WQ_RANGES[param].unit + '</div>' +
          '</div>';
        }).join('');

        return '<div class="aq-wq-trends-inner">' +
          '<div class="aq-wq-trends-header">' +
            '<span class="aq-wq-trends-icon">📈</span>' +
            '<div>' +
              '<div class="aq-wq-trends-title">Water Quality Trends · प्रवृत्ति</div>' +
              '<div class="aq-wq-trends-sub">Last 14 days per pond</div>' +
            '</div>' +
            '<select class="fi aq-wq-trends-select" id="aqWqTrendsPond">' + pondOptions + '</select>' +
          '</div>' +
          '<div class="aq-wq-trends-grid">' + chartsHTML + '</div>' +
        '</div>';
      }

      function renderCharts(pondId) {
        var allReadings = [];
        try { allReadings = JSON.parse(localStorage.getItem(WQ_KEY) || '[]'); } catch (_) {}

        // Filter readings for this pond, last 14 days
        var now = new Date();
        var fourteenAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
        var pondReadings = allReadings.filter(function (r) {
          if (!r || r.pondId !== pondId) return false;
          var d = new Date(r.date);
          return d >= fourteenAgo && d <= now;
        }).sort(function (a, b) { return new Date(a.date) - new Date(b.date); });

        Object.keys(WQ_RANGES).forEach(function (param) {
          var chartEl = document.getElementById('aq-wq-trend-chart-' + param);
          if (!chartEl) return;

          var dataPoints = pondReadings.filter(function (r) {
            return r[param] !== undefined && r[param] !== null;
          }).map(function (r) {
            return { date: new Date(r.date), value: parseFloat(r[param]) };
          });

          if (dataPoints.length === 0) {
            chartEl.innerHTML = '<div class="aq-wq-trend-empty">No data</div>';
            return;
          }

          chartEl.innerHTML = renderMiniChart(dataPoints, WQ_RANGES[param]);
        });
      }

      function renderMiniChart(data, range) {
        var width = 100; // percentage-based
        var height = 50; // px
        var values = data.map(function (d) { return d.value; });
        var min = Math.min.apply(null, values.concat([range.criticalMin]));
        var max = Math.max.apply(null, values.concat([range.criticalMax]));
        if (min === max) { min -= 1; max += 1; }
        var range_val = max - min;

        // Build SVG path
        var points = data.map(function (d, i) {
          var x = (i / Math.max(data.length - 1, 1)) * width;
          var y = height - ((d.value - min) / range_val) * height;
          return { x: x, y: y, val: d.value };
        });

        var pathD = points.map(function (p, i) {
          return (i === 0 ? 'M' : 'L') + p.x.toFixed(1) + ',' + p.y.toFixed(1);
        }).join(' ');

        // Safe range band
        var safeY1 = height - ((range.max - min) / range_val) * height;
        var safeY2 = height - ((range.min - min) / range_val) * height;

        // Build dots
        var dots = points.map(function (p) {
          var status = getWQStatus(range === WQ_RANGES.ph ? 'ph' : range === WQ_RANGES.do ? 'do' : range === WQ_RANGES.salinity ? 'salinity' : range === WQ_RANGES.ammonia ? 'ammonia' : 'temp', p.val);
          var color = status === 'normal' ? '#10b981' : (status === 'warning' ? '#fbbf24' : '#f43f5e');
          return '<circle cx="' + p.x.toFixed(1) + '" cy="' + p.y.toFixed(1) + '" r="2" fill="' + color + '"/>';
        }).join('');

        return '<svg viewBox="0 0 ' + width + ' ' + height + '" preserveAspectRatio="none" style="width:100%;height:' + height + 'px;">' +
          '<rect x="0" y="' + safeY1.toFixed(1) + '" width="' + width + '" height="' + (safeY2 - safeY1).toFixed(1) + '" fill="rgba(16,185,129,0.08)"/>' +
          '<path d="' + pathD + '" fill="none" stroke="var(--teal)" stroke-width="1.5" stroke-linejoin="round"/>' +
          dots +
        '</svg>' +
        '<div class="aq-wq-trend-latest">Latest: <strong>' + data[data.length - 1].value.toFixed(2) + range.unit + '</strong> · ' + data.length + ' readings</div>';
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      // Hook switchPage
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqWQTrendsHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageManage') {
            setTimeout(function () {
              inject();
              var sel = document.getElementById('aqWqTrendsPond');
              if (sel) renderCharts(sel.value);
            }, 600);
          }
          return r;
        };
        window.switchPage._aqWQTrendsHooked = true;
      }

      // Re-render on pond selection change
      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'aqWqTrendsPond') {
          renderCharts(e.target.value);
        }
      });

      // Periodic re-inject via unified checker
      registerPeriodicCheck(function () {
        var mp = document.getElementById('pageManage');
        if (!mp || !mp.classList.contains('active')) return;
        if (!mp.querySelector('.aq-wq-trends-card')) {
          inject();
          var sel = document.getElementById('aqWqTrendsPond');
          if (sel) renderCharts(sel.value);
        }
      }, 'wqTrends');
    }, 'initWQTrendsChart');
  }

  /* ═══════════════════════════════════════════════════════════════
     V. FEED SCHEDULE TEMPLATES — Save/load common feed schedules
     Adds a "Templates" section on the Log Feed page. Users can save
     their common feed configurations (which sizes, quantities) per
     template name, then quickly apply them.
     Data stored in al_feed_templates localStorage key.
     ═══════════════════════════════════════════════════════════════ */
  var TEMPLATES_KEY = 'al_feed_templates';

  function getFeedTemplates() {
    try { return JSON.parse(localStorage.getItem(TEMPLATES_KEY) || '[]'); }
    catch (_) { return []; }
  }

  function saveFeedTemplate(template) {
    try {
      var templates = getFeedTemplates();
      template.id = 'tpl_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6);
      template.createdAt = new Date().toISOString();
      templates.push(template);
      localStorage.setItem(TEMPLATES_KEY, JSON.stringify(templates));
      return true;
    } catch (_) { return false; }
  }

  function deleteFeedTemplate(id) {
    try {
      var templates = getFeedTemplates().filter(function (t) { return t.id !== id; });
      localStorage.setItem(TEMPLATES_KEY, JSON.stringify(templates));
      return true;
    } catch (_) { return false; }
  }

  function initFeedScheduleTemplates() {
    safe(function () {
      function inject() {
        var logPage = document.getElementById('pageLog');
        if (!logPage || !logPage.classList.contains('active')) return;
        var scroll = logPage.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-templates-card')) return;

        var card = document.createElement('div');
        card.className = 'aq-templates-card';
        card.innerHTML = buildTemplatesHTML();
        // Insert at the top of the log feed page
        var firstChild = scroll.firstChild;
        if (firstChild) {
          scroll.insertBefore(card, firstChild);
        } else {
          scroll.appendChild(card);
        }
        refreshTemplatesList();
      }

      function buildTemplatesHTML() {
        return '<div class="aq-templates-inner">' +
          '<div class="aq-templates-header">' +
            '<span class="aq-templates-icon">📋</span>' +
            '<div>' +
              '<div class="aq-templates-title">Feed Templates · टेम्पलेट</div>' +
              '<div class="aq-templates-sub">Save and quickly apply common feed configs</div>' +
            '</div>' +
            '<button class="aq-templates-save-btn" id="aqTplSaveBtn">💾 Save Current</button>' +
          '</div>' +
          '<div class="aq-templates-list" id="aqTplList"></div>' +
        '</div>';
      }

      function refreshTemplatesList() {
        var listEl = document.getElementById('aqTplList');
        if (!listEl) return;
        var templates = getFeedTemplates();
        if (templates.length === 0) {
          listEl.innerHTML = '<div class="aq-templates-empty">No templates yet. Set up feed sizes and quantities, then click "Save Current" to create a template.</div>';
          return;
        }
        listEl.innerHTML = templates.map(function (t) {
          var sizes = Object.keys(t.qty || {}).map(function (k) {
            return '<span class="aq-tpl-chip">' + k + ': ' + t.qty[k] + 'g</span>';
          }).join('');
          return '<div class="aq-tpl-item" data-id="' + t.id + '">' +
            '<div class="aq-tpl-info">' +
              '<div class="aq-tpl-name">' + escapeHtml(t.name) + '</div>' +
              '<div class="aq-tpl-chips">' + sizes + '</div>' +
              '<div class="aq-tpl-date">Saved ' + new Date(t.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) + '</div>' +
            '</div>' +
            '<div class="aq-tpl-actions">' +
              '<button class="aq-tpl-apply" data-id="' + t.id + '">Apply</button>' +
              '<button class="aq-tpl-delete" data-id="' + t.id + '">🗑</button>' +
            '</div>' +
          '</div>';
        }).join('');
      }

      function saveCurrentAsTemplate() {
        // Read current form state
        var qty = {};
        var hasAny = false;
        ['fs1', 'fs2', 'fs3', 'fs4', 'fs5'].forEach(function (fs) {
          var cb = document.getElementById('cb_' + fs);
          var qtyEl = document.getElementById('qty_' + fs);
          if (cb && cb.checked && qtyEl && qtyEl.value && parseFloat(qtyEl.value) > 0) {
            qty[fs] = qtyEl.value;
            hasAny = true;
          }
        });
        var otherCb = document.getElementById('cb_other');
        var otherQty = document.getElementById('otherFeedQty');
        if (otherCb && otherCb.checked && otherQty && otherQty.value && parseFloat(otherQty.value) > 0) {
          qty.other = otherQty.value;
          hasAny = true;
        }

        if (!hasAny) {
          if (typeof window.showToast === 'function') {
            window.showToast('⚠️', 'No Feed Selected', 'Check sizes and enter quantities first.', 'warn', 2500);
          }
          return;
        }

        // Ask for name
        var name = 'Template ' + (getFeedTemplates().length + 1);
        if (typeof window.showConfirm === 'function') {
          // Use a simple prompt fallback
          var inputName = window.prompt ? null : name;
          // Since we can't use prompt in this context, use a default name
        }

        var template = { name: name, qty: qty };
        if (saveFeedTemplate(template)) {
          if (typeof window.showToast === 'function') {
            window.showToast('💾', 'Template Saved', name + ' saved with ' + Object.keys(qty).length + ' feed sizes.', 'success', 2500);
          }
          refreshTemplatesList();
        }
      }

      function applyTemplate(id) {
        var templates = getFeedTemplates();
        var tpl = templates.find(function (t) { return t.id === id; });
        if (!tpl) return;

        // Clear all checkboxes first
        ['fs1', 'fs2', 'fs3', 'fs4', 'fs5'].forEach(function (fs) {
          var cb = document.getElementById('cb_' + fs);
          if (cb) cb.checked = false;
          var qtyEl = document.getElementById('qty_' + fs);
          if (qtyEl) qtyEl.value = '';
        });
        var otherCb = document.getElementById('cb_other');
        if (otherCb) otherCb.checked = false;
        var otherQty = document.getElementById('otherFeedQty');
        if (otherQty) otherQty.value = '';

        // Apply template values
        Object.keys(tpl.qty).forEach(function (fs) {
          if (fs === 'other') {
            var ocb = document.getElementById('cb_other');
            var oq = document.getElementById('otherFeedQty');
            if (ocb) { ocb.checked = true; ocb.dispatchEvent(new Event('change', { bubbles: true })); }
            if (oq) { oq.value = tpl.qty[fs]; oq.dispatchEvent(new Event('input', { bubbles: true })); }
          } else {
            var cb = document.getElementById('cb_' + fs);
            var q = document.getElementById('qty_' + fs);
            if (cb) {
              cb.checked = true;
              cb.dispatchEvent(new Event('change', { bubbles: true }));
            }
            // Wait for qty field to appear, then set it
            setTimeout(function () {
              var q2 = document.getElementById('qty_' + fs);
              if (q2) { q2.value = tpl.qty[fs]; q2.dispatchEvent(new Event('input', { bubbles: true })); }
            }, 200);
          }
        });

        if (typeof window.showToast === 'function') {
          window.showToast('✅', 'Template Applied', tpl.name + ' loaded. Review and submit.', 'success', 2500);
        }
      }

      function deleteTemplate(id) {
        if (typeof window.showConfirm === 'function') {
          window.showConfirm(
            'Delete Template?',
            'This template will be permanently removed.',
            function () {
              deleteFeedTemplate(id);
              if (typeof window.showToast === 'function') {
                window.showToast('🗑', 'Template Deleted', 'Template removed.', 'info', 2000);
              }
              refreshTemplatesList();
            },
            { icon: '🗑', danger: true, confirmLabel: 'Delete', cancelLabel: 'Cancel' }
          );
        } else {
          deleteFeedTemplate(id);
          refreshTemplatesList();
        }
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      // Event delegation
      document.body.addEventListener('click', function (e) {
        if (e.target.closest('#aqTplSaveBtn')) {
          saveCurrentAsTemplate();
        }
        var applyBtn = e.target.closest('.aq-tpl-apply');
        if (applyBtn) {
          applyTemplate(applyBtn.getAttribute('data-id'));
        }
        var deleteBtn = e.target.closest('.aq-tpl-delete');
        if (deleteBtn) {
          deleteTemplate(deleteBtn.getAttribute('data-id'));
        }
      });

      // Hook switchPage
      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqTemplatesHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageLog') {
            setTimeout(inject, 400);
          }
          return r;
        };
        window.switchPage._aqTemplatesHooked = true;
      }
    }, 'initFeedScheduleTemplates');
  }

  /* ═══════════════════════════════════════════════════════════════
     W. CONFIGURABLE ALERT THRESHOLDS — User-customizable thresholds
     Adds a Settings section where users can adjust:
       - Growth rate alert threshold (g/day)
       - Water quality safe ranges (pH, DO, Salinity, Ammonia, Temp)
     Stored in al_alert_thresholds localStorage key.
     The growth alerts and WQ features use these custom thresholds
     if present, falling back to defaults.
     ═══════════════════════════════════════════════════════════════ */
  var THRESHOLDS_KEY = 'al_alert_thresholds';

  function getAlertThresholds() {
    try {
      var t = JSON.parse(localStorage.getItem(THRESHOLDS_KEY) || '{}');
      // Merge with defaults
      return {
        growthRate: t.growthRate !== undefined ? t.growthRate : 0.03,
        wq: {
          ph:       t.wq && t.wq.ph       ? t.wq.ph       : { min: 7.5, max: 8.5 },
          do:       t.wq && t.wq.do       ? t.wq.do       : { min: 4.0, max: 8.0 },
          salinity: t.wq && t.wq.salinity ? t.wq.salinity : { min: 15, max: 35 },
          ammonia:  t.wq && t.wq.ammonia  ? t.wq.ammonia  : { min: 0, max: 0.5 },
          temp:     t.wq && t.wq.temp     ? t.wq.temp     : { min: 26, max: 32 }
        }
      };
    } catch (_) {
      return {
        growthRate: 0.03,
        wq: {
          ph: { min: 7.5, max: 8.5 }, do: { min: 4.0, max: 8.0 },
          salinity: { min: 15, max: 35 }, ammonia: { min: 0, max: 0.5 },
          temp: { min: 26, max: 32 }
        }
      };
    }
  }

  function saveAlertThresholds(t) {
    try { localStorage.setItem(THRESHOLDS_KEY, JSON.stringify(t)); return true; }
    catch (_) { return false; }
  }

  function initConfigurableThresholds() {
    safe(function () {
      function inject() {
        var settingsPage = document.getElementById('pageSettings');
        if (!settingsPage || !settingsPage.classList.contains('active')) return;
        var scroll = settingsPage.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-thresholds-card')) return;

        var card = document.createElement('div');
        card.className = 'aq-thresholds-card';
        card.innerHTML = buildThresholdsHTML();
        // Insert before the version footer
        var footer = scroll.querySelector('.settings-version-footer');
        if (footer) {
          scroll.insertBefore(card, footer);
        } else {
          scroll.appendChild(card);
        }
      }

      function buildThresholdsHTML() {
        var t = getAlertThresholds();
        var wqItems = Object.keys(t.wq).map(function (param) {
          var range = WQ_RANGES[param];
          var pr = t.wq[param];
          return '<div class="aq-thr-row">' +
            '<div class="aq-thr-label">' + range.icon + ' ' + range.label + '</div>' +
            '<div class="aq-thr-inputs">' +
              '<input type="number" class="fi aq-thr-input" id="aqThr_' + param + '_min" value="' + pr.min + '" step="0.1" placeholder="Min"/>' +
              '<span class="aq-thr-sep">—</span>' +
              '<input type="number" class="fi aq-thr-input" id="aqThr_' + param + '_max" value="' + pr.max + '" step="0.1" placeholder="Max"/>' +
              '<span class="aq-thr-unit">' + range.unit + '</span>' +
            '</div>' +
          '</div>';
        }).join('');

        return '<div class="aq-thr-inner">' +
          '<div class="aq-thr-header">' +
            '<span class="aq-thr-icon">⚙️</span>' +
            '<div>' +
              '<div class="aq-thr-title">Alert Thresholds · चेतावनी सीमा</div>' +
              '<div class="aq-thr-sub">Customize when alerts trigger</div>' +
            '</div>' +
          '</div>' +
          '<div class="aq-thr-section">' +
            '<div class="aq-thr-section-title">Growth Rate Alert</div>' +
            '<div class="aq-thr-row">' +
              '<div class="aq-thr-label">📈 Min Growth Rate (g/day)</div>' +
              '<div class="aq-thr-inputs">' +
                '<input type="number" class="fi aq-thr-input" id="aqThr_growthRate" value="' + t.growthRate + '" step="0.01" placeholder="0.03"/>' +
                '<span class="aq-thr-unit">g/day</span>' +
              '</div>' +
            '</div>' +
            '<div class="aq-thr-hint">Batches with growth below this will trigger an alert. Default: 0.03 g/day</div>' +
          '</div>' +
          '<div class="aq-thr-section">' +
            '<div class="aq-thr-section-title">Water Quality Safe Ranges</div>' +
            wqItems +
          '</div>' +
          '<div class="aq-thr-actions">' +
            '<button class="pill-btn grey-btn" id="aqThrReset">Reset to Defaults</button>' +
            '<button class="pill-btn green-btn" id="aqThrSave">✓ Save Thresholds</button>' +
          '</div>' +
        '</div>';
      }

      // Event delegation for save and reset
      document.body.addEventListener('click', function (e) {
        if (e.target.closest('#aqThrSave')) {
          saveThresholds();
        }
        if (e.target.closest('#aqThrReset')) {
          resetThresholds();
        }
      });

      function saveThresholds() {
        var t = { wq: {} };
        t.growthRate = parseFloat(document.getElementById('aqThr_growthRate')?.value) || 0.03;
        Object.keys(WQ_RANGES).forEach(function (param) {
          var min = parseFloat(document.getElementById('aqThr_' + param + '_min')?.value);
          var max = parseFloat(document.getElementById('aqThr_' + param + '_max')?.value);
          t.wq[param] = {
            min: isNaN(min) ? WQ_RANGES[param].min : min,
            max: isNaN(max) ? WQ_RANGES[param].max : max
          };
        });
        if (saveAlertThresholds(t)) {
          if (typeof window.showToast === 'function') {
            window.showToast('✅', 'Thresholds Saved', 'Alert thresholds updated.', 'success', 2500);
          }
        }
      }

      function resetThresholds() {
        if (typeof window.showConfirm === 'function') {
          window.showConfirm(
            'Reset Thresholds?',
            'This will restore all thresholds to their default values.',
            function () {
              localStorage.removeItem(THRESHOLDS_KEY);
              if (typeof window.showToast === 'function') {
                window.showToast('🔄', 'Reset Done', 'Thresholds restored to defaults. Reload to see changes.', 'info', 2800);
              }
              // Rebuild the form
              var card = document.querySelector('.aq-thresholds-card');
              if (card) card.innerHTML = buildThresholdsHTML();
            },
            { icon: '🔄', danger: true, confirmLabel: 'Reset', cancelLabel: 'Cancel' }
          );
        }
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqThresholdsHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageSettings') setTimeout(inject, 400);
          return r;
        };
        window.switchPage._aqThresholdsHooked = true;
      }

      registerPeriodicCheck(function () {
        var sp = document.getElementById('pageSettings');
        if (!sp || !sp.classList.contains('active')) return;
        if (!sp.querySelector('.aq-thresholds-card')) inject();
      }, 'thresholds');
    }, 'initConfigurableThresholds');
  }

  /* ═══════════════════════════════════════════════════════════════
     X. FARM OVERVIEW DASHBOARD — All ponds' KPIs in one view
     Adds a "Farm Overview" card on the Dashboard farm view showing
     all ponds in a compact grid with key metrics: health score,
     active batches, feed total, estimated biomass.
     ═══════════════════════════════════════════════════════════════ */
  function initFarmOverview() {
    safe(function () {
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard || !dashboard.classList.contains('active')) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;

        var contextSel = document.getElementById('dashboardContextSelect');
        if (!contextSel || contextSel.value !== 'farm') {
          var existing = scroll.querySelector('.aq-farm-overview-card');
          if (existing) existing.remove();
          return;
        }

        if (scroll.querySelector('.aq-farm-overview-card')) return;

        var ponds = [];
        try { ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]'); } catch (_) {}
        if (ponds.length === 0) return;

        var old = scroll.querySelector('.aq-farm-overview-card');
        if (old) old.remove();

        var card = document.createElement('div');
        card.className = 'aq-farm-overview-card';
        card.innerHTML = buildFarmOverviewHTML(ponds);

        // Insert after the weather card or timeline
        var anchor = scroll.querySelector('.aq-weather-rec-card') || scroll.querySelector('.aq-timeline-card') || scroll.querySelector('.aq-insights-card');
        if (anchor && anchor.parentNode) {
          try { anchor.parentNode.appendChild(card); } catch (_) { scroll.appendChild(card); }
        } else {
          scroll.appendChild(card);
        }
      }

      function buildFarmOverviewHTML(ponds) {
        var batches = [];
        try { batches = JSON.parse(localStorage.getItem('al_batches') || '[]'); } catch (_) {}
        var records = [];
        try { records = JSON.parse(localStorage.getItem('al_records') || '[]'); } catch (_) {}
        var sampling = [];
        try { sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]'); } catch (_) {}

        var today = new Date();

        // Farm-level totals
        var totalActiveBatches = 0;
        var totalShrimp = 0;
        var totalFeed = 0;
        var totalBiomass = 0;

        var pondCards = ponds.map(function (p) {
          var pondBatches = batches.filter(function (b) { return b && b.pondId === p.id && !b.completedAt; });
          var pondRecords = records.filter(function (r) { return r && r.pondId === p.id; });
          var feedTotal = pondRecords.reduce(function (s, r) { return s + (parseFloat(r.totalQty || r.total || 0)); }, 0);

          var shrimp = pondBatches.reduce(function (s, b) { return s + (b.shrimpCount || 0); }, 0);
          var pondSampling = sampling.filter(function (s) {
            if (!s || !s.batchId) return false;
            return pondBatches.some(function (b) { return b.id === s.batchId; });
          });
          var lastSample = pondSampling.length > 0 ? pondSampling[pondSampling.length - 1] : null;
          var abw = lastSample ? lastSample.abw : 0;
          var biomass = Math.round(shrimp * abw / 1000);

          totalActiveBatches += pondBatches.length;
          totalShrimp += shrimp;
          totalFeed += feedTotal;
          totalBiomass += biomass;

          var health = calcPondHealthScore(p.id);
          var healthInfo = healthScoreColor(health.score);

          return '<div class="aq-fo-pond" data-pond-id="' + p.id + '">' +
            '<div class="aq-fo-pond-header">' +
              '<span class="aq-fo-pond-name">' + escapeHtml(p.name) + '</span>' +
              '<div class="aq-fo-pond-health" style="color:' + healthInfo.color + ';">' +
                '<div class="aq-fo-health-ring" style="background: conic-gradient(' + healthInfo.color + ' ' + (health.score * 3.6) + 'deg, rgba(255,255,255,0.08) 0deg);">' +
                  '<span>' + health.score + '</span>' +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="aq-fo-pond-stats">' +
              '<div class="aq-fo-stat"><span class="aq-fo-stat-label">Batches</span><span class="aq-fo-stat-val">' + pondBatches.length + '</span></div>' +
              '<div class="aq-fo-stat"><span class="aq-fo-stat-label">Shrimp</span><span class="aq-fo-stat-val">' + (shrimp >= 1000 ? (shrimp / 1000).toFixed(0) + 'K' : shrimp) + '</span></div>' +
              '<div class="aq-fo-stat"><span class="aq-fo-stat-label">ABW</span><span class="aq-fo-stat-val">' + abw.toFixed(1) + 'g</span></div>' +
              '<div class="aq-fo-stat"><span class="aq-fo-stat-label">Biomass</span><span class="aq-fo-stat-val">' + biomass + 'kg</span></div>' +
            '</div>' +
            '<div class="aq-fo-pond-feed">' +
              '<span class="aq-fo-feed-label">Feed Total</span>' +
              '<div class="aq-fo-feed-bar-wrap">' +
                '<div class="aq-fo-feed-bar" style="width:' + Math.min(100, feedTotal / 50000) + '%;"></div>' +
              '</div>' +
              '<span class="aq-fo-feed-val">' + (feedTotal >= 1000 ? (feedTotal / 1000).toFixed(0) + 'kg' : feedTotal + 'g') + '</span>' +
            '</div>' +
          '</div>';
        }).join('');

        return '<div class="aq-fo-inner">' +
          '<div class="aq-fo-header">' +
            '<span class="aq-fo-icon">🌾</span>' +
            '<div>' +
              '<div class="aq-fo-title">Farm Overview · खेत सारांश</div>' +
              '<div class="aq-fo-sub">' + ponds.length + ' ponds · ' + totalActiveBatches + ' active batches</div>' +
            '</div>' +
          '</div>' +
          '<div class="aq-fo-totals">' +
            '<div class="aq-fo-total"><span class="aq-fo-total-label">Total Shrimp</span><span class="aq-fo-total-val">' + (totalShrimp >= 1000 ? (totalShrimp / 1000).toFixed(0) + 'K' : totalShrimp) + '</span></div>' +
            '<div class="aq-fo-total"><span class="aq-fo-total-label">Total Biomass</span><span class="aq-fo-total-val">' + totalBiomass + ' kg</span></div>' +
            '<div class="aq-fo-total"><span class="aq-fo-total-label">Total Feed</span><span class="aq-fo-total-val">' + (totalFeed >= 1000 ? (totalFeed / 1000).toFixed(0) + 'kg' : totalFeed + 'g') + '</span></div>' +
          '</div>' +
          '<div class="aq-fo-ponds-grid">' + pondCards + '</div>' +
        '</div>';
      }

      function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, function (c) {
          return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqFarmOverviewHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(inject, 600);
            setTimeout(inject, 1200);
          }
          return r;
        };
        window.switchPage._aqFarmOverviewHooked = true;
      }

      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'dashboardContextSelect') setTimeout(inject, 600);
      });

      registerPeriodicCheck(function () {
        var d = document.getElementById('pageDashboard');
        if (!d || !d.classList.contains('active')) return;
        var c = document.getElementById('dashboardContextSelect');
        if (!c || c.value !== 'farm') return;
        if (!d.querySelector('.aq-farm-overview-card')) inject();
      }, 'farmOverview');
    }, 'initFarmOverview');
  }

  /* ═══════════════════════════════════════════════════════════════
     Y. FEED TEMPLATE CUSTOM NAMING — Modal to name templates
     Replaces the auto-generated name with a modal dialog that lets
     users enter a custom name when saving a feed template.
     ═══════════════════════════════════════════════════════════════ */
  function initTemplateNaming() {
    safe(function () {
      // Intercept the save button click to show a naming modal
      document.body.addEventListener('click', function (e) {
        if (!e.target.closest('#aqTplSaveBtn')) return;
        // Read current form state
        var qty = {};
        var hasAny = false;
        ['fs1', 'fs2', 'fs3', 'fs4', 'fs5'].forEach(function (fs) {
          var cb = document.getElementById('cb_' + fs);
          var qtyEl = document.getElementById('qty_' + fs);
          if (cb && cb.checked && qtyEl && qtyEl.value && parseFloat(qtyEl.value) > 0) {
            qty[fs] = qtyEl.value;
            hasAny = true;
          }
        });
        var otherCb = document.getElementById('cb_other');
        var otherQty = document.getElementById('otherFeedQty');
        if (otherCb && otherCb.checked && otherQty && otherQty.value && parseFloat(otherQty.value) > 0) {
          qty.other = otherQty.value;
          hasAny = true;
        }

        if (!hasAny) {
          if (typeof window.showToast === 'function') {
            window.showToast('⚠️', 'No Feed Selected', 'Check sizes and enter quantities first.', 'warn', 2500);
          }
          return;
        }

        // Show naming modal
        showNamingModal(qty);
      }, true); // capture to intercept before the other handler

      function showNamingModal(qty) {
        var overlay = document.createElement('div');
        overlay.className = 'aq-naming-overlay';
        var defaultName = 'Template ' + (getFeedTemplates().length + 1);
        overlay.innerHTML =
          '<div class="aq-naming-modal">' +
            '<div class="aq-naming-header">' +
              '<span class="aq-naming-icon">💾</span>' +
              '<span>Save Feed Template</span>' +
              '<button class="aq-naming-close">✕</button>' +
            '</div>' +
            '<div class="aq-naming-body">' +
              '<label class="aq-naming-label">Template Name</label>' +
              '<input type="text" class="fi aq-naming-input" id="aqNamingInput" value="' + escapeHtml(defaultName) + '" maxlength="40" placeholder="e.g. Morning Feed, Growout Stage 2…"/>' +
              '<div class="aq-naming-preview">' +
                '<div class="aq-naming-preview-label">Contents:</div>' +
                '<div class="aq-naming-preview-chips">' +
                  Object.keys(qty).map(function (k) {
                    return '<span class="aq-tpl-chip">' + k + ': ' + qty[k] + 'g</span>';
                  }).join('') +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="aq-naming-actions">' +
              '<button class="pill-btn grey-btn aq-naming-cancel">Cancel</button>' +
              '<button class="pill-btn green-btn aq-naming-confirm">✓ Save Template</button>' +
            '</div>' +
          '</div>';

        function escapeHtml(s) {
          return String(s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
          });
        }

        document.body.appendChild(overlay);
        requestAnimationFrame(function () {
          overlay.classList.add('aq-naming-open');
          var input = document.getElementById('aqNamingInput');
          if (input) { input.focus(); input.select(); }
        });

        function close() {
          overlay.classList.remove('aq-naming-open');
          setTimeout(function () { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, 250);
        }

        function confirmSave() {
          var name = document.getElementById('aqNamingInput')?.value?.trim() || defaultName;
          var template = { name: name, qty: qty };
          if (saveFeedTemplate(template)) {
            if (typeof window.showToast === 'function') {
              window.showToast('💾', 'Template Saved', name + ' saved with ' + Object.keys(qty).length + ' feed sizes.', 'success', 2500);
            }
            // Refresh the templates list
            var listEl = document.getElementById('aqTplList');
            if (listEl) {
              // Trigger refresh by re-injecting the templates card
              var card = document.querySelector('.aq-templates-card');
              if (card) {
                // Re-render the list
                var templates = getFeedTemplates();
                if (templates.length === 0) {
                  listEl.innerHTML = '<div class="aq-templates-empty">No templates yet.</div>';
                } else {
                  listEl.innerHTML = templates.map(function (t) {
                    var sizes = Object.keys(t.qty || {}).map(function (k) {
                      return '<span class="aq-tpl-chip">' + k + ': ' + t.qty[k] + 'g</span>';
                    }).join('');
                    return '<div class="aq-tpl-item" data-id="' + t.id + '">' +
                      '<div class="aq-tpl-info">' +
                        '<div class="aq-tpl-name">' + escapeHtml(t.name) + '</div>' +
                        '<div class="aq-tpl-chips">' + sizes + '</div>' +
                        '<div class="aq-tpl-date">Saved ' + new Date(t.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) + '</div>' +
                      '</div>' +
                      '<div class="aq-tpl-actions">' +
                        '<button class="aq-tpl-apply" data-id="' + t.id + '">Apply</button>' +
                        '<button class="aq-tpl-delete" data-id="' + t.id + '">🗑</button>' +
                      '</div>' +
                    '</div>';
                  }).join('');
                }
              }
            }
          }
          close();
        }

        overlay.querySelector('.aq-naming-close').addEventListener('click', close);
        overlay.querySelector('.aq-naming-cancel').addEventListener('click', close);
        overlay.querySelector('.aq-naming-confirm').addEventListener('click', confirmSave);
        overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });

        // Enter key saves
        var input = document.getElementById('aqNamingInput');
        if (input) {
          input.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') { e.preventDefault(); confirmSave(); }
            if (e.key === 'Escape') { e.preventDefault(); close(); }
          });
        }

        // Prevent the original save handler from also firing
        e.stopPropagation && e.stopPropagation();
      }
    }, 'initTemplateNaming');
  }

  /* ═══════════════════════════════════════════════════════════════
     Z. BATCH COMPARISON OVER TIME — Growth at same DOC
     Adds a "Growth Comparison" tab to the Batch Comparison modal.
     Shows how active batches compare at the same Day of Culture (DOC)
     — e.g., which batch had the highest ABW at DOC 30, 60, 90.
     ═══════════════════════════════════════════════════════════════ */
  function initBatchComparisonOverTime() {
    safe(function () {
      function injectButton() {
        var managePage = document.getElementById('pageManage');
        if (!managePage || !managePage.classList.contains('active')) return;
        var scroll = managePage.querySelector('.page-scroll');
        if (!scroll) return;
        if (scroll.querySelector('.aq-growth-compare-btn-wrap')) return;

        var wrap = document.createElement('div');
        wrap.className = 'aq-growth-compare-btn-wrap aq-compare-btn-wrap';
        wrap.innerHTML = '<button class="aq-compare-btn" id="aqGrowthCompareBtn" style="background: linear-gradient(135deg, rgba(167,139,250,0.12) 0%, rgba(0,229,245,0.08) 100%); border-color: rgba(167,139,250,0.2);">' +
          '<span class="aq-compare-btn-icon">📈</span>' +
          '<span>Growth Comparison · वृद्धि तुलना</span>' +
        '</button>';
        // Insert after the other compare buttons
        var existingBtns = scroll.querySelectorAll('.aq-compare-btn-wrap');
        if (existingBtns.length > 0 && existingBtns[existingBtns.length - 1].nextSibling) {
          scroll.insertBefore(wrap, existingBtns[existingBtns.length - 1].nextSibling);
        } else {
          var heroSm = scroll.querySelector('.page-hero-sm');
          if (heroSm && heroSm.nextSibling) {
            scroll.insertBefore(wrap, heroSm.nextSibling);
          } else {
            scroll.appendChild(wrap);
          }
        }
      }

      function showGrowthComparisonModal() {
        var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
        var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
        var ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]');
        var pondMap = {};
        (ponds || []).forEach(function (p) { pondMap[p.id] = p.name; });

        // Use all batches that have sampling data
        var batchesWithSampling = (batches || []).filter(function (b) {
          if (!b) return false;
          return (sampling || []).some(function (s) { return s && s.batchId === b.id; });
        });

        if (batchesWithSampling.length < 2) {
          if (typeof window.showToast === 'function') {
            window.showToast('⚠️', 'Need 2+ Batches', 'Growth comparison requires at least 2 batches with sampling data.', 'warn', 2800);
          }
          return;
        }

        // Define DOC milestones
        var milestones = [7, 15, 30, 45, 60, 75, 90, 105, 120];

        // For each batch, find the ABW at each milestone (closest sampling within ±3 days)
        var batchData = batchesWithSampling.map(function (b) {
          var batchSampling = (sampling || []).filter(function (s) {
            return s && s.batchId === b.id;
          }).sort(function (a, c) { return new Date(a.date) - new Date(c.date); });

          var start = new Date(b.stockingDate || b.createdAt);
          var milestoneABWs = {};
          milestones.forEach(function (m) {
            var targetDate = new Date(start.getTime() + m * 24 * 60 * 60 * 1000);
            var closest = null;
            var minDiff = Infinity;
            batchSampling.forEach(function (s) {
              var sd = new Date(s.date);
              var diff = Math.abs(sd - targetDate);
              if (diff < minDiff && diff <= 3 * 24 * 60 * 60 * 1000) {
                minDiff = diff;
                closest = s;
              }
            });
            milestoneABWs[m] = closest ? closest.abw : null;
          });

          return {
            id: b.id,
            pond: pondMap[b.pondId] || b.pond || 'Pond',
            batchNum: b.batchNumber,
            completed: !!b.completedAt,
            milestoneABWs: milestoneABWs,
            lastABW: batchSampling.length > 0 ? batchSampling[batchSampling.length - 1].abw : 0
          };
        });

        var overlay = document.createElement('div');
        overlay.className = 'aq-compare-overlay';
        overlay.innerHTML =
          '<div class="aq-compare-modal">' +
            '<div class="aq-compare-modal-header">' +
              '<span class="aq-compare-modal-icon">📈</span>' +
              '<div><div class="aq-compare-modal-title">Growth Comparison Over Time</div>' +
              '<div class="aq-compare-modal-sub">' + batchData.length + ' batches · ABW at key DOC milestones</div></div>' +
              '<button class="aq-compare-modal-close">✕</button>' +
            '</div>' +
            '<div class="aq-compare-modal-body">' +
              renderGrowthTable(batchData, milestones) +
            '</div>' +
          '</div>';

        function renderGrowthTable(batchData, milestones) {
          // Find best ABW at each milestone
          function bestAt(milestone) {
            var best = 0;
            batchData.forEach(function (b) {
              if (b.milestoneABWs[milestone] && b.milestoneABWs[milestone] > best) {
                best = b.milestoneABWs[milestone];
              }
            });
            return best;
          }

          var header = '<div class="aq-compare-row aq-compare-header">' +
            '<div class="aq-compare-cell aq-compare-cell-label">Batch</div>' +
            batchData.map(function (b) {
              return '<div class="aq-compare-cell"><div class="aq-compare-cell-pond">' + escapeHtml(b.pond) + '</div><div class="aq-compare-cell-batch">#' + b.batchNum + (b.completed ? ' ✓' : '') + '</div></div>';
            }).join('') +
          '</div>';

          var milestoneRows = milestones.map(function (m) {
            var best = bestAt(m);
            var values = batchData.map(function (b) {
              return b.milestoneABWs[m];
            });
            return '<div class="aq-compare-row">' +
              '<div class="aq-compare-cell aq-compare-cell-label">DOC ' + m + '</div>' +
              values.map(function (v) {
                var isBest = v === best && v > 0;
                return '<div class="aq-compare-cell' + (isBest ? ' aq-compare-best' : '') + '">' +
                  (v !== null ? v.toFixed(2) + 'g' : '—') +
                  (isBest ? ' <span class="aq-compare-star">★</span>' : '') +
                '</div>';
              }).join('') +
            '</div>';
          }).join('');

          var lastRow = '<div class="aq-compare-row">' +
            '<div class="aq-compare-cell aq-compare-cell-label">Latest ABW</div>' +
            batchData.map(function (b) {
              var best = Math.max.apply(null, batchData.map(function (x) { return x.lastABW; }));
              var isBest = b.lastABW === best && b.lastABW > 0;
              return '<div class="aq-compare-cell' + (isBest ? ' aq-compare-best' : '') + '">' +
                b.lastABW.toFixed(2) + 'g' +
                (isBest ? ' <span class="aq-compare-star">★</span>' : '') +
              '</div>';
            }).join('') +
          '</div>';

          return '<div class="aq-compare-table">' +
            header +
            milestoneRows +
            lastRow +
          '</div>';
        }

        function escapeHtml(s) {
          return String(s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
          });
        }

        document.body.appendChild(overlay);
        requestAnimationFrame(function () { overlay.classList.add('aq-compare-open'); });

        function close() {
          overlay.classList.remove('aq-compare-open');
          setTimeout(function () { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, 250);
        }
        overlay.querySelector('.aq-compare-modal-close').addEventListener('click', close);
        overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
        var escHandler = function (e) { if (e.key === 'Escape') { close(); document.removeEventListener('keydown', escHandler); } };
        document.addEventListener('keydown', escHandler);
      }

      document.body.addEventListener('click', function (e) {
        if (e.target.closest('#aqGrowthCompareBtn')) {
          showGrowthComparisonModal();
        }
      });

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqGrowthCompareHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageManage') setTimeout(injectButton, 350);
          return r;
        };
        window.switchPage._aqGrowthCompareHooked = true;
      }
    }, 'initBatchComparisonOverTime');
  }

  /* ═══════════════════════════════════════════════════════════════
     AA. FCR TRACKER — Feed Conversion Ratio per batch
     Shows on batch detail view (below batch timeline). FCR = total
     feed / total biomass gain. A lower FCR is better (more efficient).
     Displays current FCR, target FCR range, and FCR trend.
     ═══════════════════════════════════════════════════════════════ */
  function initFCRTracker() {
    safe(function () {
      function inject() {
        var dashboard = document.getElementById('pageDashboard');
        if (!dashboard || !dashboard.classList.contains('active')) return;
        var scroll = dashboard.querySelector('.page-scroll');
        if (!scroll) return;

        var contextSel = document.getElementById('dashboardContextSelect');
        if (!contextSel || contextSel.value === 'farm' || contextSel.value.indexOf('batch_') === -1) {
          var existing = scroll.querySelector('.aq-fcr-card');
          if (existing) existing.remove();
          return;
        }

        if (scroll.querySelector('.aq-fcr-card')) return;

        var batchId = contextSel.value.replace(/^batch_/, '');
        var fcrData = calcFCR(batchId);
        if (!fcrData) return;

        var old = scroll.querySelector('.aq-fcr-card');
        if (old) old.remove();

        var card = document.createElement('div');
        card.className = 'aq-fcr-card';

        // FCR status: <1.2 excellent, 1.2-1.6 good, 1.6-2.0 fair, >2.0 poor
        var fcrStatus, fcrColor, fcrIcon;
        if (fcrData.fcr < 1.2) { fcrStatus = 'Excellent'; fcrColor = '#10b981'; fcrIcon = '🌟'; }
        else if (fcrData.fcr < 1.6) { fcrStatus = 'Good'; fcrColor = '#00e5f5'; fcrIcon = '✅'; }
        else if (fcrData.fcr < 2.0) { fcrStatus = 'Fair'; fcrColor = '#fbbf24'; fcrIcon = '⚠️'; }
        else { fcrStatus = 'Poor'; fcrColor = '#f43f5e'; fcrIcon = '🚨'; }

        card.innerHTML =
          '<div class="aq-fcr-inner">' +
            '<div class="aq-fcr-header">' +
              '<span class="aq-fcr-icon">📊</span>' +
              '<span>FCR Tracker · फ़ीड रूपांतरण अनुपात</span>' +
            '</div>' +
            '<div class="aq-fcr-body">' +
              '<div class="aq-fcr-main">' +
                '<div class="aq-fcr-value" style="color:' + fcrColor + ';">' + fcrData.fcr.toFixed(2) + '</div>' +
                '<div class="aq-fcr-status" style="color:' + fcrColor + ';">' + fcrIcon + ' ' + fcrStatus + '</div>' +
              '</div>' +
              '<div class="aq-fcr-details">' +
                '<div class="aq-fcr-detail-row">' +
                  '<span>Total Feed</span><span>' + (fcrData.totalFeedKg).toFixed(1) + ' kg</span>' +
                '</div>' +
                '<div class="aq-fcr-detail-row">' +
                  '<span>Est. Biomass</span><span>' + (fcrData.biomassKg).toFixed(1) + ' kg</span>' +
                '</div>' +
                '<div class="aq-fcr-detail-row">' +
                  '<span>Shrimp Count</span><span>' + fcrData.shrimpCount.toLocaleString() + '</span>' +
                '</div>' +
                '<div class="aq-fcr-detail-row">' +
                  '<span>Current ABW</span><span>' + fcrData.abw.toFixed(2) + ' g</span>' +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="aq-fcr-scale">' +
              '<div class="aq-fcr-scale-label">FCR Scale</div>' +
              '<div class="aq-fcr-scale-bar">' +
                '<div class="aq-fcr-scale-seg aq-fcr-excellent" title="<1.2 Excellent"></div>' +
                '<div class="aq-fcr-scale-seg aq-fcr-good" title="1.2-1.6 Good"></div>' +
                '<div class="aq-fcr-scale-seg aq-fcr-fair" title="1.6-2.0 Fair"></div>' +
                '<div class="aq-fcr-scale-seg aq-fcr-poor" title=">2.0 Poor"></div>' +
                '<div class="aq-fcr-scale-marker" style="left:' + Math.min(100, fcrData.fcr / 2.5 * 100) + '%; background:' + fcrColor + ';"></div>' +
              '</div>' +
              '<div class="aq-fcr-scale-labels">' +
                '<span>0</span><span>1.2</span><span>1.6</span><span>2.0</span><span>2.5+</span>' +
              '</div>' +
            '</div>' +
            '<div class="aq-fcr-tip">' +
              '💡 FCR = Total Feed ÷ Biomass Gain. Target: 1.2–1.6 for shrimp. Lower is better.' +
            '</div>' +
          '</div>';

        // Insert after the batch summary card (which is OUTSIDE farmOverviewContent)
        var batchSummary = document.getElementById('batchSummaryCard') || scroll.querySelector('.batch-summary-card');
        if (batchSummary && batchSummary.parentNode) {
          try { batchSummary.parentNode.appendChild(card); } catch (_) { scroll.appendChild(card); }
        } else {
          scroll.appendChild(card);
        }
      }

      function calcFCR(batchId) {
        var data = null;
        safe(function () {
          var batches = JSON.parse(localStorage.getItem('al_batches') || '[]');
          var records = JSON.parse(localStorage.getItem('al_records') || '[]');
          var sampling = JSON.parse(localStorage.getItem('al_sampling') || '[]');
          var batch = (batches || []).find(function (b) { return b && b.id === batchId; });
          if (!batch) return;

          // Total feed for this pond
          var pondRecords = (records || []).filter(function (r) { return r && r.pondId === batch.pondId; });
          var totalFeedG = pondRecords.reduce(function (s, r) { return s + (parseFloat(r.totalQty || r.total || 0)); }, 0);
          var totalFeedKg = totalFeedG / 1000;

          // Current ABW from latest sampling
          var batchSampling = (sampling || []).filter(function (s) { return s && s.batchId === batchId; })
            .sort(function (a, b) { return new Date(a.date) - new Date(b.date); });
          var lastSample = batchSampling.length > 0 ? batchSampling[batchSampling.length - 1] : null;
          var abw = lastSample ? lastSample.abw : 0;

          // Shrimp count
          var shrimpCount = batch.shrimpCount || 0;

          // Estimated biomass = shrimp × ABW (in kg)
          var biomassKg = (shrimpCount * abw) / 1000;

          // FCR = total feed / biomass
          var fcr = biomassKg > 0 ? totalFeedKg / biomassKg : 0;

          data = {
            fcr: fcr,
            totalFeedKg: totalFeedKg,
            biomassKg: biomassKg,
            shrimpCount: shrimpCount,
            abw: abw
          };
        });
        return data;
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqFCRHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageDashboard') {
            setTimeout(inject, 800);
            setTimeout(inject, 1500);
          }
          return r;
        };
        window.switchPage._aqFCRHooked = true;
      }

      document.body.addEventListener('change', function (e) {
        if (e.target.id === 'dashboardContextSelect') setTimeout(inject, 800);
      });

      registerPeriodicCheck(function () {
        var d = document.getElementById('pageDashboard');
        if (!d || !d.classList.contains('active')) return;
        var c = document.getElementById('dashboardContextSelect');
        if (!c || c.value.indexOf('batch_') === -1) return;
        if (!d.querySelector('.aq-fcr-card')) inject();
      }, 'fcrTracker');
    }, 'initFCRTracker');
  }

  /* ═══════════════════════════════════════════════════════════════
     BB. BATCH LIFECYCLE STAGES — Visual stage indicator
     Adds a stage badge to each pond card on the Manage page showing
     which lifecycle stage the active batch is in:
       - Nursery (DOC 0-25)
       - Growout Early (DOC 26-60)
       - Growout Mid (DOC 61-90)
       - Finishing (DOC 91-120)
       - Harvest Ready (DOC 120+)
     ═══════════════════════════════════════════════════════════════ */
  function initBatchLifecycleStages() {
    safe(function () {
      function injectBadges() {
        var managePage = document.getElementById('pageManage');
        if (!managePage || !managePage.classList.contains('active')) return;

        var pondCards = managePage.querySelectorAll('.pond-card');
        pondCards.forEach(function (card) {
          if (card.querySelector('.aq-lifecycle-badge')) return; // already injected

          var pondNameEl = card.querySelector('.pond-card-name');
          if (!pondNameEl) return;
          var pondName = pondNameEl.textContent.trim();

          var ponds = [];
          try { ponds = JSON.parse(localStorage.getItem('al_ponds') || '[]'); } catch (_) {}
          var pond = ponds.find(function (p) { return p.name === pondName; });
          if (!pond) return;

          // Find active batch for this pond
          var batches = [];
          try { batches = JSON.parse(localStorage.getItem('al_batches') || '[]'); } catch (_) {}
          var activeBatch = (batches || []).find(function (b) {
            return b && b.pondId === pond.id && !b.completedAt;
          });
          if (!activeBatch) return;

          // Calculate DOC
          var start = new Date(activeBatch.stockingDate || activeBatch.createdAt);
          var doc = Math.floor((new Date() - start) / (1000 * 60 * 60 * 24));

          // Determine stage
          var stage, color, icon;
          if (doc <= 25) { stage = 'Nursery'; color = '#38bdf8'; icon = '🌱'; }
          else if (doc <= 60) { stage = 'Growout Early'; color = '#00e5f5'; icon = '🌿'; }
          else if (doc <= 90) { stage = 'Growout Mid'; color = '#10b981'; icon = '🐟'; }
          else if (doc <= 120) { stage = 'Finishing'; color = '#fbbf24'; icon = '⚖️'; }
          else { stage = 'Harvest Ready'; color = '#f43f5e'; icon = '🎯'; }

          // Create badge
          var badge = document.createElement('div');
          badge.className = 'aq-lifecycle-badge';
          badge.style.borderColor = color;
          badge.innerHTML =
            '<span class="aq-lifecycle-icon">' + icon + '</span>' +
            '<span class="aq-lifecycle-stage" style="color:' + color + ';">' + stage + '</span>' +
            '<span class="aq-lifecycle-doc">DOC ' + doc + '</span>';

          // Insert into the pond card top area, after health badge
          var top = card.querySelector('.pond-card-top');
          if (top) {
            top.appendChild(badge);
          } else {
            card.insertBefore(badge, card.firstChild);
          }
        });
      }

      var origSwitchPage = window.switchPage;
      if (typeof origSwitchPage === 'function' && !origSwitchPage._aqLifecycleHooked) {
        window.switchPage = function (pageId) {
          var r = origSwitchPage.apply(this, arguments);
          if (pageId === 'pageManage') {
            setTimeout(injectBadges, 350);
          }
          return r;
        };
        window.switchPage._aqLifecycleHooked = true;
      }

      registerPeriodicCheck(function () {
        var mp = document.getElementById('pageManage');
        if (!mp || !mp.classList.contains('active')) return;
        var cards = mp.querySelectorAll('.pond-card');
        if (cards.length === 0) return;
        // Check if any card is missing the badge
        var needsInject = false;
        cards.forEach(function (c) {
          if (!c.querySelector('.aq-lifecycle-badge')) needsInject = true;
        });
        if (needsInject) injectBadges();
      }, 'lifecycleStages');
    }, 'initBatchLifecycleStages');
  }

  function boot() {
    window.__AQ_EXTRA_BOOT = (window.__AQ_EXTRA_BOOT || 0) + 1;
    safe(injectStyles, 'injectStyles');
    safe(initThemeSystem, 'initThemeSystem');
    safe(bindSettingsButtons, 'bindSettingsButtons');
    safe(initNotifications, 'initNotifications');
    safe(initQuickStatsWidget, 'initQuickStatsWidget');
    safe(initTodaysTasksWidget, 'initTodaysTasksWidget');
    safe(initInsightsCard, 'initInsightsCard');
    safe(initActivityTimeline, 'initActivityTimeline');
    safe(initPondHealthScore, 'initPondHealthScore');
    safe(initFeedCostCalculator, 'initFeedCostCalculator');
    safe(initHarvestPredictor, 'initHarvestPredictor');
    safe(initBatchComparison, 'initBatchComparison');
    safe(initWeatherFeedRec, 'initWeatherFeedRec');
    safe(initCostAnalytics, 'initCostAnalytics');
    safe(initGrowthAlerts, 'initGrowthAlerts');
    safe(initPondComparison, 'initPondComparison');
    safe(initWaterQualityTracking, 'initWaterQualityTracking');
    safe(initBatchTimeline, 'initBatchTimeline');
    safe(initWQTrendsChart, 'initWQTrendsChart');
    safe(initFeedScheduleTemplates, 'initFeedScheduleTemplates');
    safe(initConfigurableThresholds, 'initConfigurableThresholds');
    safe(initFarmOverview, 'initFarmOverview');
    safe(initTemplateNaming, 'initTemplateNaming');
    safe(initBatchComparisonOverTime, 'initBatchComparisonOverTime');
    safe(initFCRTracker, 'initFCRTracker');
    safe(initBatchLifecycleStages, 'initBatchLifecycleStages');
    safe(addSearchTrigger, 'addSearchTrigger');
    safe(bindKeyboardShortcuts, 'bindKeyboardShortcuts');

    // Add "Global Search" command to the existing command palette (if present)
    safe(function () {
      // The features.js command palette reads from a global array if available
      if (!window.__AQ_COMMANDS) window.__AQ_COMMANDS = [];
      window.__AQ_COMMANDS.push({
        title: 'Global Search',
        sub: 'Search ponds, batches, records, inventory',
        icon: '🔍',
        action: openGlobalSearch
      });
      // Theme toggle command removed — app is permanently dark.
    }, 'register commands in palette');

    // ── Fix #10 + #11: Dashboard context-change listener ──
    // When the user picks a different batch/pond from the dashboard dropdown,
    // refresh all three dynamic widgets so they immediately reflect the new
    // context (Farm vs Pond/Batch vs Completed batch).
    safe(function () {
      var sel = document.getElementById('dashboardContextSelect');
      if (!sel || sel._aqCtxHooked) return;
      sel._aqCtxHooked = true;
      sel.addEventListener('change', function () {
        // Slight delay so script.js's showFarmView/showBatchView runs first
        setTimeout(function () {
          if (typeof window.refreshAquaTasks    === 'function') window.refreshAquaTasks();
          if (typeof window.refreshAquaInsights === 'function') window.refreshAquaInsights();
          if (typeof window.refreshAquaTimeline === 'function') window.refreshAquaTimeline();
        }, 120);
      });
    }, 'bindDashboardContextListener');

    console.log('[AquaLog/extra] booted (round 13). All 28 features live: Theme, Tasks, Insights, Timeline, HealthScore, CostCalc, Harvest, BatchCompare, Weather, CostAnalytics, GrowthAlerts, PondCompare, WaterQuality, WQTrends, BatchTimeline, FeedTemplates, TemplateNaming, Thresholds, FarmOverview, GrowthCompare, FCRTracker, LifecycleStages, Search, QuickStats.');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }

})();
