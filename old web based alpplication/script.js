'use strict';


// --- Service: storage.js ---
(function() {
  'use strict';
/* ════════════════════════════════════════════════════════
   AquaLog — storage.js
   Centralised localStorage abstraction layer.

   Responsibility: this is the ONLY file that talks directly
   to localStorage. Every domain read/write in script.js goes
   through window.AppStorage instead.

   Pattern: mirrors the existing service files (siteManager.js,
   weatherService.js, etc.) — IIFE-wrapped, single namespaced
   window object, no external dependencies.

   Key inventory (all AquaLog localStorage keys live here):
     al_records       — feed log records array
     al_ponds         — ponds array
     al_queue         — offline sync queue array
     al_sheets_url    — Google Sheets webhook URL (string)
     al_batches       — batches array
     al_growth        — growth weight entries array
     al_hapa          — hapa survival entries array
     al_biomass       — biomass entries array
     al_sampling      — sampling entries array
     al_api_url       — custom API endpoint URL (string)
     al_api_method    — HTTP method for custom API (string)
     al_api_auth      — auth token for custom API (string)
     al_api_headers   — custom headers JSON string
     al_m3_theme      — Material You theme enabled ('true'/'false')
     al_outdoor_mode  — outdoor mode enabled ('true'/'false')
     al_font_size     — font size setting ('small'/'medium'/'large')
     al_inventory     — inventory transactions array (all sites; filter by siteId)
   ════════════════════════════════════════════════════════ */



  /* ── Storage key constants ──────────────────────────────── */
  const KEYS = Object.freeze({
    RECORDS    : 'al_records',
    PONDS      : 'al_ponds',
    QUEUE      : 'al_queue',
    SHEETS     : 'al_sheets_url',
    BATCHES    : 'al_batches',
    GROWTH     : 'al_growth',
    HAPA       : 'al_hapa',
    BIOMASS    : 'al_biomass',
    SAMPLING   : 'al_sampling',
    API_URL    : 'al_api_url',
    API_METHOD : 'al_api_method',
    API_AUTH   : 'al_api_auth',
    API_HEADERS: 'al_api_headers',
    M3_THEME   : 'al_m3_theme',
    OUTDOOR    : 'al_outdoor_mode',
    FONT_SIZE  : 'al_font_size',
    INVENTORY  : 'al_inventory',
    FINANCE_EXPENSES : 'al_finance_expenses',
    FINANCE_REVENUE  : 'al_finance_revenue',
    FINANCE_PRICES   : 'al_finance_prices',
  });

  /* ── Internal primitives ────────────────────────────────── */

  /**
   * loadJSON — Safe JSON read from localStorage.
   * Returns fallback on missing key or parse failure.
   */
  function loadJSON(key, fallback) {
    try {
      const v = localStorage.getItem(key);
      return v ? JSON.parse(v) : fallback;
    } catch {
      return fallback;
    }
  }

  /**
   * safeSet — Safe JSON write to localStorage.
   * Surfaces a meaningful toast on QuotaExceededError instead of
   * silently failing. (toast helper resolved at call time via
   * window.AppStorage._toast, wired by script.js after showToast exists.)
   */
  function safeSet(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (e) {
      console.error('[AquaLog Storage] Write failed for key:', key, e);
      // showToast is defined in script.js; call it if available
      if (typeof window.showToast === 'function') {
        window.showToast('⚠️', 'Storage Full', 'Could not save. Free up device storage and try again.');
      }
      return false;
    }
  }

  /**
   * safeSetRaw — Write a raw string value (no JSON.stringify).
   * Used for simple string keys like sheets URL.
   */
  function safeSetRaw(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (e) {
      console.error('[AquaLog Storage] Raw write failed for key:', key, e);
    }
  }

  /* ── Schema migration (runs at IIFE load, before script.js) ── */
  /* This block was previously inline at the top of script.js.    */
  /* Moving it here ensures all localStorage access still goes    */
  /* through this single module from the very first boot.         */

  function runMigrations() {
    const raw = localStorage.getItem(KEYS.PONDS);
    if (!raw) return; // fresh install — nothing to migrate

    let parsed;
    try { parsed = JSON.parse(raw); } catch { return; }

    // Migration 1: old string-array ponds → object format
    if (Array.isArray(parsed) && parsed.length > 0 && typeof parsed[0] === 'string') {
      const migrated = parsed.map(name => ({
        id      : 'pond_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7),
        name,
        site    : 'Default Site',
        sizeSqFt: 0,
        active  : true,
      }));
      localStorage.setItem(KEYS.PONDS, JSON.stringify(migrated));

      // Also migrate batches that reference pond by name string → new id
      const batchList = loadJSON(KEYS.BATCHES, []);
      let batchesChanged = false;
      batchList.forEach(b => {
        if (b.pond && !b.pondId) {
          const match = migrated.find(p => p.name === b.pond);
          if (match) { b.pondId = match.id; batchesChanged = true; }
        }
      });
      if (batchesChanged) localStorage.setItem(KEYS.BATCHES, JSON.stringify(batchList));
      return;
    }

    // Migration 2: object ponds missing required fields + harvest/hapa fields on batches
    if (Array.isArray(parsed) && (parsed.length === 0 || typeof parsed[0] === 'object')) {
      let pondsChanged = false;
      parsed.forEach(p => {
        if (p.site      === undefined) { p.site      = 'Default Site'; pondsChanged = true; }
        if (p.sizeSqFt  === undefined) { p.sizeSqFt  = 0;             pondsChanged = true; }
        if (p.active    === undefined) { p.active     = true;          pondsChanged = true; }
      });
      if (pondsChanged) localStorage.setItem(KEYS.PONDS, JSON.stringify(parsed));

      const batchList = loadJSON(KEYS.BATCHES, []);
      let batchChanged = false;
      batchList.forEach(b => {
        if (b.harvestDate      === undefined) { b.harvestDate      = null; batchChanged = true; }
        if (b.harvestTime      === undefined) { b.harvestTime      = null; batchChanged = true; }
        if (b.finalShrimpCount === undefined) { b.finalShrimpCount = null; batchChanged = true; }
        if (b.harvestWeightKg  === undefined) { b.harvestWeightKg  = null; batchChanged = true; }
        if (b.completionNotes  === undefined) { b.completionNotes  = null; batchChanged = true; }
        if (b.survivalPercent  === undefined) { b.survivalPercent  = null; batchChanged = true; }
        if (b.hapaStocked      === undefined) { b.hapaStocked      = 100;  batchChanged = true; }
      });
      if (batchChanged) localStorage.setItem(KEYS.BATCHES, JSON.stringify(batchList));
    }
  }

  // Run migrations immediately at module load
  runMigrations();

  /* ── Public API ─────────────────────────────────────────── */
  const AppStorage = {

    /** Expose key names so script.js can reference them symbolically */
    KEYS,

    /* Domain array getters / setters */
    getRecords  : ()  => loadJSON(KEYS.RECORDS,  []),
    saveRecords : (v) => safeSet(KEYS.RECORDS,   v),

    getPonds    : ()  => loadJSON(KEYS.PONDS,    []),
    savePonds   : (v) => safeSet(KEYS.PONDS,     v),

    getBatches  : ()  => loadJSON(KEYS.BATCHES,  []),
    saveBatches : (v) => safeSet(KEYS.BATCHES,   v),

    getQueue    : ()  => loadJSON(KEYS.QUEUE,    []),
    saveQueue   : (v) => safeSet(KEYS.QUEUE,     v),

    getGrowth   : ()  => loadJSON(KEYS.GROWTH,   []),
    saveGrowth  : (v) => safeSet(KEYS.GROWTH,    v),

    getHapa     : ()  => loadJSON(KEYS.HAPA,     []),
    saveHapa    : (v) => safeSet(KEYS.HAPA,      v),

    getBiomass  : ()  => loadJSON(KEYS.BIOMASS,  []),
    saveBiomass : (v) => safeSet(KEYS.BIOMASS,   v),

    getSampling : ()  => loadJSON(KEYS.SAMPLING, []),
    saveSampling: (v) => safeSet(KEYS.SAMPLING,  v),

    /* Google Sheets URL (stored as raw string, not JSON) */
    getSheetsUrl : ()  => localStorage.getItem(KEYS.SHEETS) || '',
    saveSheetsUrl: (v) => safeSetRaw(KEYS.SHEETS, v),

    /* Custom REST API settings */
    getApiSettings() {
      return {
        url    : localStorage.getItem(KEYS.API_URL)     || '',
        method : localStorage.getItem(KEYS.API_METHOD)  || 'POST',
        auth   : localStorage.getItem(KEYS.API_AUTH)    || '',
        headers: localStorage.getItem(KEYS.API_HEADERS) || '',
      };
    },
    saveApiSettings(obj) {
      safeSetRaw(KEYS.API_URL,     obj.url     ?? '');
      safeSetRaw(KEYS.API_METHOD,  obj.method  ?? 'POST');
      safeSetRaw(KEYS.API_AUTH,    obj.auth    ?? '');
      safeSetRaw(KEYS.API_HEADERS, obj.headers ?? '');
    },

    /* Theme / preferences */
    getTheme    : ()  => localStorage.getItem(KEYS.M3_THEME) || 'false',
    saveTheme   : (v) => safeSetRaw(KEYS.M3_THEME, String(v)),

    getSetting  : (key) => localStorage.getItem(key),
    saveSetting : (key, value) => safeSetRaw(key, value),

    /**
     * bulkSet — Write multiple data keys at once (used by demo data loader).
     * map: { records, ponds, batches, queue, growth, hapa, sampling }
     * Pass null/undefined for any key to skip it.
     */
    bulkSet(map) {
      if (map.records  !== undefined) safeSet(KEYS.RECORDS,  map.records);
      if (map.ponds    !== undefined) safeSet(KEYS.PONDS,    map.ponds);
      if (map.batches  !== undefined) safeSet(KEYS.BATCHES,  map.batches);
      if (map.queue    !== undefined) safeSet(KEYS.QUEUE,    map.queue);
      if (map.growth   !== undefined) safeSet(KEYS.GROWTH,   map.growth);
      if (map.hapa     !== undefined) safeSet(KEYS.HAPA,     map.hapa);
      if (map.sampling !== undefined) safeSet(KEYS.SAMPLING, map.sampling);
    },

    /**
     * removeItem — Remove a single key (used during reset and demo reload).
     */
    removeItem: (key) => {
      try { localStorage.removeItem(key); } catch (e) { /* ignore */ }
    },

    /**
     * clearDomainData — Delete all domain data keys, keeping settings/theme.
     * Called by the "Reset All Data" developer tool.
     */
    clearDomainData() {
      [
        KEYS.RECORDS, KEYS.PONDS, KEYS.BATCHES,
        KEYS.GROWTH,  KEYS.HAPA,  KEYS.BIOMASS,
        KEYS.SAMPLING, KEYS.QUEUE, KEYS.INVENTORY,
        KEYS.FINANCE_EXPENSES, KEYS.FINANCE_REVENUE, KEYS.FINANCE_PRICES,
        // C7 fix: these keys were missing, leaving stale data after "Reset All Data"
        'al_sites', 'al_weather_cache', 'al_weather_history',
        'al_inventory_thresholds', 'al_inventory_migrated_v1',
        // C8 fix: these were also missing — Finance, water quality, feed
        // templates, and notification settings survived a "full" reset
        'al_water_quality', 'al_notif_settings', 'al_feed_templates',
      ].forEach(k => {
        try { localStorage.removeItem(k); } catch (e) { /* ignore */ }
      });
    },

    /* ── Inventory (Farm → Site → Inventory) ──────────────────
       Inventory Transaction is the single source of truth — current
       stock is never stored, only ever derived by summing transactions.
       Every method below is site-scoped: inventory never leaks across
       sites and is never treated as a global pool. ───────────────── */

    /**
     * getAllInventoryTransactions — Raw, unfiltered read of every
     * inventory transaction across every site. Internal primitive;
     * prefer getInventoryTransactions(siteId) from calling code so
     * data always stays site-scoped. Exposed for migration/export/
     * future Finance-module use where a cross-site view is required.
     * @returns {Array<object>}
     */
    getAllInventoryTransactions: () => loadJSON(KEYS.INVENTORY, []),

    /**
     * saveAllInventoryTransactions — Raw, unfiltered write of the
     * entire inventory transaction array. Internal primitive.
     * @param {Array<object>} v
     */
    saveAllInventoryTransactions: (v) => safeSet(KEYS.INVENTORY, v),

    /**
     * getInventoryTransactions — All inventory transactions for a
     * single site, oldest first. This is the primary read method
     * every UI module and future module (Medicine Log, Fuel Usage,
     * Finance) should use.
     * @param {string} siteId
     * @returns {Array<object>}
     */
    getInventoryTransactions(siteId) {
      if (!siteId) return [];
      return loadJSON(KEYS.INVENTORY, [])
        .filter(t => t.siteId === siteId)
        .sort((a, b) => (a.createdAt || '').localeCompare(b.createdAt || ''));
    },

    /**
     * addInventoryTransaction — Persist a single, already-built
     * inventory transaction. Does not validate or normalise — use
     * InventoryManager.createTransaction() for that; this is the
     * low-level storage primitive it (and migrations) writes through.
     * @param {object} tx - full transaction record (must include siteId, id)
     * @returns {object} the same tx, for chaining
     */
    addInventoryTransaction(tx) {
      const all = loadJSON(KEYS.INVENTORY, []);
      all.push(tx);
      // C13 fix: return null on write failure so createTransaction can surface the error
      if (!safeSet(KEYS.INVENTORY, all)) return null;
      return tx;
    },

    /**
     * bulkAddInventoryTransactions — Append many transactions in a
     * single read + write. Use this instead of calling
     * addInventoryTransaction() in a loop to avoid O(N²) I/O.
     * @param {object[]} txArray - array of fully built transaction objects
     * @returns {number} count of transactions added
     */
    bulkAddInventoryTransactions(txArray) {
      if (!txArray || !txArray.length) return 0;
      const all = loadJSON(KEYS.INVENTORY, []);
      txArray.forEach(tx => all.push(tx));
      // C13 fix: return 0 on write failure
      if (!safeSet(KEYS.INVENTORY, all)) return 0;
      return txArray.length;
    },

    /**
     * updateInventoryTransaction — Merge a partial patch into an
     * existing transaction by id and bump updatedAt.
     * @param {string} id
     * @param {object} data - partial fields to merge
     * @returns {object|null} the updated transaction, or null if not found
     */
    updateInventoryTransaction(id, data) {
      const all = loadJSON(KEYS.INVENTORY, []);
      const idx = all.findIndex(t => t.id === id);
      if (idx === -1) return null;
      all[idx] = Object.assign({}, all[idx], data, { id: all[idx].id, updatedAt: new Date().toISOString() });
      safeSet(KEYS.INVENTORY, all);
      return all[idx];
    },

    /**
     * deleteInventoryTransaction — Remove a transaction by id.
     * @param {string} id
     * @returns {boolean} true if a transaction was removed
     */
    deleteInventoryTransaction(id) {
      const all = loadJSON(KEYS.INVENTORY, []);
      const next = all.filter(t => t.id !== id);
      const changed = next.length !== all.length;
      if (changed) safeSet(KEYS.INVENTORY, next);
      return changed;
    },

    /**
     * getInventoryByCategory — Site-scoped transactions filtered to
     * one category ('feed' | 'medicine' | 'fuel').
     * @param {string} siteId
     * @param {string} category
     * @returns {Array<object>}
     */
    getInventoryByCategory(siteId, category) {
      return this.getInventoryTransactions(siteId).filter(t => t.category === category);
    },

    /**
     * getStockBalance — Current on-hand stock for one item, derived
     * by summing every transaction's signed quantity. This is the
     * canonical "current stock" calculation — never read a stored
     * stock field, always call this (or InventoryManager.calculateStock,
     * which wraps it).
     * @param {string} siteId
     * @param {string} category
     * @param {string} itemName
     * @returns {number}
     */
    getStockBalance(siteId, category, itemName) {
      const name = (itemName || '').trim().toLowerCase();
      // L9 fix: return 0 for empty itemName (was aggregating all blank-name txns together)
      if (!name) return 0;
      return this.getInventoryByCategory(siteId, category)
        .filter(t => (t.itemName || '').trim().toLowerCase() === name)
        .reduce((sum, t) => sum + signedQuantity(t), 0);
    },

    /**
     * getLowStockItems — Every distinct (category, itemName) pair at
     * a site whose current stock balance is at or below its threshold.
     * @param {string} siteId
     * @param {{feed?:number, medicine?:number, fuel?:number}} [thresholds]
     *        Optional per-category overrides; falls back to sensible defaults.
     * @returns {Array<{category:string, itemName:string, stock:number, threshold:number, unit:string}>}
     */
    getLowStockItems(siteId, thresholds) {
      const customThresholds = loadJSON('al_inventory_thresholds', {});
      // H5 fix: aligned with InventoryManager.DEFAULT_LOW_STOCK_THRESHOLDS (was feed:100/medicine:10/fuel:50)
      const categoryDefaults = { feed: 50, medicine: 5, fuel: 20 };
      const callerOverrides = thresholds || {}; // H5 fix: honor the thresholds parameter (was previously ignored)
      const txs = this.getInventoryTransactions(siteId);
      const seen = new Map(); // key: category::itemName -> unit
      txs.forEach(tx => {
        const key = tx.category + '::' + (tx.itemName || '').trim().toLowerCase();
        if (!seen.has(key)) seen.set(key, { category: tx.category, itemName: tx.itemName, unit: tx.unit });
      });
      const results = [];
      seen.forEach(({ category, itemName, unit }) => {
        const stock = this.getStockBalance(siteId, category, itemName);
        const customKey = `${siteId}::${category}::${itemName.trim().toLowerCase()}`;
        // H5 fix: priority — per-item custom > caller's per-category override > built-in default
        const threshold = customThresholds[customKey] !== undefined
          ? Number(customThresholds[customKey])
          : (callerOverrides[category] !== undefined
            ? Number(callerOverrides[category])
            : (categoryDefaults[category] ?? 0));
        if (stock <= threshold) {
          results.push({ category, itemName, stock, threshold, unit });
        }
      });
      return results;
    },

    getInventoryThresholds() {
      return loadJSON('al_inventory_thresholds', {});
    },

    saveInventoryThresholds(v) {
      safeSet('al_inventory_thresholds', v);
    },

    /* ── Finance: Expenses, Revenue, Market Prices ────────── */

    getFinanceExpenses: () => loadJSON(KEYS.FINANCE_EXPENSES, []),
    saveFinanceExpenses: (v) => safeSet(KEYS.FINANCE_EXPENSES, v),

    getFinanceRevenue: () => loadJSON(KEYS.FINANCE_REVENUE, []),
    saveFinanceRevenue: (v) => safeSet(KEYS.FINANCE_REVENUE, v),

    getMarketPrices: () => loadJSON(KEYS.FINANCE_PRICES, []),
    saveMarketPrices: (v) => safeSet(KEYS.FINANCE_PRICES, v),

    addFinanceExpense(expense) {
      const all = loadJSON(KEYS.FINANCE_EXPENSES, []);
      all.push(expense);
      safeSet(KEYS.FINANCE_EXPENSES, all);
      return expense;
    },

    deleteFinanceExpense(id) {
      const all = loadJSON(KEYS.FINANCE_EXPENSES, []);
      const next = all.filter(e => e.id !== id);
      if (next.length !== all.length) safeSet(KEYS.FINANCE_EXPENSES, next);
      return next.length !== all.length;
    },

    addFinanceRevenue(rev) {
      const all = loadJSON(KEYS.FINANCE_REVENUE, []);
      all.push(rev);
      safeSet(KEYS.FINANCE_REVENUE, all);
      return rev;
    },

    deleteFinanceRevenue(id) {
      const all = loadJSON(KEYS.FINANCE_REVENUE, []);
      const next = all.filter(e => e.id !== id);
      if (next.length !== all.length) safeSet(KEYS.FINANCE_REVENUE, next);
      return next.length !== all.length;
    },

    addMarketPrice(price) {
      const all = loadJSON(KEYS.FINANCE_PRICES, []);
      all.push(price);
      safeSet(KEYS.FINANCE_PRICES, all);
      return price;
    },

    deleteMarketPrice(id) {
      const all = loadJSON(KEYS.FINANCE_PRICES, []);
      const next = all.filter(e => e.id !== id);
      if (next.length !== all.length) safeSet(KEYS.FINANCE_PRICES, next);
      return next.length !== all.length;
    },
  };

  /**
   * signedQuantity — Direction-aware quantity for stock summation.
   * Stock-adding types return +quantity, stock-removing types return
   * -quantity. 'manual_adjustment' is stored pre-signed (an operator
   * can enter a negative correction) and is passed through as-is.
   */
  function signedQuantity(t) {
    const q = Number(t.quantity) || 0;
    switch (t.type) {
      case 'purchase':
      case 'transfer_in':
        return Math.abs(q);
      case 'consumption':
      case 'transfer_out':
      case 'expired':
      case 'damaged':
        return -Math.abs(q);
      case 'manual_adjustment':
        return q;
      default:
        return 0;
    }
  }

window.AppStorage = AppStorage;
})();

/* ───────────────────────────────────────────────────────────
   safeChart — defensive Chart.js factory (Task 3-c)

   Chart.js 4 keeps an internal registry of every canvas→Chart
   instance. If `new Chart(canvas, cfg)` is called twice on the
   same canvas without destroying the first instance, Chart.js
   leaks the previous instance (and warns "Canvas is already in
   use"). This helper queries that registry via `Chart.getChart`
   and destroys any pre-existing instance on the canvas before
   creating a fresh one. Use this instead of `new Chart(...)` for
   any chart that may be re-created on the same canvas during
   page navigation, React re-mounts, or demo-data reloads.
   ─────────────────────────────────────────────────────────── */
function safeChart(canvas, config) {
  if (!canvas) return null;
  const C = (typeof window.Chart !== 'undefined') ? window.Chart : null;
  if (C && typeof C.getChart === 'function') {
    let existing = null;
    try { existing = C.getChart(canvas); } catch (e) { /* ignore */ }
    if (existing) { try { existing.destroy(); } catch (e) { /* ignore */ } }
  }
  if (!C) {
    console.warn('[AquaLog] safeChart: Chart.js global not available — chart skipped.');
    return null;
  }
  return new C(canvas, config);
}
window.safeChart = safeChart;

// --- Service: utils.js ---
(function() {
  'use strict';
/* ════════════════════════════════════════════════════════
   AquaLog — utils.js
   Centralised pure helper and formatter functions.

   Responsibility: Expose non-stateful pure formatting, date/time,
   and validator functions under window.AppUtils namespace.
   ════════════════════════════════════════════════════════ */



  const MS_PER_DAY = 864e5; // milliseconds in one day

  // Escape HTML entities to prevent XSS
  function escapeHTML(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Set date to midnight
  // H2 fix: parse date-only strings as LOCAL (not UTC) to avoid off-by-one
  // in negative-offset timezones. new Date('2024-01-15') parses as UTC midnight.
  function startOfDay(date = new Date()) {
    const d = (typeof date === 'string' && date.length === 10)
      ? new Date(date + 'T00:00:00')
      : new Date(date);
    d.setHours(0, 0, 0, 0);
    return d;
  }

  // Format date as YYYY-MM-DD
  function fmt(d) {
    // 3-f fix: guard against Invalid Date / null / undefined inputs.
    // new Date(undefined) → Invalid Date, whose getFullYear() returns NaN,
    // producing strings like "NaN-NaN-NaN" that downstream filters and
    // locale-compares silently misbehave on. Fall back to today instead.
    if (!(d instanceof Date) || isNaN(d.getTime())) d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }

  function todayStr() {
    return fmt(new Date());
  }

  function isIsoDateStr(value) {
    return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
  }

  function isFutureDateStr(value) {
    return isIsoDateStr(value) && value > todayStr();
  }

  function isBeforeDateStr(value, minValue) {
    return isIsoDateStr(value) && isIsoDateStr(minValue) && value < minValue;
  }

  function numberFromField(value) {
    const text = String(value ?? '').trim();
    if (text === '') return null;
    const n = Number(text);
    return Number.isFinite(n) ? n : null;
  }

  function isPositiveNumberField(value) {
    const n = numberFromField(value);
    return n !== null && n > 0;
  }

  function isNonNegativeNumberField(value) {
    const n = numberFromField(value);
    return n !== null && n >= 0;
  }

  // Date formatter (DD/MM/YYYY)
  function fmtDateDisplay(dateStr) {
    if (!dateStr) return '—';
    const d = new Date(dateStr.length === 10 ? dateStr + 'T00:00:00' : dateStr);
    if (isNaN(d)) return dateStr;
    const dd   = String(d.getDate()).padStart(2, '0');
    const mm   = String(d.getMonth() + 1).padStart(2, '0');
    const yyyy = d.getFullYear();
    return `${dd}/${mm}/${yyyy}`;
  }

  function fmtShrimpCount(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(2) + 'M';
    if (n >= 1000)    return (n / 1000).toFixed(1) + 'k';
    return n.toLocaleString();
  }

  // ABW formatting in grams
  function fmtWeightG(g) {
    if (g === null || g === undefined || isNaN(g)) return '—';
    if (g >= 100) return g.toFixed(0) + 'g';
    if (g >= 10)  return g.toFixed(1) + 'g';
    if (g >= 1)   return g.toFixed(2) + 'g';
    return g.toFixed(3) + 'g';
  }

  // Localised grams formatting
  function fmtGrams(g) {
    if (g === null || g === undefined || isNaN(g)) return '0';

    function localise(n) {
      n = Math.round(n * 100) / 100;
      return n.toLocaleString('en-US');
    }

    if (g >= 1000000) return localise(+(g / 1000000).toFixed(1)) + 'M';
    if (g >= 1000)    return localise(+(g / 1000).toFixed(1)) + 'k';
    return localise(Math.round(g));
  }

  function capitalize(s) {
    return s.charAt(0).toUpperCase() + s.slice(1);
  }

  function formatInputDate(dateStr) {
    if (!dateStr) return 'Select Date';
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      return `${parts[2]}-${parts[1]}-${parts[0]}`; // YYYY-MM-DD -> DD-MM-YYYY
    }
    return dateStr;
  }

  function formatTime12(timeStr) {
    if (!timeStr) return 'Select Time';
    if (timeStr.includes('AM') || timeStr.includes('PM')) return timeStr;
    const parts = timeStr.split(':');
    if (parts.length >= 2) {
      let hours = parseInt(parts[0], 10);
      const minutes = parts[1];
      const ampm = hours >= 12 ? 'PM' : 'AM';
      hours = hours % 12;
      hours = hours ? hours : 12;
      return `${hours}:${minutes} ${ampm}`;
    }
    return timeStr;
  }

  function calcDOC(stockingDate) {
    const today = startOfDay();
    const stock = startOfDay(stockingDate);
    const diff = Math.floor((today - stock) / MS_PER_DAY);
    return diff >= 0 ? diff + 1 : 1;
  }

  function getDateForDOC(stockingDateStr, docNumber) {
    // H2 fix: parse date-only strings as LOCAL (not UTC)
    const d = (typeof stockingDateStr === 'string' && stockingDateStr.length === 10)
      ? new Date(stockingDateStr + 'T00:00:00')
      : new Date(stockingDateStr);
    d.setDate(d.getDate() + (docNumber - 1));
    return fmt(d);
  }

  function isInLastNDays(dateStr, n) {
    // H2 fix: parse date-only strings as LOCAL (not UTC)
    const d    = (typeof dateStr === 'string' && dateStr.length === 10)
      ? new Date(dateStr + 'T00:00:00')
      : new Date(dateStr);
    const now  = new Date();
    const diff = (now - d) / MS_PER_DAY;
    return diff >= 0 && diff < n;
  }

  function getWeekRange(offset) {
    const now = new Date();
    const day = now.getDay();
    const diff = (day === 0 ? -6 : 1 - day);
    const start = new Date(now);
    start.setDate(now.getDate() + diff + offset * 7);
    start.setHours(0,0,0,0);
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    end.setHours(23,59,59,999);
    return { start, end };
  }

  function getMonthOffset(offset) {
    const now   = new Date();
    let year    = now.getFullYear();
    let month   = now.getMonth() + offset;
    while (month < 0)  { month += 12; year--; }
    while (month > 11) { month -= 12; year++; }
    return { year, month };
  }

  const AppUtils = {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  };

window.AppUtils = AppUtils;
})();

// --- Service: siteManager.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════
   AquaLog Intelligence — siteManager.js
   Owns the Site entity (Farm/Site location, shared by many ponds).
   Responsibilities:
     - Persist sites in localStorage (SK_SITES)
     - Migrate legacy free-text pond.site strings into real Site records
     - CRUD helpers used by the UI (Settings → Farm Sites, Create Pond modal)
   Exposes: window.SiteManager
   ════════════════════════════════════════════ */


  const SK_SITES = 'al_sites';

  function safeGet(key, fallback) {
    try {
      const v = localStorage.getItem(key);
      return v ? JSON.parse(v) : fallback;
    } catch { return fallback; }
  }
  function safeSet(key, value) {
    try { localStorage.setItem(key, JSON.stringify(value)); return true; }
    catch { return false; }
  }

  function loadSites() {
    return safeGet(SK_SITES, []);
  }
  function saveSites(sites) {
    safeSet(SK_SITES, sites);
  }

  function genId(prefix) {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
  }

  function todayISO() {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }

  /**
   * Creates and persists a new Site.
   * @param {{name:string, address?:string, latitude?:number|null, longitude?:number|null}} data
   * @returns {object} the created Site
   */
  function createSite(data) {
    const sites = loadSites();
    // H16 fix: validate lat/long (was accepting NaN for non-numeric strings)
    const rawLat = data.latitude;
    const rawLng = data.longitude;
    const lat = (rawLat === undefined || rawLat === null || rawLat === '') ? null : Number(rawLat);
    const lng = (rawLng === undefined || rawLng === null || rawLng === '') ? null : Number(rawLng);
    const site = {
      id: genId('site'),
      name: (data.name != null ? String(data.name) : '').trim() || 'Unnamed Site',
      location: {
        address: (data.address || '').trim(),
        latitude: (lat !== null && Number.isFinite(lat) && lat >= -90 && lat <= 90) ? lat : null,
        longitude: (lng !== null && Number.isFinite(lng) && lng >= -180 && lng <= 180) ? lng : null,
      },
      createdDate: todayISO(),
    };
    sites.push(site);
    saveSites(sites);
    return site;
  }

  function updateSite(id, data) {
    const sites = loadSites();
    const site = sites.find(s => s.id === id);
    if (!site) return null;
    let oldName = null;
    let nameChanged = false;
    if (data.name !== undefined) {
      oldName = site.name;
      const newName = data.name.trim();
      if (newName && newName !== oldName) {
        site.name = newName;
        nameChanged = true;
      }
    }
    if (data.address !== undefined) site.location.address = data.address.trim();
    if (data.latitude !== undefined) site.location.latitude = data.latitude === '' ? null : Number(data.latitude);
    if (data.longitude !== undefined) site.location.longitude = data.longitude === '' ? null : Number(data.longitude);
    saveSites(sites);

    // C6 fix: propagate name change to dependent ponds' legacy pond.site field.
    // Ponds store both pond.siteId and pond.site (name string). Without this,
    // renaming a site orphans every pond on it — populateSiteSelect uses the name
    // as the option value, so the stale name produces no match and the edit modal
    // fails validation.
    if (nameChanged && window.AppStorage) {
      try {
        const ponds = window.AppStorage.getPonds();
        let pondsChanged = false;
        ponds.forEach(p => {
          if (p.siteId === id || p.site === oldName) {
            p.site = site.name;
            if (!p.siteId) p.siteId = id;
            pondsChanged = true;
          }
        });
        if (pondsChanged) window.AppStorage.savePonds(ponds);

        // Sync in-memory ponds array (script.js keeps a module-scoped mirror on window)
        if (Array.isArray(window.ponds)) {
          window.ponds.forEach(p => {
            if (p.siteId === id || p.site === oldName) {
              p.site = site.name;
              if (!p.siteId) p.siteId = id;
            }
          });
        }
      } catch (e) {
        console.error('[AquaLog SiteManager] updateSite pond propagation failed (non-fatal):', e);
      }
    }
    return site;
  }

  function deleteSite(id) {
    let sites = loadSites();
    sites = sites.filter(s => s.id !== id);
    saveSites(sites);

    // C8 fix: cascade cleanup so orphaned data doesn't linger for a deleted site
    try {
      // 1. Remove all inventory transactions for this site
      if (window.AppStorage) {
        const allTx = window.AppStorage.getAllInventoryTransactions();
        const remainingTx = allTx.filter(t => t.siteId !== id);
        if (remainingTx.length !== allTx.length) {
          window.AppStorage.saveAllInventoryTransactions(remainingTx);
        }
      }

      // 2. Clear weather cache entry for this site (object keyed by siteId)
      try {
        const cacheRaw = localStorage.getItem('al_weather_cache');
        if (cacheRaw) {
          const cache = JSON.parse(cacheRaw);
          if (cache && typeof cache === 'object' && cache[id]) {
            delete cache[id];
            localStorage.setItem('al_weather_cache', JSON.stringify(cache));
          }
        }
      } catch (_) { /* ignore parse errors */ }

      // 3. Clear weather history entries for this site (array of snapshots with siteId)
      try {
        const histRaw = localStorage.getItem('al_weather_history');
        if (histRaw) {
          const hist = JSON.parse(histRaw);
          if (Array.isArray(hist)) {
            const remainingHist = hist.filter(h => h.siteId !== id);
            if (remainingHist.length !== hist.length) {
              localStorage.setItem('al_weather_history', JSON.stringify(remainingHist));
            }
          }
        }
      } catch (_) { /* ignore parse errors */ }

      // 4. Null out siteId on ponds that referenced this site (storage + in-memory)
      if (window.AppStorage) {
        const ponds = window.AppStorage.getPonds();
        let pondsChanged = false;
        ponds.forEach(p => {
          if (p.siteId === id) {
            p.siteId = null;
            p.site = '';
            pondsChanged = true;
          }
        });
        if (pondsChanged) window.AppStorage.savePonds(ponds);

        // Sync in-memory ponds array (script.js keeps a module-scoped mirror on window)
        if (Array.isArray(window.ponds)) {
          window.ponds.forEach(p => {
            if (p.siteId === id) {
              p.siteId = null;
              p.site = '';
            }
          });
        }
      }
    } catch (e) {
      console.error('[AquaLog SiteManager] deleteSite cascade cleanup failed (non-fatal):', e);
    }
  }

  function getSiteById(id) {
    if (!id) return null;
    return loadSites().find(s => s.id === id) || null;
  }

  function hasLocation(site) {
    return !!(site && site.location && site.location.latitude != null && site.location.longitude != null);
  }

  /**
   * One-time migration: converts legacy pond.site (free-text string) into
   * real Site records, and assigns pond.siteId. Safe to call on every boot —
   * it is a no-op once migration has completed. Never deletes existing data;
   * pond.site string is left in place as a display fallback.
   * @param {Array} ponds - the app's pond array (mutated in place, then caller persists)
   * @returns {{sites:Array, pondsChanged:boolean}}
   */
  function migrate(ponds) {
    let sites = loadSites();
    let pondsChanged = false;

    (ponds || []).forEach(pond => {
      if (pond.siteId) return; // already migrated

      const rawName = (pond.site || '').trim();
      const lookupName = rawName || 'Default Site';

      let site = sites.find(s => s.name.toLowerCase() === lookupName.toLowerCase());
      if (!site) {
        site = {
          id: genId('site'),
          name: lookupName,
          location: { address: '', latitude: null, longitude: null },
          createdDate: todayISO(),
        };
        sites.push(site);
      }
      pond.siteId = site.id;
      if (!rawName) pond.site = lookupName; // keep string in sync for legacy display code
      pondsChanged = true;
    });

    saveSites(sites);
    return { sites, pondsChanged };
  }

  const SiteManager = {
    loadSites,
    saveSites,
    createSite,
    updateSite,
    deleteSite,
    getSiteById,
    hasLocation,
    migrate,
  };
window.SiteManager = SiteManager;
})();

// --- Service: inventoryManager.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════════════════
   AquaLog — inventoryManager.js
   Owns the Inventory Transaction entity (Farm → Site → Inventory).

   Responsibilities:
     - Define the transaction data model (types, categories, per-
       category detail schemas) and enforce it via validation.
     - Business-logic layer on top of AppStorage's raw inventory
       CRUD (storage.js is the only file that touches localStorage
       directly — this file always goes through window.AppStorage).
     - Current stock is NEVER stored; it is always derived by
       summing transactions (see AppStorage.getStockBalance).
     - Hook into the existing feed-log lifecycle (create / edit /
       delete in script.js) so every feed entry automatically keeps
       a matching 'consumption' inventory transaction in sync,
       including a one-time retroactive backfill for historical
       feed entries logged before this module existed.
     - One-time defensive migration of any pre-existing ad-hoc
       inventory data into the new transaction structure, without
       touching feed logs, sites, ponds, batches, weather data, or
       settings.

   Exposes: window.InventoryManager
   Depends on: window.AppStorage (storage.js), loaded first.
   ════════════════════════════════════════════════════════ */


  /* ── Enumerations ───────────────────────────────────────── */

  const TRANSACTION_TYPES = Object.freeze([
    'purchase', 'consumption', 'manual_adjustment',
    'transfer_in', 'transfer_out', 'expired', 'damaged',
  ]);

  const CATEGORIES = Object.freeze(['feed', 'medicine', 'fuel']);

  const MEDICINE_CATEGORIES = Object.freeze([
    'Probiotics', 'Minerals', 'Lime', 'Salt', 'Molasses',
    'Zeolite', 'Chlorine', 'Bleaching Powder', 'Vitamins', 'Water Treatment',
  ]);

  const MEDICINE_UNITS = Object.freeze(['Bottle', 'Packet', 'Kg', 'Liter', 'Bag']);

  const FUEL_TYPES = Object.freeze(['Diesel', 'Petrol', 'Engine Oil']);

  /* Default low-stock thresholds per category, used when a caller
     doesn't supply its own (kept in sync with AppStorage.getLowStockItems). */
  const DEFAULT_LOW_STOCK_THRESHOLDS = Object.freeze({ feed: 50, medicine: 5, fuel: 20 });

  /* Types that require a positive (non-zero, non-negative) quantity.
     'manual_adjustment' is the only type allowed a negative quantity
     (an operator correcting stock downward), but still may not be zero. */
  const POSITIVE_ONLY_TYPES = TRANSACTION_TYPES.filter(t => t !== 'manual_adjustment');

  /* ── Id / timestamp helpers ─────────────────────────────── */

  function genId(prefix) {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
  }

  function nowISO() {
    return new Date().toISOString();
  }

  function toNumber(v) {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  /* ── Category-specific detail normalisation ─────────────── */

  /**
   * normaliseFeedDetails — Builds the `details` blob for a feed
   * transaction and auto-calculates totalWeight = bagWeight × numberOfBags.
   * Stock for feed is always tracked/displayed in kg, never bags.
   * @param {object} details {feedBrand, feedSize, bagWeight, numberOfBags}
   * @returns {{details:object, totalWeightKg:number}}
   */
  function normaliseFeedDetails(details) {
    const d = details || {};
    const bagWeight    = toNumber(d.bagWeight);
    const numberOfBags = toNumber(d.numberOfBags);
    const totalWeightKg = +(bagWeight * numberOfBags).toFixed(3);
    return {
      details: {
        feedBrand   : (d.feedBrand || '').trim(),
        feedSize    : (d.feedSize || '').trim(),
        bagWeight,
        numberOfBags,
        totalWeight : totalWeightKg,
      },
      totalWeightKg,
    };
  }

  /**
   * normaliseMedicineDetails — Builds the `details` blob for a
   * medicine/consumable transaction.
   * @param {object} details {itemName, category, unit, expiryDate}
   */
  function normaliseMedicineDetails(details) {
    const d = details || {};
    return {
      itemName  : (d.itemName || '').trim(),
      category  : d.category || '',
      unit      : d.unit || '',
      expiryDate: d.expiryDate || null,
    };
  }

  /**
   * normaliseFuelDetails — Builds the `details` blob for a fuel
   * transaction and auto-calculates totalCost when not supplied.
   * @param {object} details {fuelType, quantity, pricePerLiter}
   */
  function normaliseFuelDetails(details) {
    const d = details || {};
    const quantity      = toNumber(d.quantity);
    const pricePerLiter = toNumber(d.pricePerLiter);
    return {
      details: {
        fuelType: d.fuelType || '',
        quantity,
        pricePerLiter,
      },
      quantity,
      // H12 fix: only compute totalCost when details.quantity is present.
      // When it's missing (e.g. caller passes top-level quantity but no details.quantity,
      // as migrateLegacyInventoryData does), return null so buildTransaction's fallback
      // (resolved_quantity * unitPrice) fires instead of silently storing 0.
      totalCost: (quantity !== null && quantity > 0 && pricePerLiter !== null && pricePerLiter > 0)
        ? +(quantity * pricePerLiter).toFixed(2)
        : null,
    };
  }

  /* ── Helper Functions for stock verification ── */
  function getSignedQty(t) {
    const q = Number(t.quantity) || 0;
    switch (t.type) {
      case 'purchase':
      case 'transfer_in':
        return Math.abs(q);
      case 'consumption':
      case 'transfer_out':
      case 'expired':
      case 'damaged':
        return -Math.abs(q);
      case 'manual_adjustment':
        return q;
      default:
        return 0;
    }
  }

  function getAvailableStock(siteId, category, itemName, excludeTxId) {
    if (!window.AppStorage) return 0;
    const name = (itemName || '').trim().toLowerCase();
    const txs = window.AppStorage.getInventoryByCategory(siteId, category) || [];
    return txs
      .filter(t => (t.itemName || '').trim().toLowerCase() === name && t.id !== excludeTxId)
      .reduce((sum, t) => sum + getSignedQty(t), 0);
  }

  function getAvailableStockByRef(siteId, category, itemName, excludeRefId) {
    if (!window.AppStorage) return 0;
    const name = (itemName || '').trim().toLowerCase();
    const txs = window.AppStorage.getInventoryByCategory(siteId, category) || [];
    return txs
      .filter(t => (t.itemName || '').trim().toLowerCase() === name && t.referenceNumber !== excludeRefId)
      .reduce((sum, t) => sum + getSignedQty(t), 0);
  }

  function checkFeedLogStockSufficiency(record, excludeRecordId = null) {
    if (!record) return { ok: true };
    const pond = window.AppStorage.getPonds().find(p => p.id === record.PondId);
    const siteId = pond ? pond.siteId : null;
    if (!siteId) return { ok: true };

    const recordId = excludeRecordId || record.id;

    // H11 fix: accumulate per-itemName demand so multiple slots pulling the same
    // item are checked against the JOINT total, not independently.
    const demanded = {}; // itemName -> kg already demanded in this loop

    for (let i = 1; i <= 5; i++) {
      const grams = Number(record[`Feed Size ${i} Gram`]) || 0;
      if (grams > 0) {
        const kgNeeded = grams / 1000;
        const itemName = `Feed Size ${i}`;
        const alreadyDemanded = demanded[itemName] || 0;
        const available = getAvailableStockByRef(siteId, 'feed', itemName, recordId);
        if (kgNeeded + alreadyDemanded > available) {
          return {
            ok: false,
            message: `Insufficient inventory for ${itemName}. Available: ${available.toFixed(1)} kg. Requested: ${(kgNeeded + alreadyDemanded).toFixed(1)} kg.`
          };
        }
        demanded[itemName] = alreadyDemanded + kgNeeded;
      }
    }

    const otherGrams = Number(record['Other Feed Gram']) || 0;
    if (otherGrams > 0) {
      const otherName = (record['Other Feed Name'] || '').trim() || 'Other Feed';
      const kgNeeded = otherGrams / 1000;
      const alreadyDemanded = demanded[otherName] || 0;
      const available = getAvailableStockByRef(siteId, 'feed', otherName, recordId);
      if (kgNeeded + alreadyDemanded > available) {
        return {
          ok: false,
          message: `Insufficient inventory for ${otherName}. Available: ${available.toFixed(1)} kg. Requested: ${(kgNeeded + alreadyDemanded).toFixed(1)} kg.`
        };
      }
      demanded[otherName] = alreadyDemanded + kgNeeded;
    }

    return { ok: true };
  }

  /* ── Validation ──────────────────────────────────────────── */

  /**
   * validateTransaction — Pure validation of a transaction payload
   * before it is persisted. Enforces: no negative quantities, no
   * negative prices, no zero quantities, no empty supplier on
   * purchases, valid type/category, and a siteId.
   * @param {object} data
   * @returns {{valid:boolean, errors:string[]}}
   */
  function validateTransaction(data) {
    const errors = [];
    const d = data || {};

    if (!d.siteId) errors.push('siteId is required — inventory is always site-scoped.');
    if (!TRANSACTION_TYPES.includes(d.type)) errors.push(`type must be one of: ${TRANSACTION_TYPES.join(', ')}`);
    if (!CATEGORIES.includes(d.category)) errors.push(`category must be one of: ${CATEGORIES.join(', ')}`);
    if (!d.itemName || !String(d.itemName).trim()) errors.push('itemName is required.');
    if (!d.purchaseDate) errors.push('purchaseDate is required.');

    const qty = Number(d.quantity);
    if (!Number.isFinite(qty) || qty === 0) {
      errors.push('quantity is required and cannot be zero.');
    } else if (POSITIVE_ONLY_TYPES.includes(d.type) && qty < 0) {
      errors.push(`quantity cannot be negative for type "${d.type}".`);
    }

    if (d.unitPrice !== undefined && d.unitPrice !== null && d.unitPrice !== '') {
      const price = Number(d.unitPrice);
      if (!Number.isFinite(price) || price < 0) errors.push('unitPrice cannot be negative.');
    }

    if (d.type === 'purchase' && !(d.supplier && String(d.supplier).trim())) {
      errors.push('supplier is required for purchase transactions.');
    }

    // --- FIX 7: Mandatory Reason Validation ---
    const notesStr = (d.notes || '').trim();
    if (['damaged', 'expired', 'manual_adjustment', 'transfer_in', 'transfer_out'].includes(d.type)) {
      if (!notesStr) {
        errors.push('Reason/Notes is required.');
      } else if (notesStr.length < 5) {
        errors.push('Reason must be at least 5 characters.');
      } else if (notesStr.length > 300) {
        errors.push('Reason cannot exceed 300 characters.');
      }
    }

    // --- FIX 4: Transfer Validation ---
    if (d.type === 'transfer_out' || d.type === 'transfer_in') {
      const source = d.details?.sourceSiteId || d.details?.sourceSite;
      const dest = d.details?.destSiteId || d.details?.destSite;
      if (!source) errors.push('Source site is required for transfers.');
      if (!dest) errors.push('Destination site is required for transfers.');
      if (source && dest && source === dest) errors.push('Source and destination sites cannot be the same.');
      
      const transferQty = Number(d.quantity);
      if (isNaN(transferQty) || transferQty <= 0) {
        errors.push('Transfer quantity must be greater than zero.');
      }
    }

    // --- FIX 1: Prevent Negative Stock ---
    const change = getSignedQty(d);
    if (change < 0) {
      const currentStock = getAvailableStock(d.siteId, d.category, d.itemName, d.id);
      if (currentStock + change < 0) {
        errors.push(`Insufficient inventory. Available: ${currentStock.toFixed(1)} ${d.unit || 'units'}. Requested: ${Math.abs(change).toFixed(1)} ${d.unit || 'units'}.`);
      }
    }

    return { valid: errors.length === 0, errors };
  }

  /* ── Transaction builder ─────────────────────────────────── */

  /**
   * buildTransaction — Normalises a raw payload into a full
   * transaction record ready for storage: fills id/timestamps,
   * computes category-specific details (e.g. feed totalWeight),
   * and derives totalCost when not explicitly supplied.
   * Does NOT persist — call createTransaction() for that.
   * @param {object} data
   * @returns {object} full transaction record
   */
  function buildTransaction(data) {
    const d = Object.assign({}, data);
    let quantity  = d.quantity !== undefined ? toNumber(d.quantity) : 0;
    let unit      = d.unit || '';
    let details   = d.details || {};
    let totalCost = d.totalCost !== undefined && d.totalCost !== null && d.totalCost !== ''
      ? toNumber(d.totalCost)
      : null;

    if (d.category === 'feed') {
      const fed = normaliseFeedDetails(details);
      details = fed.details;
      // Only auto-derive quantity/unit from bag math when the caller
      // didn't already supply an explicit quantity (e.g. consumption
      // transactions pass quantity in kg directly, with no bag data).
      if (d.quantity === undefined || d.quantity === null || d.quantity === '') {
        quantity = fed.totalWeightKg;
      }
      unit = unit || 'kg';
    } else if (d.category === 'medicine') {
      details = normaliseMedicineDetails(details);
      unit = unit || details.unit || '';
    } else if (d.category === 'fuel') {
      const fud = normaliseFuelDetails(details);
      details = fud.details;
      if (d.quantity === undefined || d.quantity === null || d.quantity === '') {
        quantity = fud.quantity;
      }
      unit = unit || 'Liter';
      if (totalCost === null) totalCost = fud.totalCost;
    }

    let unitPrice = d.unitPrice !== undefined && d.unitPrice !== null && d.unitPrice !== ''
      ? toNumber(d.unitPrice) : 0;
    // Fuel's price-per-litre IS its unit price — fall back to it so
    // validation (no negative prices) covers the fuel-specific field too.
    if (d.category === 'fuel' && (d.unitPrice === undefined || d.unitPrice === null || d.unitPrice === '')) {
      unitPrice = toNumber((d.details || {}).pricePerLiter);
    }
    if (totalCost === null) totalCost = +(Math.abs(quantity) * unitPrice).toFixed(2);

    const timestamp = nowISO();
    return {
      id             : d.id || genId('inv'),
      siteId         : d.siteId,
      type           : d.type,
      category       : d.category,
      itemName       : String(d.itemName || '').trim(),
      purchaseDate   : d.purchaseDate,
      supplier       : (d.supplier || '').trim(),
      quantity,
      unit,
      unitPrice,
      totalCost,
      referenceNumber: d.referenceNumber || '',
      notes          : d.notes || '',
      details,
      createdAt      : d.createdAt || timestamp,
      updatedAt      : timestamp,
    };
  }

  /* ── Public CRUD (validated, normalised) ────────────────── */

  /**
   * createTransaction — Validates and persists a new inventory
   * transaction. This is the entry point every future UI (Feed
   * Purchase form, Medicine Log, Fuel Usage) should call.
   * @param {object} data - raw payload (see module header for schema)
   * @returns {{success:boolean, transaction:object|null, errors:string[]}}
   */
  function createTransaction(data) {
    const built = buildTransaction(data);
    const { valid, errors } = validateTransaction(built);
    if (!valid) return { success: false, transaction: null, errors };
    // C13 fix: check persistence result — surface failure instead of silently reporting success
    const persisted = window.AppStorage.addInventoryTransaction(built);
    if (!persisted) {
      return { success: false, transaction: null, errors: ['Storage write failed — device may be out of space.'] };
    }
    return { success: true, transaction: built, errors: [] };
  }

  /**
   * updateTransaction — Validates and applies a partial update to
   * an existing transaction, recalculating derived fields (totalCost,
   * feed totalWeight) if the relevant inputs changed.
   * @param {string} id
   * @param {object} data - partial fields to change
   * @returns {{success:boolean, transaction:object|null, errors:string[]}}
   */
  function updateTransaction(id, data) {
    const existing = window.AppStorage.getAllInventoryTransactions().find(t => t.id === id);
    if (!existing) return { success: false, transaction: null, errors: ['Transaction not found.'] };

    const merged = Object.assign({}, existing, data, {
      details: Object.assign({}, existing.details, data.details || {}),
    });
    const rebuilt = buildTransaction(Object.assign({}, merged, { id, createdAt: existing.createdAt }));
    const { valid, errors } = validateTransaction(rebuilt);
    if (!valid) return { success: false, transaction: null, errors };

    const saved = window.AppStorage.updateInventoryTransaction(id, rebuilt);
    return { success: true, transaction: saved, errors: [] };
  }

  /**
   * deleteTransaction — Removes a transaction by id.
   * @param {string} id
   * @returns {boolean}
   */
  function deleteTransaction(id) {
    return window.AppStorage.deleteInventoryTransaction(id);
  }

  /* ── Query / analytics helpers ──────────────────────────── */

  /**
   * calculateStock — Current on-hand stock for one item at a site,
   * derived entirely from transaction history (never a stored field).
   * @param {string} siteId
   * @param {string} category
   * @param {string} itemName
   * @returns {number}
   */
  function calculateStock(siteId, category, itemName) {
    return window.AppStorage.getStockBalance(siteId, category, itemName);
  }

  /**
   * isLowStock — Whether an item's current stock is at or below a
   * threshold (explicit threshold, else the category default).
   * @param {string} siteId
   * @param {string} category
   * @param {string} itemName
   * @param {number} [threshold]
   * @returns {boolean}
   */
  function isLowStock(siteId, category, itemName, threshold) {
    const t = threshold !== undefined && threshold !== null
      ? Number(threshold)
      : DEFAULT_LOW_STOCK_THRESHOLDS[category] ?? 0;
    return calculateStock(siteId, category, itemName) <= t;
  }

  /**
   * getLowStockItems — See AppStorage.getLowStockItems (thin re-export
   * kept here so callers only need to know about InventoryManager).
   * @param {string} siteId
   * @param {object} [thresholds]
   */
  function getLowStockItems(siteId, thresholds) {
    return window.AppStorage.getLowStockItems(siteId, thresholds);
  }

  function isInMonth(dateStr, month) {
    return typeof dateStr === 'string' && dateStr.slice(0, 7) === month;
  }

  /**
   * getMonthlyPurchase — Total quantity and cost purchased for a
   * category at a site within a given month. Reads purchase-type
   * transactions directly, ready for a future Finance module.
   * @param {string} siteId
   * @param {string} category
   * @param {string} month - 'YYYY-MM'
   * @returns {{quantity:number, cost:number}}
   */
  function getMonthlyPurchase(siteId, category, month) {
    const txs = window.AppStorage.getInventoryByCategory(siteId, category)
      .filter(t => t.type === 'purchase' && isInMonth(t.purchaseDate, month));
    return {
      quantity: +txs.reduce((s, t) => s + Math.abs(toNumber(t.quantity)), 0).toFixed(3),
      cost    : +txs.reduce((s, t) => s + toNumber(t.totalCost), 0).toFixed(2),
    };
  }

  /**
   * getMonthlyConsumption — Total quantity consumed for a category
   * at a site within a given month.
   * @param {string} siteId
   * @param {string} category
   * @param {string} month - 'YYYY-MM'
   * @returns {{quantity:number, cost:number}}
   */
  function getMonthlyConsumption(siteId, category, month) {
    const txs = window.AppStorage.getInventoryByCategory(siteId, category)
      .filter(t => t.type === 'consumption' && isInMonth(t.purchaseDate, month));
    return {
      quantity: +txs.reduce((s, t) => s + Math.abs(toNumber(t.quantity)), 0).toFixed(3),
      cost    : +txs.reduce((s, t) => s + toNumber(t.totalCost), 0).toFixed(2),
    };
  }

  /* ── Feed-log integration ────────────────────────────────
     Every feed log entry (script.js records array) automatically
     drives a matching set of 'consumption' inventory transactions —
     one per non-zero feed slot — so feed stock always reflects
     what's actually been fed. Transactions are linked back to their
     record via referenceNumber === record.id, which makes the sync
     idempotent: re-running it for the same record simply replaces
     its transactions, which is exactly what an edit needs and is a
     safe no-op for an unmodified record processed twice. ─────── */

  const FEED_SLOT_FIELDS = Object.freeze([
    { field: 'Feed Size 1 Gram', label: 'Feed Size 1' },
    { field: 'Feed Size 2 Gram', label: 'Feed Size 2' },
    { field: 'Feed Size 3 Gram', label: 'Feed Size 3' },
    { field: 'Feed Size 4 Gram', label: 'Feed Size 4' },
    { field: 'Feed Size 5 Gram', label: 'Feed Size 5' },
  ]);

  /**
   * resolveSiteIdForPond — Looks up the site a pond belongs to,
   * straight from AppStorage so this module never depends on
   * script.js's in-memory state.
   * @param {string} pondId
   * @returns {string|null}
   */
  function resolveSiteIdForPond(pondId) {
    const pond = window.AppStorage.getPonds().find(p => p.id === pondId);
    return (pond && pond.siteId) || null;
  }

  /**
   * deleteFeedConsumptionForRecord — Removes every consumption
   * transaction linked to a given feed-log record (by record.id).
   * Called on feed-log delete, and internally before re-creating
   * transactions on feed-log edit.
   * @param {object} record - a feed log record (must have .id)
   * @returns {boolean} true if anything was removed
   */
  function deleteFeedConsumptionForRecord(record) {
    if (!record || !record.id) return false;
    const all = window.AppStorage.getAllInventoryTransactions();
    const next = all.filter(t => !(t.category === 'feed' && t.type === 'consumption' && t.referenceNumber === record.id));
    const changed = next.length !== all.length;
    if (changed) window.AppStorage.saveAllInventoryTransactions(next);
    return changed;
  }

  /**
   * syncFeedConsumption — Creates (or, for an edit, recreates) the
   * 'consumption' inventory transactions for a single feed-log
   * record. Call this after a feed entry is logged AND after it is
   * edited — it always clears any previously-linked transactions
   * first, so it is safe to call repeatedly for the same record.
   * @param {object} record - a feed log record; record.id links transactions to it.
   *   If record.id is missing one is generated, but the caller is
   *   responsible for persisting the mutated record (records array)
   *   back via AppStorage.saveRecords — the create/edit hooks in
   *   script.js already do this as part of their own save.
   * @returns {Array<object>} the created consumption transactions
   */
  function syncFeedConsumption(record) {
    if (!record) return [];
    if (!record.id) record.id = genId('rec');

    // Always clear old links first — makes this safe for both a
    // brand-new record (no-op) and an edited one (removes stale txs).
    deleteFeedConsumptionForRecord(record);

    const siteId = resolveSiteIdForPond(record.PondId);
    if (!siteId) return []; // pond has no site yet — nothing to post against

    const created = [];
    const failed = []; // H10 fix: track failed consumption transactions

    FEED_SLOT_FIELDS.forEach(({ field, label }) => {
      const grams = toNumber(record[field]);
      if (grams > 0) {
        const result = createTransaction({
          siteId,
          type        : 'consumption',
          category    : 'feed',
          itemName    : label,
          purchaseDate: record.Date,
          supplier    : '',
          quantity    : +(grams / 1000).toFixed(3), // grams -> kg
          unit        : 'kg',
          unitPrice   : 0,
          referenceNumber: record.id,
          notes       : 'Auto-generated from feed log entry',
          details     : { source: 'feed_log', pondId: record.PondId, batchId: record.BatchId || null },
        });
        // H10 fix: surface failures instead of silently dropping them
        if (result.success) created.push(result.transaction);
        else failed.push({ label, grams, errors: result.errors });
      }
    });

    const otherGrams = toNumber(record['Other Feed Gram']);
    if (otherGrams > 0) {
      const otherName = (record['Other Feed Name'] || '').trim() || 'Other Feed';
      const result = createTransaction({
        siteId,
        type        : 'consumption',
        category    : 'feed',
        itemName    : otherName,
        purchaseDate: record.Date,
        supplier    : '',
        quantity    : +(otherGrams / 1000).toFixed(3),
        unit        : 'kg',
        unitPrice   : 0,
        referenceNumber: record.id,
        notes       : 'Auto-generated from feed log entry',
        details     : { source: 'feed_log', pondId: record.PondId, batchId: record.BatchId || null },
      });
      // H10 fix: surface failures instead of silently dropping them
      if (result.success) created.push(result.transaction);
      else failed.push({ label: otherName, grams: otherGrams, errors: result.errors });
    }

    // H10 fix: warn about any slots that couldn't be synced
    if (failed.length > 0) {
      console.warn('[AquaLog Inventory] syncFeedConsumption: ' + failed.length + ' slot(s) could not be synced:', failed);
    }

    return created;
  }

  /**
   * backfillHistoricalFeedConsumption — One-time (idempotent, safe
   * to call on every boot) pass over every existing feed-log record
   * that has no linked consumption transactions yet, and creates
   * them retroactively. Assigns a stable id to any legacy record
   * that predates this module and persists that back via
   * AppStorage.saveRecords — nothing else about the record changes.
   * Never touches records that already have linked transactions, so
   * it will not fight with edits made through the normal hooks.
   */
  function backfillHistoricalFeedConsumption(limitDays) {
    const records = window.AppStorage.getRecords();
    if (!records.length) return;

    // Q5 fix: optional limitDays parameter — only process records from the last N days.
    // Used by the demo data loader to avoid generating 30K+ transactions that overflow localStorage.
    const cutoffDate = limitDays ? fmt(new Date(Date.now() - limitDays * MS_PER_DAY)) : null;

    // Assign stable IDs to any legacy records that predate this module
    let idsAssigned = false;
    records.forEach(r => {
      if (!r.id) { r.id = genId('rec'); idsAssigned = true; }
    });
    if (idsAssigned) window.AppStorage.saveRecords(records);

    // Build a set of already-linked record IDs (one read only)
    const allTx = window.AppStorage.getAllInventoryTransactions();
    const linked = new Set(
      allTx
        .filter(t => t.category === 'feed' && t.type === 'consumption' && t.referenceNumber)
        .map(t => t.referenceNumber)
    );

    // Collect every new consumption transaction in memory — zero per-record I/O
    const toAdd = [];

    records.forEach(r => {
      if (linked.has(r.id)) return; // already backfilled
      // Q5 fix: skip records older than cutoffDate when limitDays is set
      if (cutoffDate && r.Date < cutoffDate) return;

      const siteId = resolveSiteIdForPond(r.PondId);
      if (!siteId) return;

      if (!r.id) r.id = genId('rec');

      FEED_SLOT_FIELDS.forEach(({ field, label }) => {
        const grams = toNumber(r[field]);
        if (grams <= 0) return;
        const built = buildTransaction({
          siteId,
          type        : 'consumption',
          category    : 'feed',
          itemName    : label,
          purchaseDate: r.Date,
          supplier    : '',
          quantity    : +(grams / 1000).toFixed(3),
          unit        : 'kg',
          unitPrice   : 0,
          referenceNumber: r.id,
          notes       : 'Auto-generated from feed log entry',
          details     : { source: 'feed_log', pondId: r.PondId, batchId: r.BatchId || null },
        });
        toAdd.push(built);
      });

      const otherGrams = toNumber(r['Other Feed Gram']);
      if (otherGrams > 0) {
        const otherName = (r['Other Feed Name'] || '').trim() || 'Other Feed';
        const built = buildTransaction({
          siteId,
          type        : 'consumption',
          category    : 'feed',
          itemName    : otherName,
          purchaseDate: r.Date,
          supplier    : '',
          quantity    : +(otherGrams / 1000).toFixed(3),
          unit        : 'kg',
          unitPrice   : 0,
          referenceNumber: r.id,
          notes       : 'Auto-generated from feed log entry',
          details     : { source: 'feed_log', pondId: r.PondId, batchId: r.BatchId || null },
        });
        toAdd.push(built);
      }
    });

    // Chunked bulk write — prevents quota-exceeded when backfilling thousands of records.
    // Each chunk writes 500 transactions; stops early if a write fails (quota exceeded).
    if (toAdd.length) {
      const CHUNK_SIZE = 500;
      let written = 0;
      let failed = false;
      for (let i = 0; i < toAdd.length && !failed; i += CHUNK_SIZE) {
        const chunk = toAdd.slice(i, i + CHUNK_SIZE);
        const result = window.AppStorage.bulkAddInventoryTransactions(chunk);
        if (result === 0) {
          // C13 fix: bulkAdd returns 0 on write failure (quota exceeded)
          console.warn(`[AquaLog Inventory] Backfill stopped at ${written}/${toAdd.length} — localStorage quota exceeded. Remaining ${toAdd.length - written} transactions not written.`);
          failed = true;
        } else {
          written += chunk.length;
        }
      }
      console.info(`[AquaLog Inventory] Backfilled ${written}/${toAdd.length} feed consumption transactions${failed ? ' (partial — quota exceeded)' : ''}.`);
    }
  }


  /* ── Legacy data migration ───────────────────────────────
     Defensive, best-effort: this app never previously shipped an
     inventory feature, so under normal circumstances there is
     nothing to migrate and this is a no-op. It exists so that if an
     earlier ad-hoc/experimental inventory key is present on a
     user's device, it gets folded into the new al_inventory
     structure instead of silently ignored or colliding with it.
     Only ever ADDs data — never deletes or rewrites unrelated keys
     (feed logs, sites, ponds, batches, weather data, settings). ── */

  const LEGACY_KEYS = Object.freeze(['inventory', 'al_stock', 'feedInventory', 'medicineInventory', 'fuelInventory']);
  const MIGRATION_FLAG_KEY = 'al_inventory_migrated_v1';

  function looksLikeLegacyInventoryItem(item) {
    return item && typeof item === 'object' &&
      (item.itemName || item.name) &&
      (item.quantity !== undefined || item.qty !== undefined || item.stock !== undefined);
  }

  function migrateLegacyInventoryData() {
    try {
      if (localStorage.getItem(MIGRATION_FLAG_KEY)) return; // already run

      const defaultSiteId = (window.AppStorage.getPonds()[0] || {}).siteId || null;
      let migratedAny = false;

      LEGACY_KEYS.forEach(key => {
        const raw = localStorage.getItem(key);
        if (!raw) return;
        let parsed;
        try { parsed = JSON.parse(raw); } catch { return; }
        if (!Array.isArray(parsed) || !parsed.length || !looksLikeLegacyInventoryItem(parsed[0])) return;

        parsed.forEach(item => {
          if (!looksLikeLegacyInventoryItem(item)) return;
          const siteId = item.siteId || defaultSiteId;
          if (!siteId) return; // no site to attach to — skip rather than guess wrong
          createTransaction({
            siteId,
            type        : 'purchase',
            category    : CATEGORIES.includes(item.category) ? item.category : 'feed',
            itemName    : item.itemName || item.name,
            purchaseDate: item.date || item.purchaseDate || nowISO().slice(0, 10),
            supplier    : item.supplier || 'Unknown (migrated)',
            quantity    : item.quantity ?? item.qty ?? item.stock,
            unit        : item.unit || '',
            unitPrice   : item.unitPrice || 0,
            notes       : 'Migrated from legacy "' + key + '" data.',
          });
          migratedAny = true;
        });
        // M17 fix: delete the legacy key after successful migration so a partial-failure
        // retry doesn't double-count. Was never deleted, causing re-migration if the flag wasn't set.
        try { localStorage.removeItem(key); } catch(_) {}
      });

      if (migratedAny) console.info('[AquaLog Inventory] Migrated legacy inventory data into al_inventory.');
      localStorage.setItem(MIGRATION_FLAG_KEY, 'true');
    } catch (e) {
      console.error('[AquaLog Inventory] Legacy migration failed (non-fatal):', e);
    }
  }

  /* ── Boot sequence ───────────────────────────────────────
     C9/C10 fix: Migration and backfill are now deferred to
     bootApp() in script.js, which runs AFTER SiteManager.migrate
     has assigned siteIds to legacy ponds. Running them here at
     IIFE-load time caused them to no-op because ponds had no
     siteId yet. ─────────────────────────────────────────────── */

  /* ── Public API ──────────────────────────────────────────── */
  const InventoryManager = {
    /* Enumerations, exposed for future UI modules */
    TRANSACTION_TYPES,
    CATEGORIES,
    MEDICINE_CATEGORIES,
    MEDICINE_UNITS,
    FUEL_TYPES,
    DEFAULT_LOW_STOCK_THRESHOLDS,

    /* CRUD */
    validateTransaction,
    createTransaction,
    updateTransaction,
    deleteTransaction,

    /* Queries / analytics */
    calculateStock,
    isLowStock,
    getLowStockItems,
    getMonthlyPurchase,
    getMonthlyConsumption,

    /* Feed-log integration (called from script.js hooks) */
    syncFeedConsumption,
    deleteFeedConsumptionForRecord,
    backfillHistoricalFeedConsumption,
    checkFeedLogStockSufficiency,
    migrateLegacyInventoryData, // C9/C10 fix: exposed so bootApp can call it after SiteManager.migrate
  };

window.InventoryManager = InventoryManager;
})();

// --- Service: locationService.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════
   AquaLog Intelligence — locationService.js
   Responsibilities:
     - Capture GPS location from the browser (navigator.geolocation)
     - Geocode a manually typed place name → {latitude, longitude, address}
     - Reverse-geocode GPS coordinates → human readable address
   Uses Open-Meteo Geocoding API (free, no API key) for forward search,
   and OpenStreetMap Nominatim for reverse lookup (best-effort, optional).
   Exposes: window.LocationService
   ════════════════════════════════════════════ */


  const GEOCODE_URL = 'https://geocoding-api.open-meteo.com/v1/search';
  const REVERSE_URL = 'https://nominatim.openstreetmap.org/reverse';

  /**
   * Requests the device's current GPS location.
   * @returns {Promise<{latitude:number, longitude:number}>}
   */
  function getCurrentGPSLocation() {
    return new Promise((resolve, reject) => {
      if (!('geolocation' in navigator)) {
        reject({ code: 'UNSUPPORTED', message: 'GPS is not supported on this device.' });
        return;
      }
      navigator.geolocation.getCurrentPosition(
        pos => resolve({ latitude: pos.coords.latitude, longitude: pos.coords.longitude }),
        err => {
          let message = 'Unable to retrieve GPS location.';
          let code = 'UNKNOWN';
          if (err.code === err.PERMISSION_DENIED) { code = 'PERMISSION_DENIED'; message = 'GPS permission denied. Please enter your location manually.'; }
          else if (err.code === err.POSITION_UNAVAILABLE) { code = 'UNAVAILABLE'; message = 'Location unavailable. Please enter your location manually.'; }
          else if (err.code === err.TIMEOUT) { code = 'TIMEOUT'; message = 'Location request timed out. Please try again.'; }
          reject({ code, message });
        },
        { enableHighAccuracy: true, timeout: 12000, maximumAge: 60000 }
      );
    });
  }

  /**
   * Converts a typed place name into coordinates + formatted address.
   * @param {string} query - e.g. "Surat Gujarat"
   * @returns {Promise<{latitude:number, longitude:number, address:string}[]>} up to 5 matches
   */
  async function geocodeAddress(query) {
    const q = (query || '').trim();
    if (!q) throw { code: 'EMPTY', message: 'Enter a location to search.' };

    let resp;
    try {
      resp = await fetch(`${GEOCODE_URL}?name=${encodeURIComponent(q)}&count=5&language=en&format=json`);
    } catch (e) {
      throw { code: 'NETWORK', message: 'No internet connection. Please check your network and try again.' };
    }
    if (!resp.ok) throw { code: 'API_ERROR', message: 'Location search service unavailable.' };

    const data = await resp.json();
    if (!data.results || data.results.length === 0) {
      throw { code: 'NOT_FOUND', message: 'No matching location found. Try a different search.' };
    }

    return data.results.map(r => ({
      latitude: r.latitude,
      longitude: r.longitude,
      address: [r.name, r.admin1, r.country].filter(Boolean).join(', '),
    }));
  }

  /**
   * Best-effort reverse geocode of GPS coordinates into a readable address.
   * Falls back to a plain "lat, lng" string if the service is unreachable.
   * @param {number} latitude
   * @param {number} longitude
   * @returns {Promise<string>}
   */
  async function reverseGeocode(latitude, longitude) {
    const fallback = `${latitude.toFixed(4)}, ${longitude.toFixed(4)}`;
    try {
      const resp = await fetch(`${REVERSE_URL}?lat=${latitude}&lon=${longitude}&format=jsonv2`, {
        // L6 fix: add User-Agent header (Nominatim usage policy requires it)
        headers: { 'Accept': 'application/json', 'User-Agent': 'AquaLog/1.0 (shrimp farm management app)' },
      });
      if (!resp.ok) return fallback;
      const data = await resp.json();
      return data.display_name || fallback;
    } catch {
      return fallback;
    }
  }

  const LocationService = {
    getCurrentGPSLocation,
    geocodeAddress,
    reverseGeocode,
  };
window.LocationService = LocationService;
})();

// --- Service: weatherService.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════
   AquaLog Intelligence — weatherService.js
   Responsibilities:
     - Talk to the Open-Meteo Forecast API (free, no API key)
     - Format the raw response into the app's weather shape
     - Cache the last-known-good reading per site (localStorage) and
       serve it when offline / the API is unavailable
   Exposes: window.WeatherService
   ════════════════════════════════════════════ */


  const SK_WEATHER_CACHE = 'al_weather_cache'; // { [siteId]: WeatherReading }
  const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
  const CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes

  // WMO weather interpretation codes → short human label
  const WMO_CONDITIONS = {
    0: 'Clear Sky', 1: 'Mostly Clear', 2: 'Partly Cloudy', 3: 'Overcast',
    45: 'Fog', 48: 'Depositing Fog',
    51: 'Light Drizzle', 53: 'Drizzle', 55: 'Dense Drizzle',
    56: 'Freezing Drizzle', 57: 'Freezing Drizzle',
    61: 'Light Rain', 63: 'Rain', 65: 'Heavy Rain',
    66: 'Freezing Rain', 67: 'Freezing Rain',
    71: 'Light Snow', 73: 'Snow', 75: 'Heavy Snow', 77: 'Snow Grains',
    80: 'Light Showers', 81: 'Showers', 82: 'Violent Showers',
    85: 'Snow Showers', 86: 'Heavy Snow Showers',
    95: 'Thunderstorm', 96: 'Thunderstorm w/ Hail', 99: 'Severe Thunderstorm',
  };

  function safeGetCache() {
    try { return JSON.parse(localStorage.getItem(SK_WEATHER_CACHE)) || {}; }
    catch { return {}; }
  }
  function safeSetCache(cache) {
    try { localStorage.setItem(SK_WEATHER_CACHE, JSON.stringify(cache)); } catch { /* ignore */ }
  }

  function conditionFromCode(code) {
    return WMO_CONDITIONS[code] || 'Unknown';
  }

  function formatReading(raw, currentHourIso) {
    const current = raw.current || {};
    const hourly = raw.hourly || {};
    const daily = raw.daily || {};

    let rainProbability = 0;
    if (Array.isArray(hourly.time) && Array.isArray(hourly.precipitation_probability)) {
      let idx = hourly.time.indexOf(currentHourIso);
      if (idx === -1) idx = 0;
      rainProbability = hourly.precipitation_probability[idx] ?? 0;
    }

    const uvIndex = Array.isArray(daily.uv_index_max) ? daily.uv_index_max[0] : null;

    return {
      temperature: current.temperature_2m ?? null,
      humidity: current.relative_humidity_2m ?? null,
      rainProbability,
      windSpeed: current.wind_speed_10m ?? null,
      pressure: current.pressure_msl ?? null,
      uvIndex,
      condition: conditionFromCode(current.weather_code),
      timestamp: new Date().toISOString(),
    };
  }

  function currentHourISO() {
    // H8 fix: use UTC to match the API's timezone=UTC parameter.
    // Previously used browser-local time, but the API was called with timezone:'auto'
    // (site-local), causing hourly.time.indexOf() to fail when browser tz ≠ site tz.
    const d = new Date();
    const pad = n => String(n).padStart(2, '0');
    return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}T${pad(d.getUTCHours())}:00`;
  }

  /**
   * Fetches (or serves cached) weather for a Site.
   * @param {object} site - Site entity with location.latitude/longitude
   * @param {{forceRefresh?:boolean}} [opts]
   * @returns {Promise<{data:object, fromCache:boolean, error:string|null}>}
   */
  async function getWeatherForSite(site, opts = {}) {
    if (!site || !site.location || site.location.latitude == null || site.location.longitude == null) {
      return { data: null, fromCache: false, error: 'NO_LOCATION' };
    }

    const cache = safeGetCache();
    const cached = cache[site.id];
    const cacheFresh = cached && (Date.now() - new Date(cached.timestamp).getTime()) < CACHE_TTL_MS;

    if (cacheFresh && !opts.forceRefresh) {
      return { data: cached, fromCache: true, error: null };
    }

    if (!navigator.onLine) {
      if (cached) return { data: cached, fromCache: true, error: 'OFFLINE' };
      return { data: null, fromCache: false, error: 'OFFLINE' };
    }

    const { latitude, longitude } = site.location;
    const params = new URLSearchParams({
      latitude, longitude,
      current: 'temperature_2m,relative_humidity_2m,precipitation,weather_code,pressure_msl,wind_speed_10m',
      hourly: 'precipitation_probability,uv_index',
      daily: 'uv_index_max',
      forecast_days: '1',
      timezone: 'UTC', // H8 fix: was 'auto' (site-local), but currentHourISO() uses UTC
    });

    try {
      const resp = await fetch(`${FORECAST_URL}?${params.toString()}`);
      if (!resp.ok) throw new Error('API_ERROR');
      const raw = await resp.json();
      const reading = formatReading(raw, currentHourISO());

      // H9 fix: re-read cache right before writing to avoid losing concurrent writes.
      // Previously the cache was snapshotted at call start; a concurrent fetch for
      // a different site could be overwritten when this call wrote its stale snapshot.
      const freshCache = safeGetCache();
      freshCache[site.id] = reading;
      safeSetCache(freshCache);
      return { data: reading, fromCache: false, error: null };
    } catch (e) {
      if (cached) return { data: cached, fromCache: true, error: 'API_UNAVAILABLE' };
      return { data: null, fromCache: false, error: 'API_UNAVAILABLE' };
    }
  }

  function getCachedWeather(siteId) {
    const cache = safeGetCache();
    return cache[siteId] || null;
  }

  function clearCache(siteId) {
    const cache = safeGetCache();
    if (siteId) delete cache[siteId];
    else Object.keys(cache).forEach(k => delete cache[k]);
    safeSetCache(cache);
  }

  const WeatherService = {
    getWeatherForSite,
    getCachedWeather,
    clearCache,
  };
window.WeatherService = WeatherService;
})();

// --- Service: weatherAlertEngine.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════
   AquaLog Intelligence — weatherAlertEngine.js
   Rule-based rain risk analysis for shrimp ponds.
   Exposes: window.WeatherAlertEngine
   ════════════════════════════════════════════ */


  /**
   * Analyzes a weather reading for rain risk.
   * @param {{rainProbability:number}} weather
   * @returns {null|{level:'warning'|'critical', title:string, message:string, effects:string[], actions:string[]}}
   */
  function analyzeRainRisk(weather) {
    if (!weather || weather.rainProbability == null) return null;
    const p = weather.rainProbability;

    if (p >= 90) {
      return {
        level: 'critical',
        title: 'Critical Rain Alert',
        message: `Very high chance of heavy rain (${p}%). Take immediate precautions.`,
        effects: ['Salinity reduction', 'pH fluctuation', 'Oxygen stress'],
        actions: [
          'Reduce feeding significantly',
          'Increase monitoring frequency',
          'Check dissolved oxygen levels',
        ],
      };
    }
    if (p >= 70) {
      return {
        level: 'warning',
        title: 'Rain Warning',
        message: `Heavy rain expected (${p}% chance).`,
        effects: ['Salinity reduction', 'pH fluctuation', 'Oxygen stress'],
        actions: [
          'Reduce feeding',
          'Check salinity after rain',
          'Monitor shrimp behavior',
          'Keep aerators ready',
        ],
      };
    }
    return null;
  }

  const WeatherAlertEngine = { analyzeRainRisk };
window.WeatherAlertEngine = WeatherAlertEngine;
})();

// --- Service: feedRecommendationEngine.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════
   AquaLog Intelligence — feedRecommendationEngine.js
   Rule-based feeding guidance derived from current weather.
   Exposes: window.FeedRecommendationEngine
   ════════════════════════════════════════════ */


  /**
   * Produces a practical feeding recommendation from a weather reading.
   * @param {{temperature:number, humidity:number, rainProbability:number}} weather
   * @returns {{status:string, title:string, message:string, actions:string[]}}
   */
  function getFeedingRecommendation(weather) {
    if (!weather || weather.temperature == null) {
      return { status: 'unknown', title: 'No Data', message: 'Weather data unavailable — using standard feeding schedule.', actions: [] };
    }

    const t = weather.temperature;
    const h = weather.humidity;
    const actions = [];
    let status = 'normal';
    let title = 'Normal Feeding';
    let message = `Temperature is ${t}°C — within an acceptable feeding range.`;

    // H14 fix: cover gap ranges 26-27 and 33-34 that previously fell through to 'normal'
    if (t >= 34) {
      status = 'high-temp';
      title = 'High Temperature';
      message = `Temperature is ${t}°C — above the comfortable feeding range.`;
      actions.push('Feed during cooler hours (early morning / evening)', 'Reduce afternoon feeding', 'Increase aeration');
    } else if (t <= 26) {
      status = 'low-temp';
      title = 'Low Metabolism';
      message = `Temperature is ${t}°C — shrimp metabolism slows below 26°C.`;
      actions.push('Reduce feed quantity', 'Watch for uneaten feed at next check');
    } else if (t >= 28 && t <= 32) {
      status = 'normal';
      title = 'Normal Feeding';
      message = `Temperature is ${t}°C — ideal range for shrimp feeding.`;
      actions.push('Continue normal feeding schedule');
    } else {
      // H14 fix: gap ranges 26-27 and 33-34 — slightly outside ideal
      status = 'caution';
      title = 'Slightly Outside Ideal Range';
      message = `Temperature is ${t}°C — close to ideal but monitor shrimp behaviour closely.`;
      actions.push('Watch for uneaten feed', 'Monitor dissolved oxygen levels');
    }

    // H15 fix: consider rain probability (was completely ignored)
    const r = weather.rainProbability;
    if (r != null && r >= 70) {
      if (status === 'normal') { status = 'rain-risk'; title = 'Rain Expected'; }
      message += ` High rain probability (${r}%) — shrimp may eat less during rainfall.`;
      actions.push('Reduce feed quantity by 20-30%', 'Resume normal feeding after rain stops');
    } else if (r != null && r >= 40) {
      actions.push('Monitor weather — moderate rain chance (' + r + '%)');
    }

    if (h != null && h >= 80 && t >= 30) {
      if (status === 'normal') { status = 'humidity-risk'; title = 'High Humidity + Temperature'; }
      message += ' High humidity combined with warm water raises the risk of low dissolved oxygen.';
      actions.push('Increase aeration time');
    }

    return { status, title, message, actions };
  }

  const FeedRecommendationEngine = { getFeedingRecommendation };
window.FeedRecommendationEngine = FeedRecommendationEngine;
})();

// --- Service: farmPredictionEngine.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════
   AquaLog Intelligence — farmPredictionEngine.js
   Rule-based (non-ML) farm health scoring from current weather.
   Exposes: window.FarmPredictionEngine
   ════════════════════════════════════════════ */


  /**
   * Computes a 0-100 farm health score from a weather reading.
   * @param {{temperature:number, humidity:number, rainProbability:number}} weather
   * @returns {{score:number, status:string, analysis:{icon:string,text:string}[], recommendation:string}}
   */
  function computeFarmHealthScore(weather) {
    if (!weather || weather.temperature == null) {
      return { score: null, status: 'UNKNOWN', analysis: [{ icon: '—', text: 'Weather data unavailable' }], recommendation: 'Connect a location and refresh weather to see a health score.' };
    }

    let score = 100;
    const analysis = [];
    const t = weather.temperature;
    const h = weather.humidity;
    const r = weather.rainProbability ?? 0;

    // Temperature
    if (t >= 28 && t <= 32) {
      analysis.push({ icon: '✓', text: 'Temperature suitable' });
    } else if (t > 34 || t < 24) {
      score -= 30;
      analysis.push({ icon: '✗', text: `Temperature stressful (${t}°C)` });
    } else {
      score -= 12;
      analysis.push({ icon: '⚠', text: `Temperature slightly outside ideal range (${t}°C)` });
    }

    // Rain risk
    if (r >= 90) {
      score -= 35;
      analysis.push({ icon: '✗', text: 'Rain risk critical' });
    } else if (r >= 70) {
      score -= 20;
      analysis.push({ icon: '⚠', text: 'Rain risk elevated' });
    } else {
      analysis.push({ icon: '✓', text: 'Rain risk low' });
    }

    // Humidity
    if (h != null) {
      if (h >= 85) {
        score -= 15;
        analysis.push({ icon: '⚠', text: 'Humidity high' });
      } else if (h >= 70) {
        score -= 5;
        analysis.push({ icon: '⚠', text: 'Humidity slightly high' });
      } else {
        analysis.push({ icon: '✓', text: 'Humidity normal' });
      }
    }

    score = Math.max(0, Math.min(100, Math.round(score)));

    let status, recommendation;
    if (score >= 80) {
      status = 'GOOD';
      recommendation = 'Continue normal operation.';
    } else if (score >= 55) {
      status = 'WARNING';
      recommendation = 'Reduce feeding, increase aeration, monitor oxygen and shrimp activity.';
    } else {
      status = 'CRITICAL';
      recommendation = 'Minimize feeding, run aerators continuously, check water quality now.';
    }

    return { score, status, analysis, recommendation };
  }

  const FarmPredictionEngine = { computeFarmHealthScore };
window.FarmPredictionEngine = FarmPredictionEngine;
})();

// --- Service: weatherHistoryManager.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;
/* ════════════════════════════════════════════
   AquaLog Intelligence — weatherHistoryManager.js
   Stores one weather snapshot per Site per day for future analytics
   (weather vs feed consumption / growth / survival).
   Exposes: window.WeatherHistoryManager
   ════════════════════════════════════════════ */


  const SK_WEATHER_HISTORY = 'al_weather_history';

  function safeGet() {
    try { return JSON.parse(localStorage.getItem(SK_WEATHER_HISTORY)) || []; }
    catch { return []; }
  }
  function safeSet(list) {
    try { localStorage.setItem(SK_WEATHER_HISTORY, JSON.stringify(list)); } catch { /* ignore */ }
  }

  function todayISO() {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }

  /**
   * Records (or updates) today's weather snapshot for a site.
   * At most one entry per siteId+date — safe to call repeatedly through the day.
   * @param {string} siteId
   * @param {object} weather - reading from WeatherService
   * @param {{feedGiven?:number, growthWeight?:number}} [extra]
   */
  function recordDailySnapshot(siteId, weather, extra = {}) {
    if (!siteId || !weather) return;
    const list = safeGet();
    const date = todayISO();
    let entry = list.find(e => e.siteId === siteId && e.date === date);
    if (!entry) {
      entry = { siteId, date, temperature: null, humidity: null, rainProbability: null, feedGiven: 0, growthWeight: null };
      list.push(entry);
    }
    entry.temperature = weather.temperature ?? entry.temperature;
    entry.humidity = weather.humidity ?? entry.humidity;
    entry.rainProbability = weather.rainProbability ?? entry.rainProbability;
    if (extra.feedGiven !== undefined) entry.feedGiven = extra.feedGiven;
    if (extra.growthWeight !== undefined) entry.growthWeight = extra.growthWeight;
    safeSet(list);
  }

  function getHistoryForSite(siteId) {
    return safeGet().filter(e => e.siteId === siteId).sort((a, b) => a.date.localeCompare(b.date));
  }

  const WeatherHistoryManager = { recordDailySnapshot, getHistoryForSite };
window.WeatherHistoryManager = WeatherHistoryManager;
})();

// --- Module: state.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

const FEED_SIZES = [
  {id:'fs1',label:'Feed Size 1',color:'#38bdf8'},
  {id:'fs2',label:'Feed Size 2',color:'#00d4aa'},
  {id:'fs3',label:'Feed Size 3',color:'#10b981'},
  {id:'fs4',label:'Feed Size 4',color:'#f59e0b'},
  {id:'fs5',label:'Feed Size 5',color:'#a78bfa'},
  {id:'other',label:'Other',color:'#8b949e'},
];
const MS_PER_DAY = 864e5;

window.FEED_SIZES = FEED_SIZES;
window.MS_PER_DAY = MS_PER_DAY;

let records = AppStorage.getRecords();
let ponds = [];
let offlineQ = AppStorage.getQueue();
let batches = AppStorage.getBatches();
let currentPage = 'pageDashboard';
let lastKey = null;
let dupConfirm = false;
let deleteIdx = null;
let batchToComplete = null;
let createBatchForPondId = null;
let viewBatchId = null;
let viewBatchDfsDate = null;
let editPondId = null;
let editFeedIdx = null;
let editBatchId = null;
let editBatchPendingData = null;
let selectedSessionPondId = null;
let selectedSessionDate = null;

const alSelects = {};
let isTimeManuallySelected = false;
let isSettingSuggestedTime = false;

let growthEntries = AppStorage.getGrowth();
let selectedGrowthBatchId = null;
let editGrowthEntryId = null;
let growthModalBatchId = null;

let hapaEntries = AppStorage.getHapa();
let hapaEntryBatchId = null;

let biomassEntries = AppStorage.getBiomass();
let samplingEntries = AppStorage.getSampling();
let samplingBatchId = null;

let dailyCursor = 0;
let weeklyCursor = 0;
let monthlyCursor = 0;
let pondPeriod = 'week';
let reportTab = 'daily';
let historyPond = 'all';

// Setters to update live bindings and window objects
function setRecords(val) { records = val; window.records = val; }
function setPonds(val) { ponds = val; window.ponds = val; }
function setOfflineQ(val) { offlineQ = val; window.offlineQ = val; }
function setBatches(val) { batches = val; window.batches = val; }
function setCurrentPage(val) { currentPage = val; window.currentPage = val; }
function setLastKey(val) { lastKey = val; window.lastKey = val; }
function setDupConfirm(val) { dupConfirm = val; window.dupConfirm = val; }
function setDeleteIdx(val) { deleteIdx = val; window.deleteIdx = val; }
function setBatchToComplete(val) { batchToComplete = val; window.batchToComplete = val; }
function setCreateBatchForPondId(val) { createBatchForPondId = val; window.createBatchForPondId = val; }
function setViewBatchId(val) { viewBatchId = val; window.viewBatchId = val; }
function setViewBatchDfsDate(val) { viewBatchDfsDate = val; window.viewBatchDfsDate = val; }
function setEditPondId(val) { editPondId = val; window.editPondId = val; }
function setEditFeedIdx(val) { editFeedIdx = val; window.editFeedIdx = val; }
function setEditBatchId(val) { editBatchId = val; window.editBatchId = val; }
function setEditBatchPendingData(val) { editBatchPendingData = val; window.editBatchPendingData = val; }
function setSelectedSessionPondId(val) { selectedSessionPondId = val; window.selectedSessionPondId = val; }
function setSelectedSessionDate(val) { selectedSessionDate = val; window.selectedSessionDate = val; }
function setIsTimeManuallySelected(val) { isTimeManuallySelected = val; window.isTimeManuallySelected = val; }
function setIsSettingSuggestedTime(val) { isSettingSuggestedTime = val; window.isSettingSuggestedTime = val; }
function setGrowthEntries(val)   { growthEntries   = val; window.growthEntries   = val; }
function setSelectedGrowthBatchId(val) { selectedGrowthBatchId = val; window.selectedGrowthBatchId = val; }
function setEditGrowthEntryId(val) { editGrowthEntryId = val; window.editGrowthEntryId = val; }
function setGrowthModalBatchId(val) { growthModalBatchId = val; window.growthModalBatchId = val; }
function setHapaEntries(val)     { hapaEntries     = val; window.hapaEntries     = val; }
function setHapaEntryBatchId(val) { hapaEntryBatchId = val; window.hapaEntryBatchId = val; }
function setBiomassEntries(val)  { biomassEntries  = val; window.biomassEntries  = val; }
function setSamplingEntries(val) { samplingEntries = val; window.samplingEntries = val; }
function setSamplingBatchId(val) { samplingBatchId = val; window.samplingBatchId = val; }
function setDailyCursor(val) { dailyCursor = val; window.dailyCursor = val; }
function setWeeklyCursor(val) { weeklyCursor = val; window.weeklyCursor = val; }
function setMonthlyCursor(val) { monthlyCursor = val; window.monthlyCursor = val; }
function setPondPeriod(val) { pondPeriod = val; window.pondPeriod = val; }
function setReportTab(val) { reportTab = val; window.reportTab = val; }
function setHistoryPond(val) { historyPond = val; window.historyPond = val; }

// Window bindings for backward compatibility and strict mode compliance
window.records = records;
window.ponds = ponds;
window.offlineQ = offlineQ;
window.batches = batches;
window.currentPage = currentPage;
window.lastKey = lastKey;
window.dupConfirm = dupConfirm;
window.deleteIdx = deleteIdx;
window.batchToComplete = batchToComplete;
window.createBatchForPondId = createBatchForPondId;
window.viewBatchId = viewBatchId;
window.viewBatchDfsDate = viewBatchDfsDate;
window.editPondId = editPondId;
window.editFeedIdx = editFeedIdx;
window.editBatchId = editBatchId;
window.editBatchPendingData = editBatchPendingData;
window.selectedSessionPondId = selectedSessionPondId;
window.selectedSessionDate = selectedSessionDate;
window.alSelects = alSelects;
window.isTimeManuallySelected = isTimeManuallySelected;
window.isSettingSuggestedTime = isSettingSuggestedTime;
window.growthEntries = growthEntries;
window.selectedGrowthBatchId = selectedGrowthBatchId;
window.editGrowthEntryId = editGrowthEntryId;
window.growthModalBatchId = growthModalBatchId;
window.hapaEntries = hapaEntries;
window.hapaEntryBatchId = hapaEntryBatchId;
window.biomassEntries = biomassEntries;
window.samplingEntries = samplingEntries;
window.samplingBatchId = samplingBatchId;
window.dailyCursor = dailyCursor;
window.weeklyCursor = weeklyCursor;
window.monthlyCursor = monthlyCursor;
window.pondPeriod = pondPeriod;
window.reportTab = reportTab;
window.historyPond = historyPond;

// Expose state namespace globally for un-modularized bundled script.js context
const stateNamespace = {
  get records() { return window.records; },
  set records(val) { setRecords(val); },
  setRecords,
  
  get ponds() { return window.ponds; },
  set ponds(val) { setPonds(val); },
  setPonds,
  
  get offlineQ() { return window.offlineQ; },
  set offlineQ(val) { setOfflineQ(val); },
  setOfflineQ,
  
  get batches() { return window.batches; },
  set batches(val) { setBatches(val); },
  setBatches,
  
  get currentPage() { return window.currentPage; },
  set currentPage(val) { setCurrentPage(val); },
  setCurrentPage,
  
  get lastKey() { return window.lastKey; },
  set lastKey(val) { setLastKey(val); },
  setLastKey,
  
  get dupConfirm() { return window.dupConfirm; },
  set dupConfirm(val) { setDupConfirm(val); },
  setDupConfirm,
  
  get deleteIdx() { return window.deleteIdx; },
  set deleteIdx(val) { setDeleteIdx(val); },
  setDeleteIdx,
  
  get batchToComplete() { return window.batchToComplete; },
  set batchToComplete(val) { setBatchToComplete(val); },
  setBatchToComplete,
  
  get createBatchForPondId() { return window.createBatchForPondId; },
  set createBatchForPondId(val) { setCreateBatchForPondId(val); },
  setCreateBatchForPondId,
  
  get viewBatchId() { return window.viewBatchId; },
  set viewBatchId(val) { setViewBatchId(val); },
  setViewBatchId,
  
  get viewBatchDfsDate() { return window.viewBatchDfsDate; },
  set viewBatchDfsDate(val) { setViewBatchDfsDate(val); },
  setViewBatchDfsDate,
  
  get editPondId() { return window.editPondId; },
  set editPondId(val) { setEditPondId(val); },
  setEditPondId,
  
  get editFeedIdx() { return window.editFeedIdx; },
  set editFeedIdx(val) { setEditFeedIdx(val); },
  setEditFeedIdx,
  
  get editBatchId() { return window.editBatchId; },
  set editBatchId(val) { setEditBatchId(val); },
  setEditBatchId,
  
  get editBatchPendingData() { return window.editBatchPendingData; },
  set editBatchPendingData(val) { setEditBatchPendingData(val); },
  setEditBatchPendingData,
  
  get selectedSessionPondId() { return window.selectedSessionPondId; },
  set selectedSessionPondId(val) { setSelectedSessionPondId(val); },
  setSelectedSessionPondId,
  
  get selectedSessionDate() { return window.selectedSessionDate; },
  set selectedSessionDate(val) { setSelectedSessionDate(val); },
  setSelectedSessionDate,
  
  get alSelects() { return window.alSelects; },
  
  get isTimeManuallySelected() { return window.isTimeManuallySelected; },
  set isTimeManuallySelected(val) { setIsTimeManuallySelected(val); },
  setIsTimeManuallySelected,
  
  get isSettingSuggestedTime() { return window.isSettingSuggestedTime; },
  set isSettingSuggestedTime(val) { setIsSettingSuggestedTime(val); },
  setIsSettingSuggestedTime,
  
  get growthEntries() { return window.growthEntries; },
  set growthEntries(val) { setGrowthEntries(val); },
  setGrowthEntries,
  
  get selectedGrowthBatchId() { return window.selectedGrowthBatchId; },
  set selectedGrowthBatchId(val) { setSelectedGrowthBatchId(val); },
  setSelectedGrowthBatchId,
  
  get editGrowthEntryId() { return window.editGrowthEntryId; },
  set editGrowthEntryId(val) { setEditGrowthEntryId(val); },
  setEditGrowthEntryId,
  
  get growthModalBatchId() { return window.growthModalBatchId; },
  set growthModalBatchId(val) { setGrowthModalBatchId(val); },
  setGrowthModalBatchId,
  
  get hapaEntries() { return window.hapaEntries; },
  set hapaEntries(val) { setHapaEntries(val); },
  setHapaEntries,
  
  get hapaEntryBatchId() { return window.hapaEntryBatchId; },
  set hapaEntryBatchId(val) { setHapaEntryBatchId(val); },
  setHapaEntryBatchId,
  
  get biomassEntries() { return window.biomassEntries; },
  set biomassEntries(val) { setBiomassEntries(val); },
  setBiomassEntries,
  
  get samplingEntries() { return window.samplingEntries; },
  set samplingEntries(val) { setSamplingEntries(val); },
  setSamplingEntries,
  
  get samplingBatchId() { return window.samplingBatchId; },
  set samplingBatchId(val) { setSamplingBatchId(val); },
  setSamplingBatchId,
  
  get dailyCursor() { return window.dailyCursor; },
  set dailyCursor(val) { setDailyCursor(val); },
  setDailyCursor,
  
  get weeklyCursor() { return window.weeklyCursor; },
  set weeklyCursor(val) { setWeeklyCursor(val); },
  setWeeklyCursor,
  
  get monthlyCursor() { return window.monthlyCursor; },
  set monthlyCursor(val) { setMonthlyCursor(val); },
  setMonthlyCursor,
  
  get pondPeriod() { return window.pondPeriod; },
  set pondPeriod(val) { setPondPeriod(val); },
  setPondPeriod,
  
  get reportTab() { return window.reportTab; },
  set reportTab(val) { setReportTab(val); },
  setReportTab,
  
  get historyPond() { return window.historyPond; },
  set historyPond(val) { setHistoryPond(val); },
  setHistoryPond
};
window.state = stateNamespace;
})();

// --- Module: ui.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

function animateValue(el, end, suffix = '', duration = 600) {
  if (!el) return;
  const start = 0;
  let startTime = null;
  const isFloat = !Number.isInteger(end);
  function step(now) {
    if (startTime === null) startTime = now;
    const elapsed = now - startTime;
    const progress = Math.min(elapsed / duration, 1);
    const ease = 1 - Math.pow(1 - progress, 3); // ease-out-cubic
    const current = start + (end - start) * ease;
    el.textContent = (isFloat ? current.toFixed(1) : Math.round(current)) + suffix;
    if (progress < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

function updateStatusBar() {
  const now  = new Date();
  const h    = now.getHours();
  const m    = String(now.getMinutes()).padStart(2,'0');
  const ampm = h >= 12 ? 'PM' : 'AM';
  const h12  = ((h % 12) || 12);
  const _statusTime = $('statusTime');
  if (_statusTime) _statusTime.textContent = `${h12}:${m} ${ampm}`;
}

function addNavRipple(btn, event) {
  const r = document.createElement('span');
  r.className = 'nav-ripple';
  const size = Math.max(btn.offsetWidth, btn.offsetHeight);
  r.style.cssText = 'width:' + size + 'px;height:' + size + 'px;left:' + (event.offsetX - size/2) + 'px;top:' + (event.offsetY - size/2) + 'px;';
  btn.appendChild(r);
  r.addEventListener('animationend', () => r.remove());
}

function switchPage(pageId) {
  // exit animation on current active page
  const currentActive = document.querySelector('.page.active');
  if (currentActive && currentActive.id !== pageId) {
    currentActive.classList.add('page-exit');
    setTimeout(() => {
      currentActive.classList.remove('active','page-exit');
    }, 200);
  }

  const nextPage = $(pageId);
  if (nextPage) {
    nextPage.style.transform = 'translateX(24px)';
    nextPage.style.opacity = '0';
    nextPage.classList.add('active');
    
    // Force a reflow to make the transition animation run correctly
    nextPage.offsetWidth;
    
    nextPage.style.transform = '';
    nextPage.style.opacity = '';
  }

  const tabMap = {
    pageDashboard: 'overview',
    pageManage: 'manage',
    pageReports: 'reports',
    pageSettings: 'settings',
    pageInventory: 'inventory',
    pageFinance: 'finance',
    pageFeedDetail: 'inventory',
    pageMedicineDetail: 'inventory',
    pageFuelDetail: 'inventory',
    pageInventoryReports: 'inventory'
  };
  const activeTab = tabMap[pageId];
  document.querySelectorAll('.nav-item').forEach(n => {
    n.classList.toggle('active', activeTab ? n.dataset.tab === activeTab : n.dataset.page === pageId);
  });
  currentPage = pageId;
  // Wrap each render in try/catch so a single failing render doesn't leave
  // the page-switch UI in an inconsistent state (e.g., during Next.js HMR
  // when body.html is briefly re-injected and elements are momentarily missing).
  const _safe = (fn, label) => { try { fn(); } catch (e) { console.error('[AquaLog] render failed (' + label + '):', e); } };
  if (pageId === 'pageDashboard') _safe(() => renderDashboard(), 'dashboard');
  if (pageId === 'pageManage')    _safe(() => renderManagePage(), 'manage');
  // Hide the floating batch-shortcut pill on pages where it provides no context
  // (Manage already has dedicated pond navigation via the Active Pond selector).
  if (pageId === 'pageManage') {
    const shortcutBtn = $('batchShortcutBtn');
    if (shortcutBtn) shortcutBtn.classList.add('hidden');
  }
  if (pageId === 'pageLog') {
    _safe(() => {
      renderLogPondSelect();
      if (!isTimeManuallySelected) {
        setSuggestedFeedTime();
      }
      autoSelectPreviousFeedSizes();
    }, 'log');
  }
  if (pageId === 'pageReports')   _safe(() => renderReportsTab(reportTab), 'reports');
  if (pageId === 'pageSettings')  _safe(() => renderSitesSettings(), 'settings');
  if (pageId === 'pageFinance' && typeof renderFinancePage === 'function') _safe(() => renderFinancePage(), 'finance');
  // M6 fix: stop weather auto-refresh when leaving the dashboard (was only stopped in showFarmView)
  if (pageId !== 'pageDashboard' && typeof stopWeatherAutoRefresh === 'function') {
    stopWeatherAutoRefresh();
  }
  // pageGrowth removed — Growth Tracking is embedded in Batch Dashboard
}

function renderSessionsList(container, recs) {
  if (!recs.length) {
    container.innerHTML = `<div class="empty-state">
      <div class="empty-icon">🌊</div>
      <div class="empty-text">No Records Available</div>
      <div class="empty-sub">Tap + to log a feeding</div>
    </div>`;
    return;
  }
  container.innerHTML = '';
  // M13 fix: pre-compute record→index map to avoid O(N) indexOf per session card (was O(N²))
  const recIndexMap = new Map();
  records.forEach((r, i) => recIndexMap.set(r, i));
  recs.forEach((r, i) => {
    const grams = sumGrams([r]);
    const feeds = feedSummaryStr(r);
    const idx   = recIndexMap.has(r) ? recIndexMap.get(r) : i;
    const pondDisplay = r.PondName || r.Pond || '—';
    const shortLabel  = pondDisplay.length > 6 ? pondDisplay.slice(0,6)+'…' : pondDisplay;
    const card  = document.createElement('div');
    card.className = 'session-card';
    card.innerHTML = `
      <div class="session-pond-badge">${shortLabel}</div>
      <div class="session-info">
        <div class="session-time">${r.Time} · ${r.Date}</div>
        <div class="session-total">${fmtGrams(grams)} g total</div>
        <div class="session-feeds">${feeds}</div>
      </div>
      <div class="session-actions">
        <button class="icon-btn edit" data-idx="${idx}" title="Edit" aria-label="Edit Feed Entry">✏</button>
        <button class="icon-btn del" data-idx="${idx}" title="Delete" aria-label="Delete Feed Entry">🗑</button>
      </div>`;
    container.appendChild(card);
  });
  container.querySelectorAll('.icon-btn.edit').forEach(btn => {
    btn.addEventListener('click', () => openEditFeedModal(+btn.dataset.idx));
  });
  container.querySelectorAll('.icon-btn.del').forEach(btn => {
    btn.addEventListener('click', () => confirmDelete(+btn.dataset.idx));
  });
}

function renderPondBreakdown(container, recs) {
  const pondMap = {};
  recs.forEach(r => {
    const key = r.PondName || r.Pond || 'Unknown';
    pondMap[key] = (pondMap[key]||0) + sumGrams([r]);
  });
  const total = Object.values(pondMap).reduce((a,b)=>a+b,0);
  const sorted = Object.entries(pondMap).sort((a,b)=>b[1]-a[1]);

  if (!sorted.length) {
    container.innerHTML = `<div class="empty-state"><div class="empty-icon">🏊</div><div class="empty-text">No Records Available</div></div>`;
    return;
  }
  container.innerHTML = sorted.map(([pond, grams]) => {
    const pct = total > 0 ? Math.round(grams/total*100) : 0;
    const sessions = recs.filter(r=>(r.PondName||r.Pond)===pond).length;
    return `<div class="pb-card">
      <div class="pb-top"><div class="pb-name">${pond}</div><div class="pb-val">${fmtGrams(grams)}g</div></div>
      <div class="pb-bar-bg"><div class="pb-bar-fill" style="width:${pct}%"></div></div>
      <div class="pb-sub">${pct}% of total · ${sessions} session${sessions!==1?'s':''}</div>
    </div>`;
  }).join('');
}

function showFieldError(errId, fieldId, message) {
  const err = $(errId);
  if (err) {
    if (message) err.textContent = message;
    err.classList.add('show');
  }
  if (fieldId) $(fieldId)?.classList.add('err');
}

function clearFieldError(errId, fieldId, defaultMessage) {
  const err = $(errId);
  if (err) {
    if (defaultMessage) err.textContent = defaultMessage;
    err.classList.remove('show');
  }
  if (fieldId) $(fieldId)?.classList.remove('err');
}

function showToast(title, sub = '', type = 'success', duration = 2800) {
  // Signature adapter for backward compatibility with old calls: showToast(ico, title, sub)
  // L11 fix: detect icon by emoji/symbol prefix, not by length (was misclassifying short titles like 'OK' as icons)
  if (typeof title === 'string' && /^[\p{Emoji}\u2700-\u27BF\u2190-\u21FF\u2B00-\u2BFF]/u.test(title)) {
    const ico = title;
    title = sub;
    sub = type;
    if (ico === '❌' || ico === '!' || ico === '??' || ico === 'offline' || ico === 'failed') {
      type = 'error';
    } else if (ico === '⚠️' || ico === 'warn') {
      type = 'warn';
    } else if (ico === 'ℹ️' || ico === 'info') {
      type = 'info';
    } else {
      type = 'success';
    }
  }

  const t = $('toast');
  const ico = $('toastIco');
  const tTitle = $('toastTitle');
  const tSub = $('toastSub');
  if (!t) return;

  const icons = { success:'✅', error:'❌', warn:'⚠️', info:'ℹ️' };
  ico.textContent = icons[type] || '✅';
  tTitle.textContent = title;
  tSub.textContent = sub;
  tSub.style.display = sub ? 'block' : 'none';

  // type accent class
  t.className = 'toast toast-' + type;

  // add progress bar
  const existing = t.querySelector('.toast-progress');
  if (existing) existing.remove();
  const bar = document.createElement('div');
  bar.className = 'toast-progress';
  bar.style.animationDuration = duration + 'ms';
  t.appendChild(bar);

  // show
  requestAnimationFrame(() => {
    t.classList.add('show');
  });

  clearTimeout(t._toastTimer);
  t._toastTimer = setTimeout(() => {
    t.classList.remove('show');
    t.classList.add('hide');
    setTimeout(() => t.classList.remove('hide'), 250);
  }, duration);
  announceToScreenReader(`${title}. ${sub || ''}`);
}

function celebrateSuccess() {
  // Create celebration overlay
  const overlay = document.createElement('div');
  overlay.style.cssText = `
    position: fixed;
    inset: 0;
    z-index: 2000;
    pointer-events: none;
    display: flex;
    align-items: center;
    justify-content: center;
  `;

  // Big checkmark
  const check = document.createElement('div');
    check.style.cssText = `
    width: 100px;
    height: 100px;
    border-radius: 50%;
    background: linear-gradient(135deg, #00c6d4, #10b981);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 3rem;
    box-shadow: 0 8px 40px rgba(0,198,212,0.50);
    animation: celebratePop 0.5s cubic-bezier(.34,1.56,.64,1) both;
    color: white;
  `;
  check.textContent = '✓';

  // Add CSS animation
  if (!document.getElementById('celebrateStyle')) {
    const style = document.createElement('style');
    style.id = 'celebrateStyle';
    style.textContent = `
      @keyframes celebratePop {
        0%   { transform: scale(0); opacity: 0; }
        70%  { transform: scale(1.15); opacity: 1; }
        100% { transform: scale(1); opacity: 1; }
      }
      @keyframes celebrateFade {
        0%   { opacity: 1; }
        70%  { opacity: 1; }
        100% { opacity: 0; }
      }
    `;
    document.head.appendChild(style);
  }

  overlay.style.animation = 'celebrateFade 1.2s ease forwards';
  overlay.appendChild(check);
  document.body.appendChild(overlay);
  setTimeout(() => overlay.remove(), 1300);
}

function flashElement(el, duration = 420) {
  if (!el) return;
  el.classList.add('flash');
  window.setTimeout(() => el.classList.remove('flash'), duration);
}

function setLoading(on) {
  $('submitBtn').disabled = on;
  $('submitLabel').classList.toggle('hidden', on);
  $('submitLoading').classList.toggle('hidden', !on);
}

function announceToScreenReader(message) {
  const announcer = $('srAnnouncer');
  if (announcer) {
    announcer.textContent = '';
    setTimeout(() => {
      announcer.textContent = message;
    }, 100);
  }
}

function createAlSelect(selectId, opts = {}) {
  const sel = $(selectId);
  if (!sel) return null;

  const wrapper = document.createElement('div');
  wrapper.className = 'al-select';
  sel.parentNode.insertBefore(wrapper, sel.nextSibling);

  // Hide native elements
  sel.style.display = 'none';
  const existingArrow = sel.parentElement.querySelector('.sel-arrow');
  if (existingArrow) existingArrow.style.display = 'none';

  // Trigger button
  const trigger = document.createElement('button');
  trigger.type = 'button';
  trigger.className = 'al-select-trigger';
  trigger.setAttribute('aria-haspopup', 'listbox');
  trigger.setAttribute('aria-expanded', 'false');
  wrapper.appendChild(trigger);

  // Dropdown panel
  const panel = document.createElement('div');
  panel.className = 'al-select-panel';
  panel.setAttribute('role', 'listbox');
  document.body.appendChild(panel);

  let isOpen = false;

  // Assign unique ID to wrapper and panel for tracking
  wrapper.dataset.alId = 'al_' + Math.random().toString(36).slice(2,8);
  panel.dataset.owner = wrapper.dataset.alId;

  function updateTrigger() {
    // Sync disabled state
    const isDisabled = sel.disabled;
    trigger.disabled = isDisabled;
    wrapper.classList.toggle('disabled', isDisabled);

    const idx = sel.selectedIndex;
    const selected = (idx >= 0) ? sel.options[idx] : null;
    const hasValue = selected && selected.value;
    const text = hasValue ? selected.textContent.trim() : (opts.placeholder || 'Select…');
    trigger.innerHTML =
      `<span class="al-sel-val${hasValue ? '' : ' placeholder'}">${text}</span>` +
      `<span class="al-sel-arrow">▾</span>`;
  }

  function buildPanel() {
    panel.innerHTML = '';
    Array.from(sel.children).forEach(child => {
      if (child.tagName === 'OPTGROUP') {
        const hdr = document.createElement('div');
        hdr.className = 'al-select-group-label';
        hdr.textContent = child.label;
        panel.appendChild(hdr);
        Array.from(child.children).forEach(addOption);
      } else if (child.tagName === 'OPTION') {
        addOption(child);
      }
    });
  }

  function addOption(opt) {
    if (!opt.value && opt.disabled) return; // skip empty placeholder header options
    const item = document.createElement('button');
    item.type = 'button';
    item.className = 'al-select-option';
    item.dataset.value = opt.value;
    item.textContent = opt.textContent.trim();
    item.setAttribute('role', 'option');
    const isSelected = opt.value && opt.value === sel.value;
    item.setAttribute('aria-selected', isSelected ? 'true' : 'false');
    if (opt.disabled) { item.classList.add('disabled'); item.disabled = true; }
    if (isSelected) item.classList.add('selected');
    item.addEventListener('click', () => {
      if (opt.disabled) return;
      sel.value = opt.value;
      sel.dispatchEvent(new Event('change', { bubbles: true }));
      updateTrigger();
      buildPanel();
      close();
      trigger.focus();
    });
    panel.appendChild(item);
  }

  function open() {
    if (sel.disabled) return;
    document.querySelectorAll('.al-select.open').forEach(el => {
      if (el !== wrapper) {
        // Find owner custom select panel and trigger close
        const ownerId = el.dataset.alId;
        const openPanel = document.querySelector(`.al-select-panel[data-owner="${ownerId}"]`);
        if (openPanel) {
          el.classList.remove('open');
          openPanel.style.opacity = '';
          openPanel.style.transform = '';
          openPanel.style.pointerEvents = 'none';
        }
      }
    });
    buildPanel();

    // Position panel using fixed coords relative to trigger
    const rect = trigger.getBoundingClientRect();
    const spaceBelow = window.innerHeight - rect.bottom;
    const spaceAbove = rect.top;
    const panelHeight = Math.min(260, (spaceBelow > 180 ? spaceBelow - 12 : spaceAbove - 12));

    panel.style.position = 'fixed';
    panel.style.width = rect.width + 'px';
    panel.style.maxHeight = panelHeight + 'px';
    panel.style.zIndex = '9000';

    if (spaceBelow > 180 || spaceBelow >= spaceAbove) {
      // Open downward
      panel.style.top = (rect.bottom + 5) + 'px';
      panel.style.bottom = 'auto';
    } else {
      // Open upward
      panel.style.bottom = (window.innerHeight - rect.top + 5) + 'px';
      panel.style.top = 'auto';
    }
    panel.style.left = rect.left + 'px';
    panel.dataset.owner = wrapper.dataset.alId || '';

    panel.style.opacity = '1';
    panel.style.transform = 'scaleY(1) translateY(0)';
    panel.style.pointerEvents = 'all';

    wrapper.classList.add('open');
    trigger.setAttribute('aria-expanded', 'true');
    isOpen = true;

    // Attach temporary global listeners
    document.addEventListener('click', onDocumentClick, true);
    document.addEventListener('scroll', onDocumentScroll, { capture: true, passive: true });
    window.addEventListener('resize', onWindowResize, { passive: true });
  }

  function close() {
    if (!isOpen) return;
    
    // Detach global listeners
    document.removeEventListener('click', onDocumentClick, true);
    document.removeEventListener('scroll', onDocumentScroll, true);
    window.removeEventListener('resize', onWindowResize);

    wrapper.classList.remove('open');
    panel.classList.remove('open-panel');
    trigger.setAttribute('aria-expanded', 'false');
    isOpen = false;
    panel.style.opacity = '';
    panel.style.transform = '';
    panel.style.pointerEvents = 'none';
    panel.style.top = '';
    panel.style.bottom = '';
    panel.style.left = '';
    panel.style.width = '';
    panel.style.maxHeight = '';
  }

  const onDocumentClick = e => {
    if (!wrapper.contains(e.target) && !panel.contains(e.target)) close();
  };
  const onDocumentScroll = e => {
    if (e && e.target && panel.contains(e.target)) return;
    close();
  };
  const onWindowResize = () => {
    close();
  };

  trigger.addEventListener('click', e => { e.stopPropagation(); isOpen ? close() : open(); });

  wrapper.addEventListener('keydown', e => {
    const activeEl = document.activeElement;
    const isTriggerFocused = activeEl === trigger;
    const options = Array.from(panel.querySelectorAll('.al-select-option:not(.disabled)'));
    const activeIndex = options.indexOf(activeEl);

    if (e.key === 'Escape') {
      close();
      trigger.focus();
      e.preventDefault();
      e.stopPropagation();
    } else if (e.key === 'Enter' || e.key === ' ') {
      if (!isOpen) {
        e.preventDefault();
        open();
        setTimeout(() => {
          const selectedOpt = panel.querySelector('.al-select-option.selected:not(.disabled)');
          if (selectedOpt) {
            selectedOpt.focus();
          } else if (options.length > 0) {
            options[0].focus();
          }
        }, 50);
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (!isOpen) {
        open();
        setTimeout(() => {
          if (options.length > 0) options[0].focus();
        }, 50);
      } else {
        if (isTriggerFocused) {
          if (options.length > 0) options[0].focus();
        } else if (activeIndex >= 0 && activeIndex < options.length - 1) {
          options[activeIndex + 1].focus();
        }
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (isOpen) {
        if (activeIndex > 0) {
          options[activeIndex - 1].focus();
        } else {
          trigger.focus();
        }
      }
    } else if (e.key === 'Tab') {
      close();
    }
  });

  // Mirror class (.err), disabled state, and child list updates from native select
  const syncAll = () => {
    wrapper.classList.toggle('err', sel.classList.contains('err'));
    const isDisabled = sel.disabled;
    trigger.disabled = isDisabled;
    wrapper.classList.toggle('disabled', isDisabled);
    updateTrigger();
    buildPanel();
  };

  new MutationObserver(syncAll).observe(sel, { 
    attributes: true, 
    attributeFilter: ['class', 'disabled'],
    childList: true,
    subtree: true
  });

  // Intercept programmatic setting of sel.value
  const descriptor = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value');
  if (descriptor && descriptor.set) {
    Object.defineProperty(sel, 'value', {
      get() {
        return descriptor.get.call(sel);
      },
      set(val) {
        descriptor.set.call(sel, val);
        updateTrigger();
        buildPanel();
      },
      configurable: true
    });
  }

  syncAll();

  return {
    refresh() { buildPanel(); updateTrigger(); },
    sync()    { updateTrigger(); buildPanel(); },
    close,
    open,
    destroy() { 
      close();
      if (panel.parentNode === document.body) document.body.removeChild(panel);
      if (wrapper.parentNode) wrapper.parentNode.removeChild(wrapper);
      sel.style.display = '';
    },
  };
}

function initAlSelects() {
  alSelects.feedTime          = createAlSelect('feedTime',               { placeholder: 'Select time…'  });
  alSelects.pondSelect        = createAlSelect('pondSelect',             { placeholder: '— Select pond —' });
  alSelects.editFeedTime      = createAlSelect('editFeedTime',           { placeholder: 'Select time…'  });
  alSelects.dashCtx           = createAlSelect('dashboardContextSelect', { placeholder: 'Farm Overview' });
  alSelects.apiMethod         = createAlSelect('apiMethod',         { placeholder: 'POST' });
  alSelects.languageSelect    = createAlSelect('languageSelect',    { placeholder: 'English' });
  alSelects.newPondSite       = createAlSelect('newPondSite',       { placeholder: '— Select Site —' });
  alSelects.editPondSite      = createAlSelect('editPondSite',      { placeholder: '— Select Site —' });
  alSelects.growthBatchSelect = createAlSelect('growthBatchSelect', { placeholder: '— Select batch —' });

  // Inventory Selects
  alSelects.inventorySiteSelect       = createAlSelect('inventorySiteSelect',       { placeholder: 'Select Site' });
  alSelects.feedDetailSiteSelect      = createAlSelect('feedDetailSiteSelect',      { placeholder: 'Select Site' });
  alSelects.medDetailSiteSelect       = createAlSelect('medDetailSiteSelect',       { placeholder: 'Select Site' });
  alSelects.fuelDetailSiteSelect      = createAlSelect('fuelDetailSiteSelect',      { placeholder: 'Select Site' });
  alSelects.reportsSiteSelect         = createAlSelect('reportsSiteSelect',         { placeholder: 'Select Site' });
  alSelects.inventoryReportTypeSelect = createAlSelect('inventoryReportTypeSelect', { placeholder: 'Select Report' });
  alSelects.reportCategorySelect      = createAlSelect('reportCategorySelect',      { placeholder: 'All Categories' });
  alSelects.reportFuelTypeSelect      = createAlSelect('reportFuelTypeSelect',      { placeholder: 'All Fuel Types' });
  alSelects.reportTxTypeSelect        = createAlSelect('reportTxTypeSelect',        { placeholder: 'All Movements' });
  alSelects.feedSize                  = createAlSelect('feedSize',                  { placeholder: 'Select Feed Size' });
  alSelects.medCategory               = createAlSelect('medCategory',               { placeholder: 'Select Category' });
  alSelects.medUnit                   = createAlSelect('medUnit',                   { placeholder: 'Select Unit' });
  alSelects.fuelType                  = createAlSelect('fuelType',                  { placeholder: 'Select Fuel Type' });
  alSelects.medicineItemSelect        = createAlSelect('medicineItemSelect',        { placeholder: '— Select from inventory —' });
}

function sumGrams(recs) {
  return recs.reduce((sum, r) => {
    let g = 0;
    for (let i = 1; i <= 5; i++) g += +(r[`Feed Size ${i} Gram`]||0);
    g += +(r['Other Feed Gram']||0);
    return sum + g;
  }, 0);
}

function feedSummaryStr(r) {
  const parts = [];
  for (let i = 1; i <= 5; i++) {
    const v = +(r[`Feed Size ${i} Gram`]||0);
    if (v > 0) parts.push(`FS${i}: ${fmtGrams(v)}g`);
  }
  if (+r['Other Feed Gram'] > 0) parts.push(`${escapeHTML(r['Other Feed Name']||'Other')}: ${fmtGrams(+r['Other Feed Gram'])}g`); // M1 fix: escape user input
  return parts.join(' · ');
}

function showHide(el, show) {
  if (!el) return;
  el.style.display = show ? '' : 'none';
}

function scrollToError() {
  const el = document.querySelector('.ferr.show, .qty-input.err, .fi.err');
  if (el) el.scrollIntoView({ behavior:'smooth', block:'center' });
}

function formHasData() {
  // M16 fix: null-check elements (was dereferencing .value on possibly-null elements)
  return ($('feedTime')?.value || $('pondSelect')?.value || getCheckedIds().length > 0);
}

// Window bindings for backward compatibility
window.animateValue = animateValue;
window.updateStatusBar = updateStatusBar;
window.addNavRipple = addNavRipple;
window.switchPage = switchPage;
window.renderSessionsList = renderSessionsList;
window.renderPondBreakdown = renderPondBreakdown;
window.showFieldError = showFieldError;
window.clearFieldError = clearFieldError;
window.showToast = showToast;
window.celebrateSuccess = celebrateSuccess;
window.flashElement = flashElement;
window.setLoading = setLoading;
window.announceToScreenReader = announceToScreenReader;
window.createAlSelect = createAlSelect;
window.initAlSelects = initAlSelects;
window.sumGrams = sumGrams;
window.feedSummaryStr = feedSummaryStr;
window.showHide = showHide;
window.scrollToError = scrollToError;
window.formHasData = formHasData;
})();

// --- Module: modals.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

let _confirmCb = null;
let activeDatePickerTarget = null;
let currentCalMonth = 0;
let currentCalYear = 2026;

const MODAL_STATE_CLEANUP = window.MODAL_STATE_CLEANUP || {};
window.MODAL_STATE_CLEANUP = MODAL_STATE_CLEANUP;
// Auto-close fix: confirmModal cleanup must ONLY clear the callback — NOT call _cancelConfirm()
// (which calls closeModal again, triggering MODAL_STATE_CLEANUP.confirmModal again → infinite 250ms loop)
MODAL_STATE_CLEANUP.confirmModal = () => { _confirmCb = null; };
MODAL_STATE_CLEANUP.deleteModal = () => { state.deleteIdx = null; };
MODAL_STATE_CLEANUP.logWeightModal = () => { state.editGrowthEntryId = null; };
MODAL_STATE_CLEANUP.samplingEntryModal = () => { state.samplingBatchId = null; };
MODAL_STATE_CLEANUP.hapaEntryModal = () => { state.hapaEntryBatchId = null; };

function closeModal(modalId) {
  const modal = $(modalId);
  if (!modal) return;
  
  // M3 fix: clear any pending close timer so reopening during the 250ms transition doesn't re-hide
  if (modal._closeTimer) { clearTimeout(modal._closeTimer); modal._closeTimer = null; }
  
  // Auto-close fix: if the modal is already hidden, don't re-trigger the closing animation/cleanup
  // (prevents recursive loops when MODAL_STATE_CLEANUP calls closeModal again)
  if (modal.classList.contains('hidden') && !modal.classList.contains('modal-closing')) return;
  
  modal.classList.add('modal-closing');
  const sheet = modal.querySelector('.modal-sheet');
  if (sheet) {
    sheet.classList.add('modal-sheet-closing');
  }
  
  modal._closeTimer = setTimeout(() => {
    modal.classList.remove('modal-closing');
    if (sheet) {
      sheet.classList.remove('modal-sheet-closing');
    }
    modal.classList.add('hidden');
    const cleanup = MODAL_STATE_CLEANUP[modalId];
    if (cleanup) cleanup();
    modal._closeTimer = null;
  }, 250);
}

function openModal(modalId) {
  const modal = $(modalId);
  if (!modal) return;
  // M3 fix: clear any pending close timer so the modal isn't re-hidden by a stale timeout
  if (modal._closeTimer) { clearTimeout(modal._closeTimer); modal._closeTimer = null; }
  modal.classList.remove('hidden');
}

function openAppDatePicker(targetInputEl) {
  activeDatePickerTarget = targetInputEl;
  let parsedDate = new Date();
  if (targetInputEl && targetInputEl.value) {
    const parts = targetInputEl.value.split('-');
    if (parts.length === 3) {
      parsedDate = new Date(parts[0], parts[1] - 1, parts[2]);
    }
  }
  currentCalYear = parsedDate.getFullYear();
  currentCalMonth = parsedDate.getMonth();
  renderCalendarGrid(currentCalYear, currentCalMonth);
  openModal('appDatePickerModal');
}

function renderCalendarGrid(year, month) {
  currentCalYear = year;
  currentCalMonth = month;
  
  const monthNames = [
    "January", "February", "March", "April", "May", "June", 
    "July", "August", "September", "October", "November", "December"
  ];
  
  const monthLabel = $('calMonthYearLabel');
  if (monthLabel) monthLabel.textContent = `${monthNames[month]} ${year}`;
  
  const grid = $('calendarDaysGrid');
  if (!grid) return;
  grid.innerHTML = '';
  
  const firstDayIndex = new Date(year, month, 1).getDay();
  const totalDays = new Date(year, month + 1, 0).getDate();
  const prevTotalDays = new Date(year, month, 0).getDate();
  
  // Highlight selected date
  let selYear = -1, selMonth = -1, selDay = -1;
  if (activeDatePickerTarget && activeDatePickerTarget.value) {
    const parts = activeDatePickerTarget.value.split('-');
    if (parts.length === 3) {
      selYear = parseInt(parts[0], 10);
      selMonth = parseInt(parts[1], 10) - 1;
      selDay = parseInt(parts[2], 10);
    }
  }
  
  // Highlight today's date
  const today = new Date();
  const tYear = today.getFullYear();
  const tMonth = today.getMonth();
  const tDay = today.getDate();
  
  // Max date restriction
  let maxDate = null;
  if (activeDatePickerTarget && activeDatePickerTarget.max) {
    maxDate = new Date(activeDatePickerTarget.max + 'T00:00:00');
  }
  
  // Sibling month trailing days
  for (let i = firstDayIndex - 1; i >= 0; i--) {
    const dayNum = prevTotalDays - i;
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'cal-day sibling-month';
    btn.textContent = dayNum;
    btn.disabled = true;
    grid.appendChild(btn);
  }
  
  // Active month days
  for (let d = 1; d <= totalDays; d++) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'cal-day';
    btn.textContent = d;
    
    const cellDate = new Date(year, month, d);
    
    if (year === selYear && month === selMonth && d === selDay) {
      btn.classList.add('selected');
    }
    
    if (year === tYear && month === tMonth && d === tDay) {
      btn.classList.add('today');
    }
    
    if (maxDate && cellDate > maxDate) {
      btn.classList.add('disabled');
      btn.disabled = true;
    } else {
      btn.addEventListener('click', () => {
        const yyyy = year;
        const mm = String(month + 1).padStart(2, '0');
        const dd = String(d).padStart(2, '0');
        const dateVal = `${yyyy}-${mm}-${dd}`;
        
        if (activeDatePickerTarget) {
          activeDatePickerTarget.value = dateVal;
          activeDatePickerTarget.dispatchEvent(new Event('change', { bubbles: true }));
        }
        closeModal('appDatePickerModal');
      });
    }
    grid.appendChild(btn);
  }
  
  // Sibling month leading days to complete 6-week grid
  const cellsDrawn = firstDayIndex + totalDays;
  const totalCellsNeeded = 42;
  for (let n = 1; n <= (totalCellsNeeded - cellsDrawn); n++) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'cal-day sibling-month';
    btn.textContent = n;
    btn.disabled = true;
    grid.appendChild(btn);
  }
}

function bindAppDatePickers() {
  // Only hijack date inputs inside .datetime-col.date-col capsules (feed-log date capsule).
  // All other date inputs (filters, modals, inventory) keep their native browser picker.
  document.querySelectorAll('input[type="date"]').forEach(input => {
    const col = input.closest('.datetime-col.date-col');
    if (col) {
      // Inside a date capsule → use custom calendar popup
      input.setAttribute('readonly', 'true');
      input.style.pointerEvents = 'none'; // click bubbles to parent .datetime-col
      col.style.cursor = 'pointer';
      // Guard against double-binding on re-init
      if (!col.dataset.dpBound) {
        col.dataset.dpBound = '1';
        col.addEventListener('click', (e) => {
          e.preventDefault();
          openAppDatePicker(input);
        });
      }
    } else {
      // Standalone date input → restore native browser date picker, do NOT intercept
      input.removeAttribute('readonly');
      input.style.pointerEvents = '';
      input.style.cursor = '';
    }
  });
  
  $('calPrevMonthBtn')?.addEventListener('click', () => {
    currentCalMonth--;
    if (currentCalMonth < 0) {
      currentCalMonth = 11;
      currentCalYear--;
    }
    renderCalendarGrid(currentCalYear, currentCalMonth);
  });
  
  $('calNextMonthBtn')?.addEventListener('click', () => {
    currentCalMonth++;
    if (currentCalMonth > 11) {
      currentCalMonth = 0;
      currentCalYear++;
    }
    renderCalendarGrid(currentCalYear, currentCalMonth);
  });
  
  $('calCancelBtn')?.addEventListener('click', () => {
    closeModal('appDatePickerModal');
  });
  
  $('calTodayBtn')?.addEventListener('click', () => {
    const t = new Date();
    const y = t.getFullYear();
    const m = String(t.getMonth() + 1).padStart(2, '0');
    const d = String(t.getDate()).padStart(2, '0');
    const todayStr = `${y}-${m}-${d}`;
    
    if (activeDatePickerTarget) {
      activeDatePickerTarget.value = todayStr;
      activeDatePickerTarget.dispatchEvent(new Event('change', { bubbles: true }));
    }
    closeModal('appDatePickerModal');
  });
}

function initDateTimeCapsules() {
  syncDateTimeCapsule('feedDate', 'feedTime', 'feedDateDisplay', 'feedTimeDisplay', 'customTime');
  syncDateTimeCapsule('editFeedDate', 'editFeedTime', 'editFeedDateDisplay', 'editFeedTimeDisplay', 'editCustomTime');
  bindAppDatePickers();
}

function syncDateTimeCapsule(dateInputId, selectId, dateDisplayId, selectDisplayId, customTimeInputId = null) {
  const dateInput = $(dateInputId);
  const select = $(selectId);
  const dateDisplay = $(dateDisplayId);
  const selectDisplay = $(selectDisplayId);

  if (dateInput && dateDisplay) {
    const updateDate = () => {
      dateDisplay.textContent = formatInputDate(dateInput.value);
    };
    dateInput.addEventListener('change', updateDate);
    dateInput.addEventListener('input', updateDate);
    updateDate();
    
    // Intercept programmatic setting of date value
    const originalSet = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    Object.defineProperty(dateInput, 'value', {
      set: function(val) {
        originalSet.call(this, val);
        updateDate();
      },
      get: function() {
        return Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').get.call(this);
      },
      configurable: true
    });
  }

  if (select && selectDisplay) {
    const updateTime = () => {
      if (select.value === 'Other' && customTimeInputId) {
        const customTime = $(customTimeInputId);
        if (customTime && customTime.value) {
          selectDisplay.textContent = formatTime12(customTime.value);
          return;
        }
      }
      const idx = select.selectedIndex;
      const text = (idx >= 0) ? select.options[idx].textContent : 'Select Time';
      selectDisplay.textContent = text === 'Select' ? 'Select Time' : text;
    };
    select.addEventListener('change', updateTime);
    updateTime();
    
    if (customTimeInputId) {
      const customTime = $(customTimeInputId);
      if (customTime) {
        customTime.addEventListener('change', updateTime);
        customTime.addEventListener('input', updateTime);
      }
    }

    // Intercept select value programmatic changes
    const originalSelectSet = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set;
    Object.defineProperty(select, 'value', {
      set: function(val) {
        originalSelectSet.call(this, val);
        updateTime();
      },
      get: function() {
        return Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').get.call(this);
      },
      configurable: true
    });
  }
}

function showConfirm(title, message, onConfirm, opts = {}) {
  // L13 fix: null-guard all elements (was throwing if any modal element was missing)
  const modal = $('confirmModal');
  if (!modal) return;
  const iconEl = $('confirmModalIcon');
  const titleEl = $('confirmModalTitle');
  const msgEl = $('confirmModalMsg');
  const cancelBtn = $('confirmModalCancelBtn');
  const confirmBtn = $('confirmModalConfirmBtn');
  if (!titleEl || !msgEl || !confirmBtn) return;
  if (iconEl) iconEl.textContent = opts.icon || (opts.danger ? '⚠️' : 'ℹ️');
  titleEl.textContent = title;
  msgEl.textContent = message;
  if (cancelBtn) cancelBtn.textContent = opts.cancelLabel || 'Cancel';
  confirmBtn.textContent = opts.confirmLabel || 'Confirm';
  confirmBtn.className = 'pill-btn ' + (opts.danger !== false ? 'red-btn' : 'green-btn');
  _confirmCb = onConfirm || null;
  modal.classList.remove('hidden');
}

function _doConfirm() {
  // L17 fix: capture callback before closeModal, and don't call closeModal again in _cancelConfirm
  // (was triggering redundant recursive closeModal via MODAL_STATE_CLEANUP.confirmModal)
  if (_confirmCb) { const cb = _confirmCb; _confirmCb = null; cb(); }
  closeModal('confirmModal');
}

function _cancelConfirm() {
  closeModal('confirmModal');
  _confirmCb = null;
}

function initDragToClose() {
  const sheets = document.querySelectorAll('.modal-sheet');
  sheets.forEach(sheet => {
    const overlay = sheet.closest('.modal-overlay');
    if (!overlay) return;

    let startY = 0;
    let deltaY = 0;
    let isDragging = false;

    sheet.addEventListener('touchstart', (e) => {
      const rect = sheet.getBoundingClientRect();
      const touchYRelative = e.touches[0].clientY - rect.top;
      
      // If touch started in the top 44px of the sheet (where handle/header usually sits)
      if (touchYRelative >= 0 && touchYRelative <= 44) {
        startY = e.touches[0].clientY;
        deltaY = 0;
        isDragging = true;
        sheet.style.transition = 'none';
      }
    }, { passive: true });

    sheet.addEventListener('touchmove', (e) => {
      if (!isDragging) return;
      deltaY = e.touches[0].clientY - startY;
      if (deltaY > 0) {
        sheet.style.transform = `translateY(${deltaY}px)`;
        if (e.cancelable) {
          e.preventDefault();
        }
      }
    }, { passive: false });

    sheet.addEventListener('touchend', () => {
      if (!isDragging) return;
      isDragging = false;
      sheet.style.transition = '';
      if (deltaY > 100) {
        closeModal(overlay.id);
        setTimeout(() => {
          sheet.style.transform = '';
        }, 250);
      } else {
        sheet.style.transform = 'translateY(0)';
      }
    });
  });
}

function closeBarDetailModal() {
  // Kept for backward-compatibility with canvas click handlers that call it directly.
  closeModal('barDetailModal');
}

// Window bindings for backward compatibility
window.closeModal = closeModal;
window.openModal = openModal;
window.openAppDatePicker = openAppDatePicker;
window.renderCalendarGrid = renderCalendarGrid;
window.bindAppDatePickers = bindAppDatePickers;
window.initDateTimeCapsules = initDateTimeCapsules;
window.syncDateTimeCapsule = syncDateTimeCapsule;
window.showConfirm = showConfirm;
window._doConfirm = _doConfirm;
window._cancelConfirm = _cancelConfirm;
window.initDragToClose = initDragToClose;
window.closeBarDetailModal = closeBarDetailModal;
})();

// --- Module: charts.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

let activeDonutChartInstance = null;
// C5 fix: _analyticsBatchId and _analyticsChartData moved to the batch IIFE (only read/written there).
// Declaring them here caused ReferenceError when the batch IIFE tried to assign to them.

function drawNeonLineChart(canvasId, data) {
  const canvas = $(canvasId);
  if (!canvas) return;

  const N = data.length;
  if (N < 2) return;

  const TEAL      = '#00d4aa';
  const TEAL_GLOW = 'rgba(0,212,170,0.18)';
  const TEAL_DIM  = 'rgba(0,212,170,0.08)';

  const dpr = window.devicePixelRatio || 1;
  const pad = { t: 18, r: 20, b: 36, l: 50 };
  const H   = 160;
  const W   = canvas.parentElement?.clientWidth || 340;

  canvas.width        = Math.round(W * dpr);
  canvas.height       = Math.round(H * dpr);
  canvas.style.width  = W + 'px';
  canvas.style.height = H + 'px';

  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, W, H);

  const aW  = W - pad.l - pad.r;
  const aH  = H - pad.t - pad.b;
  const max = Math.max(...data.map(d => d.value), 1);

  // ── Y-axis: 3 horizontal gridlines (bottom, mid, top) ──
  const yMarks = [0.5, 1];   // fractions of max to draw (skip 0 baseline)
  ctx.font         = '10px Plus Jakarta Sans';
  ctx.textBaseline = 'middle';
  ctx.textAlign    = 'right';

  yMarks.forEach(frac => {
    const y   = pad.t + aH * (1 - frac);
    const val = frac * max;

    ctx.strokeStyle = 'rgba(255,255,255,0.05)';
    ctx.lineWidth   = 1;
    ctx.beginPath();
    ctx.moveTo(pad.l, y);
    ctx.lineTo(W - pad.r, y);
    ctx.stroke();

    ctx.fillStyle = 'rgba(139,148,158,0.6)';
    ctx.fillText(fmtGrams(val), pad.l - 6, y);
  });

  // ── Point coords ──
  const pts = data.map((d, i) => ({
    x: pad.l + (i / (N - 1)) * aW,
    y: pad.t + aH * (1 - (d.value / max)),
    v: d.value,
    doc: i + 1          // 1-based DOC number
  }));

  // ── Fill area under the curve ──
  const fillGrad = ctx.createLinearGradient(0, pad.t, 0, pad.t + aH);
  fillGrad.addColorStop(0,   'rgba(0,212,170,0.18)');
  fillGrad.addColorStop(1,   'rgba(0,212,170,0.0)');

  ctx.beginPath();
  ctx.moveTo(pts[0].x, pad.t + aH);
  pts.forEach((p, i) => {
    if (i === 0) {
      ctx.lineTo(p.x, p.y);
    } else {
      const cpx = (pts[i-1].x + p.x) / 2;
      ctx.bezierCurveTo(cpx, pts[i-1].y, cpx, p.y, p.x, p.y);
    }
  });
  ctx.lineTo(pts[N - 1].x, pad.t + aH);
  ctx.closePath();
  ctx.fillStyle = fillGrad;
  ctx.fill();

  // ── Line: soft glow pass then crisp teal pass ──
  function stroke(lw, color, blur, shadow) {
    ctx.shadowBlur  = blur;
    ctx.shadowColor = shadow;
    ctx.beginPath();
    pts.forEach((p, i) => {
      if (i === 0) {
        ctx.moveTo(p.x, p.y);
      } else {
        const cpx = (pts[i-1].x + p.x) / 2;
        ctx.bezierCurveTo(cpx, pts[i-1].y, cpx, p.y, p.x, p.y);
      }
    });
    ctx.strokeStyle = color;
    ctx.lineWidth   = lw;
    ctx.lineJoin    = 'round';
    ctx.lineCap     = 'round';
    ctx.stroke();
    ctx.shadowBlur  = 0;
  }

  stroke(8,   'rgba(0,212,170,0.2)', 14, TEAL);   // outer glow
  stroke(2,   TEAL,                   4, TEAL);   // crisp line

  // ── Dots only at start, middle, end ──
  const keyIdx = [0, Math.floor((N - 1) / 2), N - 1];
  // Deduplicate if N is tiny
  const unique = [...new Set(keyIdx)];

  unique.forEach(i => {
    const p = pts[i];

    // glow ring
    ctx.beginPath();
    ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
    ctx.fillStyle  = 'rgba(0,212,170,0.2)';
    ctx.shadowBlur = 10;
    ctx.shadowColor = TEAL;
    ctx.fill();

    // solid dot
    ctx.beginPath();
    ctx.arc(p.x, p.y, 3, 0, Math.PI * 2);
    ctx.fillStyle  = TEAL;
    ctx.shadowBlur = 0;
    ctx.fill();
  });

  // ── X-axis: labels only at start, middle, end ──
  ctx.fillStyle    = 'rgba(139,148,158,0.75)';
  ctx.font         = '10px Plus Jakarta Sans';
  ctx.textBaseline = 'top';

  unique.forEach(i => {
    const p     = pts[i];
    const label = `D${p.doc}`;
    ctx.textAlign = i === 0 ? 'left' : i === N - 1 ? 'right' : 'center';
    // Keep left/right labels from clipping
    const x = i === 0 ? pad.l : i === N - 1 ? W - pad.r : p.x;
    ctx.fillText(label, x, H - pad.b + 6);
  });
}

function drawBezierArea(ctx, pts, padT, aH, fillStyle) {
  if (pts.length < 2) return;
  ctx.beginPath();
  ctx.moveTo(pts[0].x, padT + aH);
  pts.forEach((p, i) => {
    if (i === 0) { ctx.lineTo(p.x, p.y); }
    else {
      const cpx = (pts[i-1].x + p.x) / 2;
      ctx.bezierCurveTo(cpx, pts[i-1].y, cpx, p.y, p.x, p.y);
    }
  });
  ctx.lineTo(pts[pts.length - 1].x, padT + aH);
  ctx.closePath();
  ctx.fillStyle = fillStyle;
  ctx.fill();
}

function drawBezierStroke(ctx, pts, lw, color, blur) {
  if (pts.length < 1) return;
  ctx.shadowBlur  = blur;
  ctx.shadowColor = color;
  ctx.beginPath();
  pts.forEach((p, i) => {
    if (i === 0) { ctx.moveTo(p.x, p.y); }
    else {
      const cpx = (pts[i-1].x + p.x) / 2;
      ctx.bezierCurveTo(cpx, pts[i-1].y, cpx, p.y, p.x, p.y);
    }
  });
  ctx.strokeStyle = color;
  ctx.lineWidth   = lw;
  ctx.lineJoin    = 'round';
  ctx.lineCap     = 'round';
  ctx.stroke();
  ctx.shadowBlur  = 0;
}

function drawDualAxisLineChart(canvasId, feedData, growthData, opts = {}) {
  const canvas = $(canvasId);
  if (!canvas) return;

  if (canvas._animId) {
    cancelAnimationFrame(canvas._animId);
  }

  if (opts.instant) {
    drawDualAxisLineChartBody(canvas, feedData, growthData, 1);
  } else {
    let startTime = null;
    const duration = 450; // 450ms duration

    function render(time) {
      if (startTime === null) startTime = time;
      const elapsed = time - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const easeProgress = 1 - Math.pow(1 - progress, 3); // cubic out

      drawDualAxisLineChartBody(canvas, feedData, growthData, easeProgress);

      if (progress < 1) {
        canvas._animId = requestAnimationFrame(render);
      } else {
        canvas._animId = null;
      }
    }
    canvas._animId = requestAnimationFrame(render);
  }
}

function drawDualAxisLineChartBody(canvas, feedData, growthData, progress) {
  const hasFeed   = feedData.some(d => d.value > 0);
  const hasGrowth = growthData.length >= 1;
  if (!hasFeed && !hasGrowth) return;

  const FEED_COLOR   = '#38bdf8';   // Aqua/cyan — feed
  const GROWTH_COLOR = '#10b981';   // Green — weight (used as sampling color / default weight color)
  const AMBER_COLOR  = '#f59e0b';   // Amber — visual weight

  const dpr = window.devicePixelRatio || 1;
  const pad = { t: 18, r: 54, b: 54, l: 54 }; // Top padding reduced (no legend), bottom padding increased (for bottom legend)
  const H   = 200;
  const W   = canvas.parentElement?.clientWidth || 340;

  canvas.width        = Math.round(W * dpr);
  canvas.height       = Math.round(H * dpr);
  canvas.style.width  = W + 'px';
  canvas.style.height = H + 'px';

  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, W, H);

  const aW = W - pad.l - pad.r;
  const aH = H - pad.t - pad.b;

  // ── X-axis: DOC range ──────────────────────────────────────
  const feedDOCs   = feedData.map(d => d.doc);
  const growthDOCs = growthData.map(d => d.doc);
  const allDOCsSet = [...new Set([...feedDOCs, ...growthDOCs])].sort((a, b) => a - b);
  if (!allDOCsSet.length) return;

  const minDOC  = allDOCsSet[0];
  const maxDOC  = allDOCsSet[allDOCsSet.length - 1];
  const docSpan = maxDOC - minDOC || 1;

  function xForDOC(doc) {
    return pad.l + ((doc - minDOC) / docSpan) * aW;
  }

  // ── Y scales ──────────────────────────────────────────────
  const maxFeedG  = Math.max(...feedData.map(d => d.value), 1);
  const maxWeightG = Math.max(...growthData.map(d => d.value), 1);

  let maxWeightLimit = 15;
  if (maxWeightG > 15) {
    maxWeightLimit = Math.ceil(maxWeightG / 10) * 10;
  }

  function yForFeed(g)   { return pad.t + aH * (1 - g / maxFeedG); }
  function yForWeight(g) { return pad.t + aH * (1 - g / maxWeightLimit); }

  // ── Gridlines ─────────────────────────────────────────────
  const yFracs = [0.25, 0.5, 0.75, 1.0];
  ctx.strokeStyle = 'rgba(255,255,255,0.05)';
  ctx.lineWidth   = 1;
  yFracs.forEach(fr => {
    const y = pad.t + aH * (1 - fr);
    ctx.beginPath();
    ctx.moveTo(pad.l, y);
    ctx.lineTo(W - pad.r, y);
    ctx.stroke();
  });

  // ── Left Y-axis labels: feed in kg ────────────────────────
  ctx.font         = '9px Plus Jakarta Sans';
  ctx.textBaseline = 'middle';
  ctx.textAlign    = 'right';
  ctx.fillStyle    = `rgba(56,189,248,0.65)`;
  yFracs.forEach(fr => {
    const y   = pad.t + aH * (1 - fr);
    const kg  = (fr * maxFeedG) / 1000;
    const lbl = kg >= 10 ? kg.toFixed(0) + 'kg' : kg.toFixed(1) + 'kg';
    ctx.fillText(lbl, pad.l - 6, y);
  });

  // ── Right Y-axis labels: weight in g ─────────────────────
  ctx.textAlign = 'left';
  ctx.fillStyle = `rgba(16,185,129,0.65)`;
  yFracs.forEach(fr => {
    const y = pad.t + aH * (1 - fr);
    const weightVal = fr * maxWeightLimit;
    ctx.fillText(fmtWeightG(weightVal).replace('g', ' g'), W - pad.r + 6, y);
  });

  // ── X-axis labels (select up to 5 DOC ticks) ─────────────
  const tickCount = Math.min(allDOCsSet.length, 5);
  const step      = Math.ceil(allDOCsSet.length / tickCount);
  const xTicks    = allDOCsSet.filter((_, i) => i % step === 0 || i === allDOCsSet.length - 1);

  ctx.fillStyle    = 'rgba(139,148,158,0.65)';
  ctx.textBaseline = 'top';
  ctx.textAlign    = 'center';
  ctx.font         = '9px Plus Jakarta Sans';
  xTicks.forEach(doc => {
    const x = xForDOC(doc);
    ctx.fillText(`D${doc}`, x, H - pad.b + 7);
  });

  // ── Draw Feed line ────────────────────────────────────────
  if (hasFeed && feedData.length >= 2) {
    const feedPts = feedData.map(d => {
      const targetY = yForFeed(d.value);
      return { x: xForDOC(d.doc), y: (pad.t + aH) - ((pad.t + aH) - targetY) * progress };
    });

    const fg = ctx.createLinearGradient(0, pad.t, 0, pad.t + aH);
    fg.addColorStop(0, 'rgba(56,189,248,0.14)');
    fg.addColorStop(1, 'rgba(56,189,248,0.0)');
    drawBezierArea(ctx, feedPts, pad.t, aH, fg);

    // Glow pass + crisp pass
    drawBezierStroke(ctx, feedPts, 6, 'rgba(56,189,248,0.18)', 12);
    drawBezierStroke(ctx, feedPts, 1.5, FEED_COLOR, 4);
  }

  // ── Draw Growth line ──────────────────────────────────────
  if (hasGrowth) {
    const growPts = growthData.map(d => {
      const targetY = yForWeight(d.value);
      return { x: xForDOC(d.doc), y: (pad.t + aH) - ((pad.t + aH) - targetY) * progress };
    });

    const samplingDocs = growthData.filter(d => d.source === 'sampling').map(d => d.doc);
    const firstSamplingDoc = samplingDocs.length ? Math.min(...samplingDocs) : Infinity;

    const visualPts = growPts.filter((_, i) => growthData[i].doc <= firstSamplingDoc);
    const samplingPts = growPts.filter((_, i) => growthData[i].doc >= firstSamplingDoc);

    const AMBER_GLOW = 'rgba(245, 158, 11, 0.18)';
    const GREEN_GLOW = 'rgba(16, 185, 129, 0.18)';

    // 1. Draw area fills
    if (visualPts.length >= 2) {
      const vg = ctx.createLinearGradient(0, pad.t, 0, pad.t + aH);
      vg.addColorStop(0, 'rgba(245, 158, 11, 0.14)');
      vg.addColorStop(1, 'rgba(245, 158, 11, 0.0)');
      drawBezierArea(ctx, visualPts, pad.t, aH, vg);
    }
    if (samplingPts.length >= 2) {
      const sg = ctx.createLinearGradient(0, pad.t, 0, pad.t + aH);
      sg.addColorStop(0, 'rgba(16, 185, 129, 0.14)');
      sg.addColorStop(1, 'rgba(16, 185, 129, 0.0)');
      drawBezierArea(ctx, samplingPts, pad.t, aH, sg);
    }

    // 2. Draw line strokes
    if (visualPts.length >= 2) {
      ctx.setLineDash([4, 4]);
      drawBezierStroke(ctx, visualPts, 6, AMBER_GLOW, 12);
      drawBezierStroke(ctx, visualPts, 1.5, AMBER_COLOR, 4);
      ctx.setLineDash([]);
    }
    if (samplingPts.length >= 2) {
      ctx.setLineDash([]);
      drawBezierStroke(ctx, samplingPts, 6, GREEN_GLOW, 12);
      drawBezierStroke(ctx, samplingPts, 1.5, GROWTH_COLOR, 4);
    }

    // 3. Draw dots with appropriate source color
    growPts.forEach((p, idx) => {
      const isSampling = growthData[idx].doc >= firstSamplingDoc;
      const dotColor = isSampling ? GROWTH_COLOR : AMBER_COLOR;
      const dotGlow = isSampling ? 'rgba(16, 185, 129, 0.22)' : 'rgba(245, 158, 11, 0.22)';

      ctx.beginPath();
      ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
      ctx.fillStyle   = dotGlow;
      ctx.shadowBlur  = 10;
      ctx.shadowColor = dotColor;
      ctx.fill();

      ctx.beginPath();
      ctx.arc(p.x, p.y, 2.5, 0, Math.PI * 2);
      ctx.fillStyle  = dotColor;
      ctx.shadowBlur = 0;
      ctx.fill();
    });

    // 4. Vertical transition line & "1st Sample" label
    if (firstSamplingDoc !== Infinity) {
      const transX = xForDOC(firstSamplingDoc);

      // Vertical dashed line
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
      ctx.lineWidth   = 1;
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      ctx.moveTo(transX, pad.t + aH);
      ctx.lineTo(transX, (pad.t + aH) - aH * progress);
      ctx.stroke();
      ctx.setLineDash([]);

      // Label at the top of the line
      ctx.font         = '8px Plus Jakarta Sans';
      ctx.fillStyle    = `rgba(255, 255, 255, ${0.7 * progress})`;
      ctx.textAlign    = 'center';
      ctx.textBaseline = 'bottom';
      ctx.fillText('1st Sample', transX, (pad.t + aH) - aH * progress - 4);
    }
  }

  // ── Legend ────────────────────────────────────────────────
  ctx.font         = '9px Plus Jakarta Sans';
  ctx.textBaseline = 'middle';
  const legendY    = H - 18; // Moved to the bottom of the canvas below the X-axis
  const items      = [];
  if (hasFeed)   items.push({ color: FEED_COLOR,   label: 'Feed (kg)', dash: [] });
  
  if (hasGrowth) {
    const samplingDocs = growthData.filter(d => d.source === 'sampling').map(d => d.doc);
    const hasVisual = growthData.some(d => d.source === 'visual');
    const hasSamp = samplingDocs.length > 0;

    if (hasVisual) {
      items.push({ color: AMBER_COLOR, label: 'Visual Weight (g)', dash: [3, 3] });
    }
    if (hasSamp) {
      items.push({ color: GROWTH_COLOR, label: 'Sampling Weight (g)', dash: [] });
    }
  }

  // Calculate total width of the legend to center it
  let totalLegendWidth = 0;
  items.forEach((item, idx) => {
    totalLegendWidth += 20 + ctx.measureText(item.label).width;
    if (idx < items.length - 1) {
      totalLegendWidth += 34; // spacing between items
    }
  });

  let lx = Math.max(pad.l, (W - totalLegendWidth) / 2);
  items.forEach(item => {
    // Line segment
    ctx.strokeStyle = item.color;
    ctx.lineWidth   = 2;
    ctx.shadowBlur  = 0;
    if (item.dash && item.dash.length) {
      ctx.setLineDash(item.dash);
    } else {
      ctx.setLineDash([]);
    }
    ctx.beginPath();
    ctx.moveTo(lx, legendY);
    ctx.lineTo(lx + 16, legendY);
    ctx.stroke();
    ctx.setLineDash([]); // Reset
    // Dot
    ctx.beginPath();
    ctx.arc(lx + 8, legendY, 2.5, 0, Math.PI * 2);
    ctx.fillStyle = item.color;
    ctx.fill();
    // Label
    ctx.textAlign = 'left';
    ctx.fillStyle = 'rgba(139,148,158,0.8)';
    ctx.fillText(item.label, lx + 20, legendY);
    lx += ctx.measureText(item.label).width + 34;
  });
}

function drawHorizontalBarChart(canvasId, data, opts = {}) {
  const canvas = $(canvasId);
  if (!canvas) return;
  
  const N = data.length;
  const barHeight = 24;
  const pad = { t: 15, r: 20, b: 35, l: 60 };

  const W = canvas.parentElement.clientWidth || 340;
  const H = pad.t + pad.b + N * barHeight;
  const dpr = window.devicePixelRatio || 1;
  
  canvas.width = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  canvas.style.width = W + 'px';
  canvas.style.height = H + 'px';
  
  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.scale(dpr, dpr);
  
  const aW = W - pad.l - pad.r;
  const maxVal = Math.max(...data.map(d => d.value), 100);
  
  const newSig = data.map(d => d.label + ':' + d.value).join('|');
  if (canvas._barDataSig !== newSig) {
    canvas._barDataSig    = newSig;
    canvas._barSelectedIdx = -1;
    closeBarDetailModal();
  }
  canvas._barData  = data;

  if (!canvas._barClickBound) {
    canvas._barClickBound = true;
    canvas.style.cursor = 'pointer';
    canvas.addEventListener('click', function(e) {
      const rect = canvas.getBoundingClientRect();
      const scaleX = W / (rect.width || W);
      const scaleY = H / (rect.height || H);
      const mx     = (e.clientX - rect.left) * scaleX;
      const my     = (e.clientY - rect.top) * scaleY;
      const bars  = canvas._barRects || [];
      let hit = -1;
      bars.forEach(b => {
        if (mx >= b.x && mx <= b.x + b.w && my >= b.y && my <= b.y + b.h) hit = b.idx;
      });
      if (hit >= 0) {
        const wasSelected = canvas._barSelectedIdx === hit;
        canvas._barSelectedIdx = wasSelected ? -1 : hit;
        drawHorizontalBarChart(canvasId, canvas._barData, Object.assign({}, opts, { instant: true }));
        if (!wasSelected && canvas._onBarClick) {
          canvas._onBarClick(canvas._barData[hit], hit);
        } else if (wasSelected) {
          closeBarDetailModal();
        }
      }
    });
    document.addEventListener('click', function(e) {
      if (!canvas.contains(e.target) && !$('barDetailModal')?.contains(e.target) && canvas._barSelectedIdx >= 0) {
        canvas._barSelectedIdx = -1;
        drawHorizontalBarChart(canvasId, canvas._barData, Object.assign({}, opts, { instant: true }));
        closeBarDetailModal();
      }
    });
  }

  if (canvas._animId) {
    cancelAnimationFrame(canvas._animId);
  }

  if (opts.instant) {
    const barRects = [];
    drawHorizontalBarChartBody(canvas, ctx, data, opts, pad, maxVal, W, H, aW, canvas._barSelectedIdx, 1, barRects, barHeight);
    canvas._barRects = barRects;
  } else {
    let startTime = null;
    const duration = 400;

    function render(time) {
      if (startTime === null) startTime = time;
      const elapsed = time - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const easeProgress = 1 - Math.pow(1 - progress, 3);

      const barRects = [];
      drawHorizontalBarChartBody(canvas, ctx, data, opts, pad, maxVal, W, H, aW, canvas._barSelectedIdx, easeProgress, barRects, barHeight);
      canvas._barRects = barRects;

      if (progress < 1) {
        canvas._animId = requestAnimationFrame(render);
      } else {
        canvas._animId = null;
      }
    }
    canvas._animId = requestAnimationFrame(render);
  }
}

function drawHorizontalBarChartBody(canvas, ctx, data, opts, pad, maxVal, W, H, aW, selectedIdx, progress, barRects, barHeight) {
  ctx.clearRect(0, 0, W, H);

  ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
  ctx.lineWidth = 1;
  ctx.font = '10px Plus Jakarta Sans';
  ctx.fillStyle = 'rgba(139, 148, 158, 0.55)';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  
  const ticks = 4;
  for (let i = 0; i <= ticks; i++) {
    const x = pad.l + (i / ticks) * aW;
    ctx.beginPath();
    ctx.moveTo(x, pad.t);
    ctx.lineTo(x, H - pad.b);
    ctx.stroke();
    
    const val = (i / ticks) * maxVal;
    ctx.fillText(fmtGrams(val), x, H - pad.b + 8);
  }

  data.forEach((d, idx) => {
    const y = pad.t + idx * barHeight + 4;
    const bh = 14;
    const bwFull = Math.max((d.value / maxVal) * aW, 0);
    const bw = bwFull * progress;
    const color = opts.color || '#00d4aa';
    const isSelected = idx === selectedIdx;

    barRects.push({ x: pad.l, y: y - 4, w: aW, h: barHeight, idx });

    // Selected row background highlight
    if (isSelected) {
      ctx.save();
      ctx.fillStyle = color + '15';
      ctx.beginPath();
      ctx.rect(pad.l - 4, y - 2, aW + 8, bh + 4);
      ctx.fill();
      ctx.restore();
    }
    
    ctx.fillStyle = isSelected ? color : 'rgba(139, 148, 158, 0.85)';
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.font = isSelected ? 'bold 10px Plus Jakarta Sans' : '600 10px Plus Jakarta Sans';
    ctx.fillText(d.label, pad.l - 8, y + bh / 2);
    
    if (bw > 0) {
      const grad = ctx.createLinearGradient(pad.l, y, pad.l + bw, y);
      grad.addColorStop(0, color + '44');
      grad.addColorStop(1, color);
      ctx.fillStyle = grad;
      
      const r = Math.min(4, bw / 2, bh / 2);
      roundRectH(ctx, pad.l, y, bw, bh, r);
      ctx.fill();

      // Selected bar border glow
      if (isSelected) {
        ctx.save();
        ctx.strokeStyle = color;
        ctx.lineWidth   = 1.5;
        ctx.shadowBlur  = 8;
        ctx.shadowColor = color;
        roundRectH(ctx, pad.l, y, bw, bh, r);
        ctx.stroke();
        ctx.restore();
      }
      
      ctx.fillStyle = '#f0f6fc';
      ctx.font = 'bold 9px Plus Jakarta Sans';
      ctx.textBaseline = 'middle';
      if (bw > 40) {
        ctx.textAlign = 'right';
        ctx.fillText(fmtGrams(d.value) + 'g', pad.l + bw - 6, y + bh / 2);
      } else {
        ctx.textAlign = 'left';
        ctx.fillText(fmtGrams(d.value) + 'g', pad.l + bw + 6, y + bh / 2);
      }
    } else {
      ctx.fillStyle = 'rgba(139, 148, 158, 0.4)';
      ctx.font = '9px Plus Jakarta Sans';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText('0g', pad.l + 6, y + bh / 2);
    }
  });
}

function roundRectH(ctx, x, y, w, h, r) {
  if (w <= 0) return;
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x, y + h);
  ctx.closePath();
}

function drawBarChart(canvasId, data, opts = {}) {
  const canvas = $(canvasId);
  if (!canvas) return;

  // Get true CSS pixel width; fall back to parent width or 340
  const cssW = canvas.parentElement
    ? canvas.parentElement.clientWidth - 36  // account for card padding
    : (canvas.offsetWidth || 340);
  const W = Math.max(cssW, 160);
  const H = opts.height || 160;
  const dpr = window.devicePixelRatio || 1;

  canvas.width  = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  canvas.style.width  = W + 'px';
  canvas.style.height = H + 'px';

  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0); // reset before re-scaling
  ctx.scale(dpr, dpr);

  const max = Math.max(...data.map(d => d.value), 1);

  // ── Fix #2: Mobile-first chart layout ──
  // Tighter font, lighter grid, more breathing room, rounded bars.
  // fmtGrams already returns compact forms ("1.2k" / "1.2M") so axis labels
  // stay narrow and the chart area never gets eaten on small screens.
  ctx.font = '10px "Plus Jakarta Sans", system-ui, sans-serif';
  let maxLabelW = 0;
  for (let i = 1; i <= 4; i++) {
    const lw = ctx.measureText(fmtGrams(max * i / 4)).width;
    if (lw > maxLabelW) maxLabelW = lw;
  }
  // Cap padding so it never dominates the chart area on tiny screens
  const padL = Math.min(Math.ceil(maxLabelW) + 8, Math.max(W * 0.18, 28));
  const pad = {
    t: opts.height ? 10 : 14,
    r: 8,
    b: opts.height ? 24 : 36,                          // enough room for x-axis labels
    l: padL
  };

  const aW = W - pad.l - pad.r;
  const aH = H - pad.t - pad.b;
  // ── Fix #2: Bar gap responsive — narrower bars + bigger gaps on mobile ──
  // When there are 7+ bars in a narrow viewport, use 30% gap so each bar is
  // narrower and easier to tap. Always leave at least 6px of bar width.
  const bW  = aW / data.length;
  const bGapRatio = (data.length >= 7 && W < 380) ? 0.36 : (data.length >= 5 ? 0.30 : 0.22);
  const bGap = bW * bGapRatio;
  const selectedIdx = canvas._barSelectedIdx !== undefined ? canvas._barSelectedIdx : -1;

  // Store bar hit regions for click detection
  // Reset selection when data changes (e.g. week navigation)
  const newSig = data.map(d => d.label + ':' + d.value).join('|');
  if (canvas._barDataSig !== newSig) {
    canvas._barDataSig    = newSig;
    canvas._barSelectedIdx = -1;
    closeBarDetailModal();
  }

  canvas._barData  = data;
  canvas._barPad   = pad;
  canvas._barAH    = aH;
  canvas._barOpts  = opts; // M4 fix: store opts on canvas so outside-click handler reads current values

  // Attach click handler once (idempotent via flag)
  if (!canvas._barClickBound) {
    canvas._barClickBound = true;
    canvas.style.cursor = 'pointer';
    canvas.addEventListener('click', function(e) {
      const rect   = canvas.getBoundingClientRect();
      const scaleX = W / (rect.width || W);
      const scaleY = H / (rect.height || H);
      const mx     = (e.clientX - rect.left) * scaleX;
      const my     = (e.clientY - rect.top) * scaleY;
      const bars   = canvas._barRects || [];
      const cPad   = canvas._barPad || { t: 6 };
      const cAH    = canvas._barAH  || 100;
      let hit = -1;
      bars.forEach(b => {
        // Extend tap zone to full column height for easier mobile tapping
        if (mx >= b.x && mx <= b.x + b.w && my >= cPad.t && my <= cPad.t + cAH) {
          hit = b.idx;
        }
      });
      if (hit >= 0) {
        const wasSelected = canvas._barSelectedIdx === hit;
        canvas._barSelectedIdx = wasSelected ? -1 : hit;
        // Redraw with new selection (instant, no animation)
        drawBarChart(canvasId, canvas._barData, Object.assign({}, canvas._barOpts, { instant: true })); // M4 fix: use canvas._barOpts
        if (!wasSelected && canvas._onBarClick) {
          canvas._onBarClick(canvas._barData[hit], hit);
        } else if (wasSelected) {
          closeBarDetailModal();
        }
      }
    });
    // Close on outside click
    document.addEventListener('click', function(e) {
      if (!canvas.contains(e.target) && !$('barDetailModal')?.contains(e.target) && canvas._barSelectedIdx >= 0) {
        canvas._barSelectedIdx = -1;
        // M4 fix: read opts from canvas instead of closure (was capturing stale opts from first call)
        drawBarChart(canvasId, canvas._barData, Object.assign({}, canvas._barOpts, { instant: true }));
        closeBarDetailModal();
      }
    });
  }

  if (canvas._animId) {
    cancelAnimationFrame(canvas._animId);
  }

  if (opts.instant) {
    const barRects = [];
    drawBarChartBody(canvas, ctx, data, opts, pad, max, W, H, aW, aH, bW, bGap, canvas._barSelectedIdx, 1, barRects);
    canvas._barRects = barRects;
  } else {
    let startTime = null;
    const duration = 400; // 400ms duration

    function render(time) {
      if (startTime === null) startTime = time;
      const elapsed = time - startTime;
      const progress = Math.min(elapsed / duration, 1);
      // Cubic Out easing function
      const easeProgress = 1 - Math.pow(1 - progress, 3);

      const barRects = [];
      drawBarChartBody(canvas, ctx, data, opts, pad, max, W, H, aW, aH, bW, bGap, canvas._barSelectedIdx, easeProgress, barRects);
      canvas._barRects = barRects;

      if (progress < 1) {
        canvas._animId = requestAnimationFrame(render);
      } else {
        canvas._animId = null;
      }
    }
    canvas._animId = requestAnimationFrame(render);
  }
}

function drawBarChartBody(canvas, ctx, data, opts, pad, max, W, H, aW, aH, bW, bGap, selectedIdx, progress, barRects) {
  ctx.clearRect(0, 0, W, H);

  // ── Fix #2: Lighter grid, cleaner typography ──
  // Grid lines: dashed, very faint. Y-axis labels: smaller, dimmer.
  ctx.strokeStyle = 'rgba(255,255,255,.04)';
  ctx.lineWidth   = 1;
  ctx.font        = '9px "Plus Jakarta Sans", system-ui, sans-serif';
  ctx.textBaseline = 'middle';
  // Only draw 4 grid lines (i=0..4) — top + 3 intermediate + baseline.
  // Skip the bottom line (i=0) to let the bar baseline stand out.
  for (let i = 0; i <= 4; i++) {
    const y = pad.t + aH * (1 - i / 4);
    if (i > 0 && i < 4) {
      // Dashed intermediate grid lines
      ctx.save();
      ctx.setLineDash([2, 3]);
      ctx.beginPath();
      ctx.moveTo(pad.l, y);
      ctx.lineTo(W - pad.r, y);
      ctx.stroke();
      ctx.restore();
    } else if (i === 0) {
      // Solid baseline
      ctx.strokeStyle = 'rgba(255,255,255,.08)';
      ctx.beginPath();
      ctx.moveTo(pad.l, y);
      ctx.lineTo(W - pad.r, y);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,.04)';
    }
    if (i > 0) {
      ctx.fillStyle  = 'rgba(139,148,158,.45)';
      ctx.textAlign  = 'right';
      ctx.fillText(fmtGrams(max * i / 4), pad.l - 5, y);
    }
  }

  // Bars + x-axis labels
  data.forEach((d, i) => {
    const barX  = pad.l + i * bW + bGap / 2;
    const barW  = bW - bGap;
    const bhFull = Math.max((d.value / max) * aH, 0);
    const bh    = bhFull * progress;
    const barY  = pad.t + aH - bh;
    const color = opts.color || '#00d4aa';
    const isSelected = i === selectedIdx;

    const barYFull = pad.t + aH - bhFull;
    barRects.push({ x: barX, y: barYFull, w: barW, h: Math.max(bhFull, 6), idx: i });

    // Subtle glow backdrop for selected bar
    if (isSelected) {
      ctx.save();
      ctx.shadowBlur  = 14;
      ctx.shadowColor = color;
      ctx.fillStyle   = color + '22';
      roundRect(ctx, barX - 2, pad.t, barW + 4, aH, 6);
      ctx.fill();
      ctx.restore();
    }

    // Bar gradient — slightly brighter when selected
    const grad = ctx.createLinearGradient(barX, barY, barX, pad.t + aH);
    if (isSelected) {
      grad.addColorStop(0, color);
      grad.addColorStop(1, color + '55');
    } else {
      grad.addColorStop(0, color);
      grad.addColorStop(1, color + '33');
    }
    ctx.fillStyle = grad;
    // ── Fix #2: Rounded top corners only (cleaner premium look) ──
    const r = Math.min(6, barW / 2, bh > 0 ? bh / 2 : 6);
    roundRectTop(ctx, barX, barY, barW, bh, r);
    ctx.fill();

    // Selected border highlight
    if (isSelected && bh > 0) {
      ctx.strokeStyle = color;
      ctx.lineWidth   = 1.5;
      ctx.save();
      ctx.shadowBlur  = 6;
      ctx.shadowColor = color;
      roundRectTop(ctx, barX, barY, barW, bh, r);
      ctx.stroke();
      ctx.restore();
    }

    // X-axis label — sits below the chart area, never overlaps bars
    ctx.fillStyle    = isSelected ? color : 'rgba(139,148,158,.75)';
    ctx.font         = isSelected ? 'bold 10px "Plus Jakarta Sans", system-ui' : '10px "Plus Jakarta Sans", system-ui';
    ctx.textAlign    = 'center';
    ctx.textBaseline = 'top';
    // Clip label to barW to prevent overflow on narrow screens
    const labelX = barX + barW / 2;
    const labelY = pad.t + aH + 8;
    ctx.save();
    ctx.beginPath();
    ctx.rect(barX - 2, labelY, barW + 4, pad.b - 8);
    ctx.clip();
    ctx.fillText(d.label, labelX, labelY);
    ctx.restore();

    // Value label inside bar (only when tall enough)
    if (bh > 22 && d.value > 0) {
      ctx.fillStyle    = 'rgba(0,0,0,.75)';
      ctx.font         = 'bold 9px "Plus Jakarta Sans", system-ui';
      ctx.textAlign    = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText(fmtGrams(d.value), barX + barW / 2, barY + 5);
    }
  });

  ctx.textBaseline = 'alphabetic'; // restore default
}

// ── Fix #2: Rounded top corners only — flat bottom for cleaner baseline ──
function roundRectTop(ctx, x, y, w, h, r) {
  if (h <= 0) return;
  r = Math.min(r, h / 2, w / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h);
  ctx.lineTo(x, y + h);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function roundRect(ctx, x, y, w, h, r) {
  if (h <= 0) return;
  r = Math.min(r, h/2, w/2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x+w, y, x+w, y+r);
  ctx.lineTo(x+w, y+h);
  ctx.lineTo(x, y+h);
  ctx.lineTo(x, y+r);
  ctx.quadraticCurveTo(x, y, x+r, y);
  ctx.closePath();
}

function drawDonutChart(canvasId, data) {
  // Initialise singleton on first call
  if (!activeDonutChartInstance) {
    activeDonutChartInstance = new AqlDistributionCard();
  }

  const select  = document.getElementById('dashboardContextSelect');
  const context = select ? select.value : 'farm';

  if (context === 'farm') {
    // Farm view — all-time records
    activeDonutChartInstance.update(records, null);

    // Update subtitle dynamically
    const subEl = document.getElementById('aqlDistSub');
    if (subEl) subEl.textContent = 'All Time';

  } else if (context.startsWith('batch_')) {
    const batchId = context.replace('batch_', '');
    const batch   = batches.find(b => b.id === batchId);
    const batchRecs = batch ? records.filter(r => r.BatchId === batchId) : (data || []);

    if (batchRecs.length === 0 || (data && data.length === 0)) {
      activeDonutChartInstance.clear(batch || null);
    } else {
      activeDonutChartInstance.update(batchRecs, batch || null);
    }

    // Update subtitle
    const subEl = document.getElementById('aqlDistSub');
    if (subEl && batch) {
      const doc = calcDOC(batch.stockingDate);
      subEl.textContent = batch.status === 'completed' ? 'Completed Batch' : `Batch #${batch.batchNumber} · DOC ${doc}`;
    }
  }

  // ARIA label on canvas (legacy compatibility)
  const canvas = document.getElementById(canvasId);
  if (canvas) {
    canvas.setAttribute('role', 'img');
  }
}

function drawAnalyticsGrowthCanvas(canvas, timeline, batch, opts = {}) {
  if (!canvas) return;

  if (canvas._animId) {
    cancelAnimationFrame(canvas._animId);
  }

  if (opts.instant) {
    drawAnalyticsGrowthCanvasBody(canvas, timeline, batch, 1);
  } else {
    let startTime = null;
    const duration = 450;

    function render(time) {
      if (startTime === null) startTime = time;
      const elapsed = time - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const easeProgress = 1 - Math.pow(1 - progress, 3); // cubic out

      drawAnalyticsGrowthCanvasBody(canvas, timeline, batch, easeProgress);

      if (progress < 1) {
        canvas._animId = requestAnimationFrame(render);
      } else {
        canvas._animId = null;
      }
    }
    canvas._animId = requestAnimationFrame(render);
  }
}

function drawAnalyticsGrowthCanvasBody(canvas, timeline, batch, progress) {
  const dpr  = window.devicePixelRatio || 1;
  const pad  = { t: 24, r: 16, b: 36, l: 44 };
  const H    = 180;
  const W    = canvas.parentElement?.clientWidth || 340;

  canvas.width  = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  canvas.style.width  = W + 'px';
  canvas.style.height = H + 'px';

  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, W, H);

  const aW  = W - pad.l - pad.r;
  const aH  = H - pad.t - pad.b;
  const values = timeline.map(t => t.abw);
  const maxV = Math.max(...values, 1);
  const minV = Math.max(0, Math.min(...values) - 1);

  // Projection: compute daily growth from last 2 samplings
  const samplings = timeline.filter(t => t.source === 'sampling');
  let projected = [];
  if (batch.status === 'active' && samplings.length >= 1) {
    const lastS = samplings[samplings.length - 1];
    const dailyG = lastS.entry?.dailyGrowth || getLatestDailyGrowth(batch) || 0;
    const today  = fmt(new Date());
    const currentDoc = calcDOC(batch.stockingDate);
    // Project 21 days
    for (let d = 1; d <= 21; d++) {
      const futureDoc = lastS.doc + d;
      const futureAbw = lastS.abw + dailyG * d;
      const futureDateObj = startOfDay(lastS.date);
      futureDateObj.setDate(futureDateObj.getDate() + d);
      projected.push({ doc: futureDoc, abw: Math.max(0.001, futureAbw), date: fmt(futureDateObj) });
    }
  }

  const allDocs  = [...timeline.map(t => t.doc), ...projected.map(p => p.doc)];
  const allABWs  = [...values, ...projected.map(p => p.abw)];
  const docMin   = Math.min(...allDocs);
  const docMax   = Math.max(...allDocs);
  const abwRange = Math.max(...allABWs, 1) - Math.max(0, Math.min(...allABWs) - 1);
  const abwMax   = Math.max(...allABWs, 1);
  const abwMin   = Math.max(0, Math.min(...allABWs) - 1);

  function xPos(doc) {
    const span = docMax - docMin || 1;
    return pad.l + ((doc - docMin) / span) * aW;
  }
  function yPos(abw) {
    const span = abwMax - abwMin || 1;
    return pad.t + (1 - (abw - abwMin) / span) * aH;
  }

  // Helper to scale Y position based on progress
  function yPosAnimated(abw) {
    const targetY = yPos(abw);
    return (H - pad.b) - ((H - pad.b) - targetY) * progress;
  }

  // ── Y gridlines ──
  const yTicks = 3;
  ctx.font         = '9.5px Plus Jakarta Sans, sans-serif';
  ctx.textBaseline = 'middle';
  ctx.textAlign    = 'right';
  ctx.fillStyle    = 'rgba(139,148,158,0.6)';
  for (let i = 0; i <= yTicks; i++) {
    const frac = i / yTicks;
    const abwV = abwMin + frac * (abwMax - abwMin);
    const y    = yPos(abwV);
    ctx.strokeStyle = 'rgba(255,255,255,0.04)';
    ctx.lineWidth   = 1;
    ctx.beginPath(); ctx.moveTo(pad.l, y); ctx.lineTo(W - pad.r, y); ctx.stroke();
    ctx.fillText(abwV.toFixed(1) + 'g', pad.l - 4, y);
  }

  // ── Projection fill ──
  if (projected.length >= 2) {
    const lastTimeline = timeline[timeline.length - 1];
    ctx.beginPath();
    ctx.moveTo(xPos(lastTimeline.doc), yPosAnimated(lastTimeline.abw));
    projected.forEach(p => ctx.lineTo(xPos(p.doc), yPosAnimated(p.abw)));
    ctx.lineTo(xPos(projected[projected.length - 1].doc), H - pad.b);
    ctx.lineTo(xPos(lastTimeline.doc), H - pad.b);
    ctx.closePath();
    ctx.fillStyle = 'rgba(167,139,250,0.07)';
    ctx.fill();

    // Projection dashed line
    ctx.save();
    ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.moveTo(xPos(lastTimeline.doc), yPosAnimated(lastTimeline.abw));
    projected.forEach(p => ctx.lineTo(xPos(p.doc), yPosAnimated(p.abw)));
    ctx.strokeStyle = 'rgba(167,139,250,0.55)';
    ctx.lineWidth   = 1.5;
    ctx.stroke();
    ctx.restore();
  }

  // ── Visual line (yellow/amber) ──
  const visPoints = timeline.filter(t => t.source === 'visual');
  if (visPoints.length >= 2) {
    ctx.beginPath();
    visPoints.forEach((t, i) => {
      const x = xPos(t.doc), y = yPosAnimated(t.abw);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.strokeStyle = 'rgba(245,158,11,0.65)';
    ctx.lineWidth   = 2;
    ctx.lineJoin    = 'round';
    ctx.stroke();
  }

  // ── Sampling line (cyan/blue) ──
  const sampPts = timeline.filter(t => t.source === 'sampling');
  if (sampPts.length >= 1) {
    // If first sampling comes after visual data, connect the two
    if (visPoints.length && sampPts.length) {
      const lastVis  = visPoints[visPoints.length - 1];
      const firstSmp = sampPts[0];
      ctx.beginPath();
      ctx.moveTo(xPos(lastVis.doc), yPosAnimated(lastVis.abw));
      ctx.lineTo(xPos(firstSmp.doc), yPosAnimated(firstSmp.abw));
      ctx.strokeStyle = 'rgba(56,189,248,0.25)';
      ctx.lineWidth   = 1;
      ctx.setLineDash([3, 3]);
      ctx.stroke();
      ctx.setLineDash([]);
    }
    if (sampPts.length >= 2) {
      ctx.beginPath();
      sampPts.forEach((t, i) => {
        const x = xPos(t.doc), y = yPosAnimated(t.abw);
        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });
      ctx.strokeStyle = '#38bdf8';
      ctx.lineWidth   = 2;
      ctx.lineJoin    = 'round';
      ctx.shadowBlur  = 6;
      ctx.shadowColor = 'rgba(56,189,248,0.4)';
      ctx.stroke();
      ctx.shadowBlur  = 0;
    }
  }

  // ── Draw dots + store click coords ──
  const ptCoords = [];
  timeline.forEach(t => {
    const x = xPos(t.doc), yFinal = yPos(t.abw);
    const y = yPosAnimated(t.abw);
    const color = t.source === 'visual' ? '#f59e0b' : '#38bdf8';
    
    // Cache final coordinates for clicks
    ptCoords.push({ x, y: yFinal });

    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.fillStyle   = color;
    ctx.shadowBlur  = 8;
    ctx.shadowColor = color;
    ctx.fill();
    ctx.shadowBlur  = 0;
    // White ring
    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.3)';
    ctx.lineWidth   = 1;
    ctx.stroke();
  });
  canvas._pts = ptCoords;

  // ── X-axis labels ──
  ctx.fillStyle    = 'rgba(139,148,158,0.7)';
  ctx.font         = '9.5px Plus Jakarta Sans, sans-serif';
  ctx.textBaseline = 'top';
  ctx.textAlign    = 'center';
  const xLabelIdxs = [0, Math.floor(timeline.length / 2), timeline.length - 1];
  const seen = new Set();
  xLabelIdxs.forEach(i => {
    if (i < 0 || i >= timeline.length || seen.has(i)) return;
    seen.add(i);
    const t = timeline[i];
    ctx.fillText(`D${t.doc}`, xPos(t.doc), H - pad.b + 4);
  });
}

function drawBiomassCanvas(canvas, bioTimeline, projected, opts = {}) {
  if (!canvas) return;

  if (canvas._animId) {
    cancelAnimationFrame(canvas._animId);
  }

  if (opts.instant) {
    drawBiomassCanvasBody(canvas, bioTimeline, projected, 1);
  } else {
    let startTime = null;
    const duration = 450;

    function render(time) {
      if (startTime === null) startTime = time;
      const elapsed = time - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const easeProgress = 1 - Math.pow(1 - progress, 3); // cubic out

      drawBiomassCanvasBody(canvas, bioTimeline, projected, easeProgress);

      if (progress < 1) {
        canvas._animId = requestAnimationFrame(render);
      } else {
        canvas._animId = null;
      }
    }
    canvas._animId = requestAnimationFrame(render);
  }
}

function drawBiomassCanvasBody(canvas, bioTimeline, projected, progress) {
  const dpr  = window.devicePixelRatio || 1;
  const pad  = { t: 24, r: 16, b: 36, l: 52 };
  const H    = 160;
  const W    = canvas.parentElement?.clientWidth || 340;

  canvas.width  = Math.round(W * dpr);
  canvas.height = Math.round(H * dpr);
  canvas.style.width  = W + 'px';
  canvas.style.height = H + 'px';

  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, W, H);

  const aW = W - pad.l - pad.r;
  const aH = H - pad.t - pad.b;

  const allBio  = [...bioTimeline.map(b => b.biomassKg), ...projected.map(p => p.biomassKg)];
  const allDocs = [...bioTimeline.map(b => b.doc), ...projected.map(p => p.doc)];
  const bioMax  = Math.max(...allBio, 1);
  const bioMin  = 0;
  const docMin  = Math.min(...allDocs);
  const docMax  = Math.max(...allDocs);

  function xPos(doc) { return pad.l + ((doc - docMin) / (docMax - docMin || 1)) * aW; }
  function yPos(b)   { return pad.t + (1 - (b - bioMin) / (bioMax - bioMin || 1)) * aH; }

  // Helper to scale Y position based on progress
  function yPosAnimated(b) {
    const targetY = yPos(b);
    return (H - pad.b) - ((H - pad.b) - targetY) * progress;
  }

  // Y gridlines
  ctx.font         = '9.5px Plus Jakarta Sans, sans-serif';
  ctx.textBaseline = 'middle';
  ctx.textAlign    = 'right';
  ctx.fillStyle    = 'rgba(139,148,158,0.6)';
  [0.5, 1.0].forEach(frac => {
    const bVal = frac * bioMax;
    const y    = yPos(bVal);
    ctx.strokeStyle = 'rgba(255,255,255,0.04)';
    ctx.lineWidth   = 1;
    ctx.beginPath(); ctx.moveTo(pad.l, y); ctx.lineTo(W - pad.r, y); ctx.stroke();
    const label = bVal >= 1000 ? (bVal / 1000).toFixed(1) + 'T' : Math.round(bVal) + 'kg';
    ctx.fillText(label, pad.l - 4, y);
  });

  // Actual biomass area fill
  if (bioTimeline.length >= 2) {
    const grad = ctx.createLinearGradient(0, pad.t, 0, pad.t + aH);
    grad.addColorStop(0, 'rgba(167,139,250,0.2)');
    grad.addColorStop(1, 'rgba(167,139,250,0.02)');
    ctx.beginPath();
    ctx.moveTo(xPos(bioTimeline[0].doc), H - pad.b);
    bioTimeline.forEach(b => ctx.lineTo(xPos(b.doc), yPosAnimated(b.biomassKg)));
    ctx.lineTo(xPos(bioTimeline[bioTimeline.length - 1].doc), H - pad.b);
    ctx.closePath();
    ctx.fillStyle = grad;
    ctx.fill();
  }

  // Actual biomass line
  if (bioTimeline.length >= 1) {
    ctx.beginPath();
    bioTimeline.forEach((b, i) => {
      const x = xPos(b.doc), y = yPosAnimated(b.biomassKg);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.strokeStyle = '#a78bfa';
    ctx.lineWidth   = 2;
    ctx.lineJoin    = 'round';
    ctx.shadowBlur  = 6;
    ctx.shadowColor = 'rgba(167,139,250,0.5)';
    ctx.stroke();
    ctx.shadowBlur  = 0;
  }

  // Projected forecast dashed
  if (projected.length >= 2) {
    const lastB = bioTimeline[bioTimeline.length - 1];
    ctx.save();
    ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.moveTo(xPos(lastB.doc), yPosAnimated(lastB.biomassKg));
    projected.forEach(p => ctx.lineTo(xPos(p.doc), yPosAnimated(p.biomassKg)));
    ctx.strokeStyle = 'rgba(167,139,250,0.45)';
    ctx.lineWidth   = 1.5;
    ctx.stroke();
    ctx.restore();
  }

  // Dots on actual biomass points
  bioTimeline.forEach(b => {
    const x = xPos(b.doc), y = yPosAnimated(b.biomassKg);
    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.fillStyle   = '#a78bfa';
    ctx.shadowBlur  = 8;
    ctx.shadowColor = 'rgba(167,139,250,0.6)';
    ctx.fill();
    ctx.shadowBlur  = 0;
    ctx.beginPath();
    ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.25)';
    ctx.lineWidth   = 1;
    ctx.stroke();
  });

  // X labels
  ctx.fillStyle    = 'rgba(139,148,158,0.7)';
  ctx.font         = '9.5px Plus Jakarta Sans, sans-serif';
  ctx.textBaseline = 'top';
  ctx.textAlign    = 'center';
  [0, Math.floor(bioTimeline.length / 2), bioTimeline.length - 1].forEach(i => {
    if (i < 0 || i >= bioTimeline.length) return;
    const b = bioTimeline[i];
    ctx.fillText(`D${b.doc}`, xPos(b.doc), H - pad.b + 4);
  });

  // Forecast badge
  if (projected.length) {
    ctx.fillStyle = 'rgba(139,148,158,0.5)';
    ctx.font      = '9px Plus Jakarta Sans, sans-serif';
    ctx.textAlign = 'right';
    ctx.textBaseline = 'top';
    ctx.fillText('— Forecast', W - pad.r, pad.t - 4);
  }
}

function last7DaysData() {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = fmt(d);
    const recs = records.filter(r => r.Date === key);
    days.push({ label: d.toLocaleDateString('en-IN',{weekday:'short'}), value: sumGrams(recs) });
  }
  return days;
}

class AqlDistributionCard {
  constructor() {
    this.chartInstance = null;
    this.currentKey    = 'size';
    this.activeIdx     = -1;
    this._currentViewData = { size: [], pond: [], phase: [] };
    this._currentRecs  = [];
    this._currentBatch = null;
    this._popoverPinned = false;
    this._initialized  = false;
  }

  /* Public: called exactly where drawDonutChart was called */
  update(recs, batch = null) {
    this._currentRecs  = recs  || [];
    this._currentBatch = batch || null;
    this.activeIdx     = -1;

    // Task 3-c: detect canvas replacement (e.g. after React re-mount of
    // body.html or DOM re-flow) and force _init() to re-create the
    // Chart.js instance against the fresh canvas — otherwise the singleton
    // would keep updating an orphaned, detached canvas.
    this._ensureFreshCanvas();
    if (!this._initialized) this._init();
    this._syncSegmentOptions();
    this._hidePopover();
    this._refreshAllViews();
    this._applyState(this.currentKey, -1);
    this._updateSummaryBox();
  }

  /* Destroy chart on empty data */
  clear(batch = null) {
    this._currentRecs  = [];
    this._currentBatch = batch || null;
    this.activeIdx     = -1;
    this._ensureFreshCanvas();
    if (!this._initialized) this._init();
    this._syncSegmentOptions();
    this._hidePopover();
    this._refreshAllViews();
    this._applyState(this.currentKey, -1);
    this._showEmptyIfNeeded();
    this._updateSummaryBox();
  }

  /* ── Private ─────────────────────────────────────────── */

  /*
   * _ensureFreshCanvas — Task 3-c.
   * If the live DOM canvas (#chartDonut) differs from the canvas this
   * singleton's Chart.js instance was built against, destroy the stale
   * instance and clear the _initialized flag so _init() rebuilds it.
   * Guards against leaks and "Canvas is already in use" warnings when
   * body.html is re-injected (React re-mount / hot reload).
   */
  _ensureFreshCanvas() {
    if (!this._initialized || !this.chartInstance) return;
    const liveCanvas = document.getElementById('chartDonut');
    if (!liveCanvas) return;
    const boundCanvas = this.chartInstance.canvas;
    if (boundCanvas && boundCanvas !== liveCanvas) {
      try { this.chartInstance.destroy(); } catch (e) { /* ignore */ }
      this.chartInstance = null;
      this._initialized  = false;
    }
  }

  _init() {
    this._initialized = true;
    const seg = document.getElementById('aqlDistSeg');
    if (seg) {
      seg.addEventListener('click', e => {
        const btn = e.target.closest('.aql-sb');
        if (!btn || btn.classList.contains('on') || btn.classList.contains('hidden')) return;
        this.currentKey = btn.dataset.k;
        this.activeIdx  = -1;
        this._hidePopover();
        seg.querySelectorAll('.aql-sb').forEach(b => b.classList.remove('on'));
        btn.classList.add('on');
        this._applyState(this.currentKey, -1);
      });
    }

    // Build Chart.js instance
    const canvas = document.getElementById('chartDonut');
    if (!canvas) return;

    // Remove old aria cruft that referred to canvas dimensions
    canvas.removeAttribute('width');
    canvas.removeAttribute('height');

    this.chartInstance = safeChart(canvas, {
      type: 'doughnut',
      data: {
        labels: [],
        datasets: [{
          data: [],
          backgroundColor: [],
          borderColor: '#1e2a3a',
          borderWidth: 3,
          hoverOffset: 12,
          hoverBorderWidth: 3,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '72%',
        animation: { duration: 550, easing: 'easeInOutQuart' },
        plugins: { legend: { display: false }, tooltip: { enabled: false } },
        layout: { padding: 8 },
        onClick: (evt, elements) => {
          const idx = elements.length ? elements[0].index : -1;
          const wasPinned = this._popoverPinned && idx === this.activeIdx;
          this.activeIdx = (idx !== -1 && !wasPinned) ? idx : -1;
          this._applyState(this.currentKey, this.activeIdx);
          if (this.activeIdx === -1) this._hidePopover();
          else this._showPopover(this.currentKey, this.activeIdx, evt, true);
        },
        onHover: (evt, elements) => {
          canvas.style.cursor = elements.length ? 'pointer' : 'default';
          if (this._popoverPinned) return;
          const idx = elements.length ? elements[0].index : -1;
          if (idx === -1) this._hidePopover();
          else this._showPopover(this.currentKey, idx, evt, false);
        },
      }
    });

    canvas.addEventListener('mouseleave', () => {
      if (!this._popoverPinned) this._hidePopover();
    });
  }

  _syncSegmentOptions() {
    const seg = document.getElementById('aqlDistSeg');
    if (!seg) return;

    const isBatchView = !!this._currentBatch;
    const pondBtn = seg.querySelector('.aql-sb[data-k="pond"]');
    if (pondBtn) {
      pondBtn.classList.toggle('hidden', isBatchView);
      pondBtn.setAttribute('aria-hidden', isBatchView ? 'true' : 'false');
      pondBtn.tabIndex = isBatchView ? -1 : 0;
    }

    const phaseBtn = seg.querySelector('.aql-sb[data-k="phase"]');
    if (phaseBtn) {
      phaseBtn.classList.toggle('hidden', !isBatchView);
      phaseBtn.setAttribute('aria-hidden', isBatchView ? 'false' : 'true');
      phaseBtn.tabIndex = isBatchView ? 0 : -1;
    }

    if ((isBatchView && this.currentKey === 'pond') || (!isBatchView && this.currentKey === 'phase')) {
      this.currentKey = 'size';
      this.activeIdx = -1;
    }

    seg.querySelectorAll('.aql-sb').forEach(btn => {
      btn.classList.toggle('on', btn.dataset.k === this.currentKey);
    });
  }

  _refreshAllViews() {
    const recs  = this._currentRecs;
    const batch = this._currentBatch;
    this._currentViewData.size  = feedSizeDistribution(recs);
    this._currentViewData.pond  = pondFeedDistribution(recs);
    this._currentViewData.phase = phaseFeedDistribution(recs, batch);
  }

  _applyState(key, idx) {
    const data    = this._currentViewData[key] || [];
    const total   = data.reduce((s, d) => s + d.value, 0);
    const isEmpty = data.length === 0 || total === 0;

    this._updateCard(isEmpty);
    if (isEmpty) {
      this._clearChart();
      this._updateKpi(key, idx, data, total);
      this._buildRows(key, idx, data, total);
      this._buildDetail(key, idx, data);
      this._updateFooter(key, idx, data, total);
      return;
    }

    // Chart
    if (this.chartInstance) {
      this.chartInstance.data.labels = data.map(d => d.label);
      this.chartInstance.data.datasets[0].data = data.map(d => d.value);
      this.chartInstance.data.datasets[0].backgroundColor = data.map((d, i) => {
        if (idx === -1)    return d.color + 'bb';
        return i === idx ? d.color + 'ee' : d.color + '22';
      });
      this.chartInstance.data.datasets[0].borderColor = data.map((d, i) =>
        i === idx ? d.color : '#1e2a3a'
      );
      this.chartInstance.update();
    }

    this._updateKpi(key, idx, data, total);
    this._buildRows(key, idx, data, total);
    this._buildDetail(key, idx, data);
    this._updateFooter(key, idx, data, total);

    // ARIA
    const canvas = document.getElementById('chartDonut');
    if (canvas) {
      const desc = data.map(d => {
        const pct = total > 0 ? ((d.value / total) * 100).toFixed(1) : 0;
        return `${d.label}: ${this._fmtVal(d.value)} (${pct}%)`;
      }).join(', ');
      canvas.setAttribute('aria-label', `Distribution chart. ${desc}`);
    }
  }

  _clearChart() {
    if (!this.chartInstance) return;
    this.chartInstance.data.labels   = [];
    this.chartInstance.data.datasets[0].data            = [];
    this.chartInstance.data.datasets[0].backgroundColor = [];
    this.chartInstance.update();
  }

  _updateCard(isEmpty) {
    const card  = document.getElementById('aqlDistCard');
    const empty = document.getElementById('aqlDistEmpty');

    // Remove stale empty state
    if (!isEmpty && empty) empty.remove();

    if (isEmpty && card && !document.getElementById('aqlDistEmpty')) {
      const div = document.createElement('div');
      div.id        = 'aqlDistEmpty';
      div.className = 'aql-dist-empty';
      div.innerHTML = `<div class="aql-dist-empty-icon">📊</div>
        <div class="aql-dist-empty-title">No Records Available</div>
        <div class="aql-dist-empty-sub">Add feed records to generate analytics</div>`;
      // Insert before the footer
      const footer = document.getElementById('aqlDistFooter');
      if (footer) card.insertBefore(div, footer);
      else card.appendChild(div);
    }
  }

  _updateKpi(key, idx, data, total) {
    const eyeEl  = document.getElementById('aqlDistKpiEye');
    const valEl  = document.getElementById('aqlDistKpiVal');
    const unitEl = document.getElementById('aqlDistKpiUnit');
    if (!eyeEl || !valEl || !unitEl) return;

    if (idx === -1 || data.length === 0) {
      const defaults = {
        size:  { eye: 'Total feed', unit: 'kg · all sizes' },
        pond:  { eye: 'Active ponds', unit: `${data.length} pond${data.length !== 1 ? 's' : ''}` },
        phase: { eye: 'Phase',       unit: 'by DOC' },
      };
      const def = defaults[key] || defaults.size;
      eyeEl.textContent  = def.eye;
      eyeEl.style.color  = '';
      unitEl.textContent = def.unit;
      unitEl.style.color = '';

      if (total === 0) {
        valEl.textContent = '—';
        valEl.style.color = '';
      } else if (key === 'pond') {
        valEl.textContent = String(data.length);
        valEl.style.color = '';
      } else {
        const kg = total / 1000;
        valEl.textContent = kg >= 1 ? kg.toFixed(1) : Math.round(total).toString();
        valEl.style.color = '';
      }
    } else {
      const d   = data[idx];
      const col = d.color;
      const pct = total > 0 ? Math.round((d.value / total) * 100) : 0;
      const raw = this._fmtVal(d.value);
      const numPart  = raw.split(' ')[0];
      const unitPart = raw.includes('kg') ? 'kg' : 'g';

      eyeEl.textContent  = d.label;
      eyeEl.style.color  = col;
      valEl.textContent  = numPart;
      valEl.style.color  = '';
      unitEl.textContent = `${unitPart} · ${pct}%`;
      unitEl.style.color = col;
    }
  }

  _buildRows(key, idx, data, total) {
    const container = document.getElementById('aqlDistRows');
    if (!container) return;
    container.innerHTML = '';
    if (!data.length) return;

    data.forEach((d, i) => {
      const pct = total > 0 ? Math.round((d.value / total) * 100) : 0;
      const col = d.color;
      let cls   = 'aql-dist-ri';
      if (idx !== -1) cls += i === idx ? ' hi' : ' dim';

      const row = document.createElement('div');
      row.className = cls;
      row.innerHTML = `
        <span class="aql-dist-rdot" style="background:${col};${idx===i?'box-shadow:0 0 8px '+col+'88':''}"></span>
        <span class="aql-dist-rl">${d.label.replace('Feed Size ', 'FS ')}</span>
        <div class="aql-dist-rtrack">
          <div class="aql-dist-rt-fill" style="width:${pct}%;background:${col}"></div>
          <div class="aql-dist-rt-pip" style="background:${col}"></div>
        </div>
        <span class="aql-dist-rpm" style="color:${(idx===-1||idx===i)?col:'#2d3748'}">${pct}%</span>
        <span class="aql-dist-ramt">${this._fmtVal(d.value)}</span>`;
      row.addEventListener('click', e => {
        const wasPinned = this._popoverPinned && this.activeIdx === i;
        this.activeIdx = wasPinned ? -1 : i;
        this._applyState(key, this.activeIdx);
        if (this.activeIdx === -1) this._hidePopover();
        else this._showPopover(key, i, e, true);
      });
      row.addEventListener('mouseenter', e => {
        if (!this._popoverPinned) this._showPopover(key, i, e, false);
      });
      row.addEventListener('mouseleave', () => {
        if (!this._popoverPinned) this._hidePopover();
      });
      container.appendChild(row);
    });
  }

  _buildDetail(key, idx, data) {
    const panel = document.getElementById('aqlDistDetail');
    const inner = document.getElementById('aqlDistDpInner');
    if (!panel || !inner) return;
    panel.classList.remove('open');
    inner.innerHTML = '';
  }

  _ensurePopover() {
    const card = document.getElementById('aqlDistCard');
    if (!card) return null;

    let popover = document.getElementById('aqlDistPopover');
    if (!popover) {
      popover = document.createElement('div');
      popover.id = 'aqlDistPopover';
      popover.className = 'aql-dist-popover';
      popover.setAttribute('role', 'status');
      card.appendChild(popover);
    }
    return popover;
  }

  _showPopover(key, idx, anchor, pinned = false) {
    const data = this._currentViewData[key] || [];
    const d = data[idx];
    if (!d) {
      this._hidePopover();
      return;
    }

    const popover = this._ensurePopover();
    const card = document.getElementById('aqlDistCard');
    if (!popover || !card) return;

    this._popoverPinned = !!pinned;
    const details = this._popoverDetails(key, idx, data);
    const color = d.color || '#00d4aa';

    popover.innerHTML = `
      <div class="aql-dist-pop-title" style="color:${color}">${escapeHTML(d.label.replace('Feed Size ', 'FS '))}</div>
      <div class="aql-dist-pop-grid">
        ${details.map(it => `
          <div class="aql-dist-pop-item">
            <div class="aql-dist-pop-label">${escapeHTML(it.l)}</div>
            <div class="aql-dist-pop-value">${escapeHTML(it.v)}</div>
          </div>`).join('')}
      </div>`;

    popover.classList.add('show');

    const cardRect = card.getBoundingClientRect();
    const point = this._anchorPoint(anchor, cardRect);
    const w = popover.offsetWidth || 168;
    const h = popover.offsetHeight || 100;
    const pad = 8;

    let x = point.x + 10;
    let y = point.y - h - 12;
    if (y < pad) y = point.y + 12;

    x = Math.max(pad, Math.min(x, cardRect.width - w - pad));
    y = Math.max(pad, Math.min(y, cardRect.height - h - pad));

    popover.style.left = `${x}px`;
    popover.style.top = `${y}px`;
  }

  _hidePopover() {
    this._popoverPinned = false;
    const popover = document.getElementById('aqlDistPopover');
    if (popover) popover.classList.remove('show');
  }

  _anchorPoint(anchor, cardRect) {
    const native = anchor && anchor.native ? anchor.native : anchor;
    if (native && typeof native.clientX === 'number' && typeof native.clientY === 'number') {
      return {
        x: native.clientX - cardRect.left,
        y: native.clientY - cardRect.top,
      };
    }

    if (anchor && typeof anchor.getBoundingClientRect === 'function') {
      const rect = anchor.getBoundingClientRect();
      return {
        x: rect.left + rect.width - cardRect.left,
        y: rect.top + rect.height / 2 - cardRect.top,
      };
    }

    const canvas = document.getElementById('chartDonut');
    const rect = canvas ? canvas.getBoundingClientRect() : cardRect;
    return {
      x: rect.left + rect.width / 2 - cardRect.left,
      y: rect.top + rect.height / 2 - cardRect.top,
    };
  }

  _popoverDetails(key, idx, data) {
    const d = data[idx];
    const total = data.reduce((s, x) => s + x.value, 0);
    const pct = total > 0 ? Math.round((d.value / total) * 100) : 0;
    const rank = [...data].sort((a, b) => b.value - a.value).findIndex(x => x.label === d.label) + 1;

    if (key === 'phase') {
      return [
        { l: 'Feed', v: this._fmtVal(d.value) },
        { l: 'Share', v: `${pct}%` },
        { l: 'Avg/day', v: this._avgPerDayLabel(d) },
        { l: 'Rank', v: `#${rank}` },
      ];
    }

    return [
      { l: 'Share', v: `${pct}%` },
      { l: 'Feed', v: this._fmtVal(d.value) },
      { l: 'Rank', v: `#${rank}` },
      { l: 'Vs avg', v: this._vsAvgLabel(d, data) },
    ];
  }



  _updateFooter(key, idx, data, total) {
    const lblEl   = document.getElementById('aqlDistFootLbl');
    const valEl   = document.getElementById('aqlDistFootVal');
    const pillEl  = document.getElementById('aqlDistTrend');
    if (!lblEl || !valEl || !pillEl) return;

    const footDefaults = {
      size:  { l: 'Total feed',          v: total > 0 ? this._fmtVal(total) : '—' },
      pond:  { l: 'Total across ponds',  v: total > 0 ? this._fmtVal(total) : '—' },
      phase: { l: 'Total this cycle',    v: total > 0 ? this._fmtVal(total) : '—' },
    };
    const foot = footDefaults[key] || footDefaults.size;
    lblEl.textContent = foot.l;
    valEl.textContent = foot.v;

    // Trend pill — WoW on size/pond, phase-ramp on phase
    let trend;
    if (key === 'phase' && data.length >= 2) {
      const last = data[data.length - 1];
      const prev = data[data.length - 2];
      trend = last.value >= prev.value
        ? { dir: 'up', txt: '↑ Ramping up' }
        : { dir: 'dn', txt: '↓ Ramping down' };
    } else if (total > 0) {
      const prevWeekRecs = records.filter(r => {
        if (!r.Date) return false;
        const diff = (new Date() - new Date(r.Date + 'T00:00:00')) / MS_PER_DAY; // H1 fix: parse as local
        return diff >= 7 && diff < 14;
      });
      trend = calcWoWTrend(this._currentRecs, prevWeekRecs);
    } else {
      trend = { dir: 'fl', txt: '→ No data' };
    }
    pillEl.className    = `aql-dist-trend-pill ${trend.dir}`;
    pillEl.textContent  = trend.txt;
  }

  _showEmptyIfNeeded() {
    const data  = this._currentViewData[this.currentKey] || [];
    const total = data.reduce((s, d) => s + d.value, 0);
    this._updateCard(data.length === 0 || total === 0);
  }

  _fmtVal(grams) {
    const kg = grams / 1000;
    if (kg >= 1) return kg.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 1 }) + ' kg';
    return Math.round(grams).toLocaleString() + ' g';
  }

  _vsAvgLabel(d, allData) {
    if (!allData.length) return '—';
    const avg = allData.reduce((s, x) => s + x.value, 0) / allData.length;
    if (avg === 0) return '—';
    const diff = d.value - avg;
    const sign = diff >= 0 ? '+' : '';
    return `${sign}${this._fmtVal(Math.abs(diff))}`;
  }

  _avgPerDayLabel(d) {
    // Estimate days in phase from label (DOC 1–10 = 10 days, etc.)
    const match = d.label.match(/(\d+)[–-](\d+)/);
    if (match) {
      const days = parseInt(match[2]) - parseInt(match[1]) + 1;
      return this._fmtVal(d.value / days);
    }
    if (d.label.includes('21+')) {
      // Estimate remaining days; fallback 10
      return this._fmtVal(d.value / 10);
    }
    return '—';
  }

  _updateSummaryBox() {
    const summaryBox = document.getElementById('donutChartSummary');
    if (!summaryBox) return;
    const data  = this._currentViewData.size || [];
    const total = data.reduce((s, d) => s + d.value, 0);
    const validData = data.filter(d => d.value > 0);
    if (validData.length) {
      let highest = validData[0], lowest = validData[0];
      validData.forEach(d => {
        if (d.value > highest.value) highest = d;
        if (d.value < lowest.value)  lowest  = d;
      });
      const highestPct = total > 0 ? ((highest.value / total) * 100).toFixed(1) : 0;
      const lowestPct  = total > 0 ? ((lowest.value  / total) * 100).toFixed(1) : 0;
      let txt = `Size Summary: Dominant feed size is <strong class="summary-highlight">${highest.label}</strong> at <strong class="summary-highlight">${highestPct}%</strong> (${fmtGrams(highest.value)}g).`;
      if (validData.length >= 2 && highest.label !== lowest.label)
        txt += ` Least used is ${lowest.label} at ${lowestPct}% (${fmtGrams(lowest.value)}g).`;
      summaryBox.innerHTML = txt;
      summaryBox.classList.remove('hidden');
    } else {
      summaryBox.classList.add('hidden');
    }
  }
}


// Window bindings for backward compatibility
window.drawNeonLineChart = drawNeonLineChart;
window.drawBezierArea = drawBezierArea;
window.drawBezierStroke = drawBezierStroke;
window.drawDualAxisLineChart = drawDualAxisLineChart;
window.drawDualAxisLineChartBody = drawDualAxisLineChartBody;
window.drawHorizontalBarChart = drawHorizontalBarChart;
window.drawHorizontalBarChartBody = drawHorizontalBarChartBody;
window.roundRectH = roundRectH;
window.drawBarChart = drawBarChart;
window.drawBarChartBody = drawBarChartBody;
window.roundRect = roundRect;
window.drawDonutChart = drawDonutChart;
window.drawAnalyticsGrowthCanvas = drawAnalyticsGrowthCanvas;
window.drawAnalyticsGrowthCanvasBody = drawAnalyticsGrowthCanvasBody;
window.drawBiomassCanvas = drawBiomassCanvas;
window.drawBiomassCanvasBody = drawBiomassCanvasBody;
window.last7DaysData = last7DaysData;
window.AqlDistributionCard = AqlDistributionCard;
})();

// --- Module: weather.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

let _weatherRefreshInterval = null;
let _weatherRefreshSite = null;

function timeAgoLabel(isoTimestamp) {
  if (!isoTimestamp) return '';
  const mins = Math.max(0, Math.round((Date.now() - new Date(isoTimestamp).getTime()) / 60000));
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} minute${mins === 1 ? '' : 's'} ago`;
  const hrs = Math.round(mins / 60);
  return `${hrs} hour${hrs === 1 ? '' : 's'} ago`;
}

function startWeatherAutoRefresh(site) {
  stopWeatherAutoRefresh(); // clear any previous interval first
  _weatherRefreshSite = site;
  // Auto-refresh every 10 minutes while the pond overview is open
  _weatherRefreshInterval = setInterval(() => {
    if (_weatherRefreshSite) {
      window.WeatherService.clearCache && window.WeatherService.clearCache(_weatherRefreshSite.id);
      renderWeatherIntelligence(_weatherRefreshSite);
    }
  }, 10 * 60 * 1000);
}

function stopWeatherAutoRefresh() {
  if (_weatherRefreshInterval) {
    clearInterval(_weatherRefreshInterval);
    _weatherRefreshInterval = null;
  }
  _weatherRefreshSite = null;
}

async function renderWeatherIntelligence(site) {
  const section = $('weatherIntelligenceSection');
  if (!section || !window.SiteManager || !window.WeatherService) return;

  if (!site) {
    section.classList.add('hidden');
    section.innerHTML = '';
    return;
  }

  section.classList.remove('hidden');
  if (!section.dataset.loadedOnce) {
    section.innerHTML = '<div class="farm-intel-card wx-loading"><span class="wx-loading-dot"></span>Loading farm intelligence…</div>';
  }

  const { data: weather, fromCache, error } = await window.WeatherService.getWeatherForSite(site);
  section.dataset.loadedOnce = 'true';

  if (!weather) {
    const msg = error === 'OFFLINE'
      ? 'No internet connection. Weather data will load once you\u2019re back online.'
      : 'Weather service unavailable. Showing last known data.';
    section.innerHTML = `<div class="farm-intel-card"><div class="fic-title">🌤 Farm intelligence</div><div class="settings-site-empty">${escapeHTML(msg)}</div></div>`;
    return;
  }

  const alert = window.WeatherAlertEngine ? window.WeatherAlertEngine.analyzeRainRisk(weather) : null;
  const rec   = window.FeedRecommendationEngine ? window.FeedRecommendationEngine.getFeedingRecommendation(weather) : null;
  const risk  = window.FarmPredictionEngine ? window.FarmPredictionEngine.computeFarmHealthScore(weather) : null;

  /* ── Helpers ── */
  function wxConditionIconClass(cond) {
    const c = (cond || '').toLowerCase();
    if (c.includes('thunder')) return 'ti-cloud-lightning';
    if (c.includes('storm')) return 'ti-cloud-storm';
    if (c.includes('heavy rain') || c.includes('violent')) return 'ti-cloud-rain';
    if (c.includes('rain') || c.includes('shower') || c.includes('drizzle')) return 'ti-cloud-rain';
    if (c.includes('snow')) return 'ti-snowflake';
    if (c.includes('fog') || c.includes('mist')) return 'ti-cloud-fog';
    if (c.includes('overcast')) return 'ti-cloud';
    if (c.includes('partly cloudy') || c.includes('cloudy')) return 'ti-cloud-sun';
    if (c.includes('clear') || c.includes('sunny')) return 'ti-sun';
    return 'ti-cloud';
  }

  function wxHint(w) {
    const t = w.temperature;
    if (t == null) return '';
    if (t < 22) return 'Temperature low — monitor shrimp activity';
    if (t <= 32) return 'Ideal for feeding';
    if (t <= 34) return 'Warm — consider reducing feed';
    return 'High temp — reduce feeding, check DO';
  }

  function recBadge(status) {
    const map = {
      'normal'        : { label: 'On track',  cls: 'fic-badge--good'   },
      'low-temp'      : { label: 'Low temp',  cls: 'fic-badge--warn'   },
      'high-temp'     : { label: 'High temp', cls: 'fic-badge--danger' },
      'humidity-risk' : { label: 'Caution',   cls: 'fic-badge--warn'   },
    };
    return map[status] || { label: 'Check', cls: 'fic-badge--warn' };
  }

  const staleness = fromCache
    ? (error === 'OFFLINE' ? 'Offline — cached' : timeAgoLabel(weather.timestamp))
    : 'Just now';

  const badge = rec ? recBadge(rec.status) : { label: 'Check', cls: 'fic-badge--warn' };

  // Calculate Health Ring progress attributes
  const score = (risk && risk.score != null) ? risk.score : 0;
  const r = 34;
  const circumference = 2 * Math.PI * r; // ~213.63
  const offset = circumference - (score / 100) * circumference;

  let ringColor = '#10b981'; // Green
  if (risk && risk.status === 'WARNING') ringColor = '#f59e0b'; // Amber
  if (risk && risk.status === 'CRITICAL') ringColor = '#ef4444'; // Red

  // Calculate insights HTML
  const insightsHTML = risk ? risk.analysis.map(a => {
    let itemClass = 'ok';
    let iconClass = 'ti-check';
    if (a.icon === '✓') {
      itemClass = 'ok';
      iconClass = 'ti-check';
    } else if (a.icon === '⚠') {
      itemClass = 'warn';
      iconClass = 'ti-alert-triangle';
    } else if (a.icon === '✗') {
      itemClass = 'critical';
      iconClass = 'ti-alert-circle';
    } else {
      itemClass = 'neutral';
      iconClass = 'ti-info-circle';
    }
    return `<li class="${itemClass}"><i class="ti ${iconClass}"></i>${escapeHTML(a.text)}</li>`;
  }).join('') : '';

  let html = `
    <div class="farm-intel-card">
      <div class="fic-header">
        <div class="fic-title"><i class="ti ti-cloud"></i><span>Farm intelligence</span></div>
        <button class="fic-refresh" id="wxRefreshBtn"><i class="ti ti-refresh"></i><span id="wxUpdatedAt">${escapeHTML(staleness)}</span></button>
      </div>
      <div class="fic-location"><i class="ti ti-map-pin"></i><span id="wxLocationLabel">${escapeHTML(site.location.address || site.name)}</span></div>

      <div class="fic-hero">
        <i class="ti ${wxConditionIconClass(weather.condition)} fic-hero-icon" id="wxConditionIcon"></i>
        <div>
          <div class="fic-hero-row">
            <span class="fic-temp" id="wxTemp">${weather.temperature != null ? Math.round(weather.temperature) + '°' : '—'}</span>
            <span class="fic-cond" id="wxCondition">${escapeHTML(weather.condition || '—')}</span>
          </div>
          <div class="fic-hero-note" id="wxFeedingNote">${escapeHTML(wxHint(weather))}</div>
        </div>
      </div>

      <div class="fic-metrics">
        <div class="fic-metric"><i class="ti ti-droplet fic-m-blue"></i><div class="fic-m-val" id="wxHumidity">${weather.humidity != null ? weather.humidity + '%' : '—'}</div><div class="fic-m-label">Humidity</div></div>
        <div class="fic-metric"><i class="ti ti-cloud-rain fic-m-blue"></i><div class="fic-m-val" id="wxRain">${weather.rainProbability != null ? weather.rainProbability + '%' : '—'}</div><div class="fic-m-label">Rain</div></div>
        <div class="fic-metric"><i class="ti ti-wind fic-m-gray"></i><div class="fic-m-val" id="wxWind">${weather.windSpeed != null ? Math.round(weather.windSpeed) + ' km/h' : '—'}</div><div class="fic-m-label">Wind</div></div>
        <div class="fic-metric"><i class="ti ti-gauge fic-m-gray"></i><div class="fic-m-val" id="wxPressure">${weather.pressure != null ? Math.round(weather.pressure) : '—'}</div><div class="fic-m-label">Pressure</div></div>
      </div>

      <!-- Alert Section if present -->
      ${alert ? `
      <div class="fic-section fic-section--alert" style="border-top: 1px solid rgba(255,255,255,0.06); padding-top: 12px; margin-top: 12px;">
        <div class="fic-feed-row">
          <div class="fic-feed-icon fic-feed-icon--alert" style="color: var(--red); background: rgba(239, 68, 68, 0.12);"><i class="ti ti-alert-triangle"></i></div>
          <div class="fic-feed-body">
            <div class="fic-feed-top">
              <span class="fic-feed-title" style="color: var(--red);">${escapeHTML(alert.title)}</span>
              <span class="fic-badge fic-badge--danger" style="background: rgba(239, 68, 68, 0.12); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.25);">${escapeHTML(alert.level.toUpperCase())}</span>
            </div>
            <div class="fic-feed-desc">${escapeHTML(alert.message)}</div>
            <ul class="fic-alert-actions" style="margin-top: 6px; padding-left: 15px; font-size: 0.75rem; color: var(--t2); line-height: 1.4;">
              ${alert.actions.map(act => `<li>${escapeHTML(act)}</li>`).join('')}
            </ul>
          </div>
        </div>
      </div>
      ` : ''}

      <!-- Feed Recommendation Section -->
      ${rec ? `
      <div class="fic-section">
        <div class="fic-feed-row">
          <div class="fic-feed-icon"><i class="ti ti-fish"></i></div>
          <div class="fic-feed-body">
            <div class="fic-feed-top">
              <span class="fic-feed-title" id="feedStatusTitle">${escapeHTML(rec.title)}</span>
              <span class="fic-badge ${badge.cls}" id="feedStatusBadge">${badge.label}</span>
            </div>
            <div class="fic-feed-desc" id="feedStatusDesc">${escapeHTML(rec.message)}</div>
            ${rec.actions.length ? `
              <ul class="fic-alert-actions" style="margin-top: 6px; padding-left: 15px; font-size: 0.75rem; color: var(--t2); line-height: 1.4;">
                ${rec.actions.map(act => `<li>${escapeHTML(act)}</li>`).join('')}
              </ul>
            ` : ''}
          </div>
        </div>
      </div>
      ` : ''}

      <!-- Health Score Section -->
      ${risk && risk.score != null ? `
      <div class="fic-section">
        <div class="fic-section-title"><i class="ti ti-activity"></i><span>Farm health score</span></div>
        <div class="fic-health-row">
          <svg width="52" height="52" viewBox="0 0 80 80" class="fic-ring">
            <circle cx="40" cy="40" r="34" class="fic-ring-track"/>
            <circle cx="40" cy="40" r="34" class="fic-ring-fill" id="healthRingFill" style="stroke: ${ringColor}; stroke-dasharray: ${circumference}; stroke-dashoffset: ${offset};"/>
            <text x="40" y="47" text-anchor="middle" class="fic-ring-num" id="healthScoreNum">${risk.score}</text>
          </svg>
          <div class="fic-health-body">
            <div class="fic-health-verdict" style="color: ${ringColor};"><span id="healthVerdict">${risk.status}</span> &middot; <span id="healthNote" style="color: var(--t2); font-weight: normal;">${escapeHTML(risk.recommendation)}</span></div>
            <ul class="fic-health-list" id="healthInsightList">
              ${insightsHTML}
            </ul>
          </div>
        </div>
      </div>
      ` : ''}

    </div>
  `;

  section.innerHTML = html;

  // Wire the manual refresh button
  const refreshBtn = $('wxRefreshBtn');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', async () => {
      const icon = refreshBtn.querySelector('.ti-refresh');
      if (icon && icon.classList.contains('ai-refresh-btn--spinning')) return;
      if (icon) icon.classList.add('ai-refresh-btn--spinning');
      refreshBtn.disabled = true;
      const label = $('wxUpdatedAt');
      if (label) label.textContent = 'Refreshing…';
      if (window.WeatherService.clearCache) window.WeatherService.clearCache(site.id);
      await renderWeatherIntelligence(site);
    });
  }

  // Log a daily snapshot for weather-vs-feed/growth analytics
  if (window.WeatherHistoryManager) {
    // M15 fix: pass today's feed total as extra.feedGiven (was always omitted, leaving feed/growth analytics empty)
    const _todayStr = fmt(new Date());
    const _todayFeedGrams = records.filter(r => r.Date === _todayStr).reduce((s, r) => s + sumGrams([r]), 0);
    window.WeatherHistoryManager.recordDailySnapshot(site.id, weather, { feedGiven: +(_todayFeedGrams / 1000).toFixed(3) });
  }
}

function bindAquaLogIntelligenceEvents() {
  bindPondSiteSelectNewSiteOption('newPondSite');
  bindPondSiteSelectNewSiteOption('editPondSite');

  $('createSiteCancel')?.addEventListener('click', closeCreateSiteModal);
  $('createSiteModal')?.addEventListener('click', e => { if (e.target === $('createSiteModal')) closeCreateSiteModal(); });
  $('createSiteConfirm')?.addEventListener('click', doCreateSite);
  $('siteSearchBtn')?.addEventListener('click', handleSiteSearch);
  $('newSiteSearch')?.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); handleSiteSearch(); } });
  $('siteUseGpsBtn')?.addEventListener('click', handleSiteUseGPS);
  $('manageAddSiteBtn')?.addEventListener('click', () => { pendingPondSiteSelectId = null; openCreateSiteModal(); });
}

// Window bindings for backward compatibility
window.timeAgoLabel = timeAgoLabel;
window.startWeatherAutoRefresh = startWeatherAutoRefresh;
window.stopWeatherAutoRefresh = stopWeatherAutoRefresh;
window.renderWeatherIntelligence = renderWeatherIntelligence;
window.bindAquaLogIntelligenceEvents = bindAquaLogIntelligenceEvents;
})();

// --- Module: settings.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

let pendingPondSiteSelectId = null;
let siteSearchResultsCache = [];
let siteSelectedLocation = null;
let editingSiteId = null;

// ── Theme system (dark-only) ──────────────────────────────────────────────
// Light theme and the Appearance settings section have been removed.
// The app is now permanently dark. applyTheme() remains as a no-op shim
// so any external callers (e.g. extra-features.js's hook) keep working.
function applyTheme() {
  document.documentElement.setAttribute('data-theme', 'dark');
}

function bindSettingsEvents() {
  // Developer Tools buttons
  $('settingsLoadDemoBtn')?.addEventListener('click', loadDemoData);
  $('settingsResetDataBtn')?.addEventListener('click', () => {
    showConfirm(
      'Reset All Data',
      'This will permanently delete ALL ponds, batches, feed records, growth data, and sampling entries from this device. This cannot be undone.',
      () => {
        AppStorage.clearDomainData();
        window.location.reload();
      },
      { icon: '🗑', danger: true, confirmLabel: 'Reset Everything', cancelLabel: 'Cancel' }
    );
  });
}

// ── Outdoor mode & Font size ──────────────────────────────────────────────
// Kept as functional helpers — the toggles still exist in Settings.
function initOutdoorMode() {
  const storageKey = 'al_outdoor_mode';
  const outdoorToggle = $('outdoorModeToggle');
  const enabled = AppStorage.getSetting(storageKey) === 'true';

  if (outdoorToggle) {
    outdoorToggle.checked = enabled;
    document.documentElement.classList.toggle('outdoor-mode', enabled);
    outdoorToggle.addEventListener('change', () => {
      const newMode = outdoorToggle.checked;
      AppStorage.saveSetting(storageKey, newMode.toString());
      document.documentElement.classList.toggle('outdoor-mode', newMode);
    });
  } else {
    document.documentElement.classList.toggle('outdoor-mode', enabled);
  }
}

function initFontSizeToggle() {
  // The HTML exposes two buttons (#fontSizeSmall / #fontSizeLarge) instead of a select.
  const storageKey = 'al_font_size';
  const storedSize = AppStorage.getSetting(storageKey) || 'medium';
  const btnSmall = $('fontSizeSmall');
  const btnLarge = $('fontSizeLarge');

  const apply = (size) => {
    document.documentElement.setAttribute('data-font-size', size);
    AppStorage.saveSetting(storageKey, size);
    if (btnSmall) btnSmall.classList.toggle('green-btn', size === 'small');
    if (btnLarge) btnLarge.classList.toggle('green-btn', size === 'large');
  };
  apply(storedSize);

  if (btnSmall) btnSmall.addEventListener('click', () => apply('small'));
  if (btnLarge) btnLarge.addEventListener('click', () => apply('large'));
}

// Removed: initTheme, renderSettingsPage, applyM3Theme, initMaterialYouTheme.
// The M3 toggle UI was deleted from index.html along with the Appearance section.

function populateSiteSelect(selectId, selectedValue) {
  const sel = $(selectId);
  if (!sel || !window.SiteManager) return;
  const sites = window.SiteManager.loadSites();

  sel.innerHTML = '';
  const placeholder = document.createElement('option');
  placeholder.value = '';
  placeholder.disabled = true;
  placeholder.textContent = '— Select Site —';
  if (!selectedValue) placeholder.selected = true;
  sel.appendChild(placeholder);

  sites.forEach(site => {
    const opt = document.createElement('option');
    // M10 fix: use site.id as value (was site.name — duplicate names caused silent data loss)
    opt.value = site.id;
    opt.textContent = site.name;
    if (site.id === selectedValue || site.name === selectedValue) opt.selected = true;
    sel.appendChild(opt);
  });

  const newOpt = document.createElement('option');
  newOpt.value = '__new__';
  newOpt.textContent = '＋ Add New Site…';
  sel.appendChild(newOpt);
}

function lookupSiteIdByName(name) {
  if (!window.SiteManager || !name) return null;
  // M10 fix: also match by id (since populateSiteSelect now uses site.id as option value)
  const sites = window.SiteManager.loadSites();
  const match = sites.find(s => s.id === name || s.name === name);
  return match ? match.id : null;
}

function bindPondSiteSelectNewSiteOption(selectId) {
  const sel = $(selectId);
  if (!sel) return;
  sel.addEventListener('change', () => {
    if (sel.value === '__new__') {
      sel.value = ''; // don't leave the sentinel selected
      pendingPondSiteSelectId = selectId;
      openCreateSiteModal();
    }
  });
}

function resetCreateSiteModal() {
  $('newSiteName').value = '';
  $('newSiteSearch').value = '';
  siteSelectedLocation = null;
  siteSearchResultsCache = [];
  $('siteSearchResults').classList.add('hidden');
  $('siteSearchResults').innerHTML = '';
  $('siteLatDisplay').textContent = '—';
  $('siteLngDisplay').textContent = '—';
  $('siteAddressDisplay').textContent = 'No location set yet';
  clearFieldError('errNewSiteName', 'newSiteName', 'Farm name is required');
  clearFieldError('errNewSiteLocation', 'newSiteSearch', 'Set a location using search or GPS');
}

function openCreateSiteModal() {
  resetCreateSiteModal();
  $('createSiteModal').classList.remove('hidden');
  setTimeout(() => $('newSiteName').focus(), 100);
}

function closeCreateSiteModal() {
  closeModal('createSiteModal');
  pendingPondSiteSelectId = null;
  editingSiteId = null;
}

function openEditSiteModal(siteId) {
  if (!window.SiteManager) return;
  const site = window.SiteManager.getSiteById(siteId);
  if (!site) return;

  resetCreateSiteModal();
  editingSiteId = site.id;

  $('createSiteModalTitle').textContent = 'Edit Farm Site';
  $('newSiteName').value = site.name;
  
  if (site.location) {
    siteSelectedLocation = {
      latitude: site.location.latitude,
      longitude: site.location.longitude,
      address: site.location.address
    };
    $('siteLatDisplay').textContent = site.location.latitude != null ? site.location.latitude.toFixed(4) : '—';
    $('siteLngDisplay').textContent = site.location.longitude != null ? site.location.longitude.toFixed(4) : '—';
    $('siteAddressDisplay').textContent = site.location.address || 'No location set yet';
  }

  $('createSiteModal').classList.remove('hidden');
}

function confirmDeleteSite(siteId) {
  if (!window.SiteManager) return;
  const site = window.SiteManager.getSiteById(siteId);
  if (!site) return;

  // Check if any pond is currently using this site
  const isUsed = ponds.some(p => p.siteId === siteId);
  if (isUsed) {
    showToast('⚠️', 'Cannot Delete', `${site.name} is currently linked to one or more ponds.`);
    return;
  }

  // M14 fix: use showConfirm instead of native confirm() for consistent UX
  showConfirm(
    'Delete Farm Site',
    `Are you sure you want to delete the site "${site.name}"? This cannot be undone.`,
    () => {
      window.SiteManager.deleteSite(siteId);
      showToast('🗑️', 'Site Deleted', `${site.name} has been removed.`);

      // Refresh UI
      renderSitesSettings();
      renderManageSites();

      // Refresh weather if necessary
      const select = $('dashboardContextSelect');
      const context = select ? select.value : 'farm';
      if (context !== 'farm') {
        const batchId = context.replace('batch_', '');
        const batch = batches.find(b => b.id === batchId);
        if (batch) {
          const pond = ponds.find(p => p.id === batch.pondId);
          const activeSite = pond && window.SiteManager ? window.SiteManager.getSiteById(pond.siteId) : null;
          renderWeatherIntelligence(activeSite);
        }
      }
    },
    { danger: true }
  );
}

function setStagedSiteLocation(loc) {
  siteSelectedLocation = loc;
  $('siteLatDisplay').textContent = loc.latitude.toFixed(4);
  $('siteLngDisplay').textContent = loc.longitude.toFixed(4);
  $('siteAddressDisplay').textContent = loc.address || `${loc.latitude.toFixed(4)}, ${loc.longitude.toFixed(4)}`;
  clearFieldError('errNewSiteLocation', 'newSiteSearch', 'Set a location using search or GPS');
}

async function handleSiteSearch() {
  const query = $('newSiteSearch').value.trim();
  const resultsBox = $('siteSearchResults');
  if (!query || !window.LocationService) return;

  resultsBox.classList.remove('hidden');
  resultsBox.innerHTML = '<div class="settings-site-empty">Searching…</div>';

  try {
    const results = await window.LocationService.geocodeAddress(query);
    siteSearchResultsCache = results;
    resultsBox.innerHTML = '';
    results.forEach((r, idx) => {
      const item = document.createElement('button');
      item.type = 'button';
      item.className = 'site-search-result-item';
      item.textContent = r.address;
      item.addEventListener('click', () => {
        setStagedSiteLocation(r);
        resultsBox.classList.add('hidden');
      });
      resultsBox.appendChild(item);
    });
  } catch (e) {
    resultsBox.innerHTML = `<div class="settings-site-empty">${escapeHTML(e.message || 'Search failed. Try again.')}</div>`;
  }
}

async function handleSiteUseGPS() {
  if (!window.LocationService) return;
  const btn = $('siteUseGpsBtn');
  // L15 fix: null-check btn (was throwing if element was missing)
  if (!btn) return;
  const originalText = btn.textContent;
  btn.textContent = '📍 Locating…';
  btn.disabled = true;

  try {
    const { latitude, longitude } = await window.LocationService.getCurrentGPSLocation();
    const address = await window.LocationService.reverseGeocode(latitude, longitude);
    setStagedSiteLocation({ latitude, longitude, address });
  } catch (e) {
    showFieldError('errNewSiteLocation', 'newSiteSearch', e.message || 'Could not get GPS location. Enter it manually below.');
  } finally {
    btn.textContent = originalText;
    btn.disabled = false;
  }
}

function doCreateSite() {
  const name = $('newSiteName').value.trim();
  clearFieldError('errNewSiteName', 'newSiteName', 'Farm name is required');
  clearFieldError('errNewSiteLocation', 'newSiteSearch', 'Set a location using search or GPS');

  let ok = true;
  if (!name) { showFieldError('errNewSiteName', 'newSiteName', 'Farm name is required'); ok = false; }
  if (!siteSelectedLocation) { showFieldError('errNewSiteLocation', 'newSiteSearch', 'Set a location using search or GPS'); ok = false; }
  if (!ok || !window.SiteManager) return;

  if (editingSiteId) {
    const site = window.SiteManager.updateSite(editingSiteId, {
      name,
      address: siteSelectedLocation.address,
      latitude: siteSelectedLocation.latitude,
      longitude: siteSelectedLocation.longitude,
    });
    showToast('✏️', 'Site Updated', `${site.name} has been updated`);
    editingSiteId = null;
  } else {
    const site = window.SiteManager.createSite({
      name,
      address: siteSelectedLocation.address,
      latitude: siteSelectedLocation.latitude,
      longitude: siteSelectedLocation.longitude,
    });
    showToast('✅', 'Site Saved', `${site.name} added to your farm sites`);
    if (pendingPondSiteSelectId) {
      populateSiteSelect(pendingPondSiteSelectId, site.name);
      pendingPondSiteSelectId = null;
    }
  }

  closeModal('createSiteModal');
  renderSitesSettings();
  renderManageSites();

  // Refresh weather for active pond overview if it was updated
  const select = $('dashboardContextSelect');
  const context = select ? select.value : 'farm';
  if (context !== 'farm') {
    const batchId = context.replace('batch_', '');
    const batch = batches.find(b => b.id === batchId);
    if (batch) {
      const pond = ponds.find(p => p.id === batch.pondId);
      const activeSite = pond && window.SiteManager ? window.SiteManager.getSiteById(pond.siteId) : null;
      renderWeatherIntelligence(activeSite);
    }
  }
}

function renderSitesSettings() {
  const list = $('settingsSitesList');
  if (!list || !window.SiteManager) return;

  const sites = window.SiteManager.loadSites();
  if (sites.length === 0) {
    list.innerHTML = '<div class="settings-site-empty">No farm sites yet. Add one to enable weather intelligence.</div>';
    return;
  }

  list.innerHTML = sites.map(site => {
    const addr = site.location && site.location.address ? site.location.address : 'No location set';
    return `
      <div class="settings-site-row">
        <div class="settings-site-info" style="flex:1; min-width:0;">
          <div class="settings-site-name">${escapeHTML(site.name)}</div>
          <div class="settings-site-addr">${escapeHTML(addr)}</div>
        </div>
        <div class="settings-site-actions" style="display:flex; gap:8px; flex-shrink:0;">
          <button class="icon-btn" data-action="editSite" data-site-id="${site.id}" style="background:transparent; border:none; color:var(--teal); font-size:1.1rem; padding:4px; cursor:pointer;" aria-label="Edit Site">✏️</button>
          <button class="icon-btn" data-action="deleteSite" data-site-id="${site.id}" style="background:transparent; border:none; color:var(--red); font-size:1.1rem; padding:4px; cursor:pointer;" aria-label="Delete Site">🗑️</button>
        </div>
      </div>`;
  }).join('');
}

function renderManageSites() {
  const list = $('manageSitesList');
  if (!list || !window.SiteManager) return;

  const sites = window.SiteManager.loadSites();
  if (sites.length === 0) {
    list.innerHTML = '<div class="settings-site-empty">No farm sites yet. Add one to enable weather intelligence.</div>';
    return;
  }

  list.innerHTML = sites.map(site => {
    const addr = site.location && site.location.address ? site.location.address : 'No location set';
    return `
      <div class="settings-site-row">
        <div class="settings-site-info" style="flex:1; min-width:0;">
          <div class="settings-site-name">${escapeHTML(site.name)}</div>
          <div class="settings-site-addr">${escapeHTML(addr)}</div>
        </div>
        <div class="settings-site-actions" style="display:flex; gap:8px; flex-shrink:0;">
          <button class="icon-btn" data-action="editSite" data-site-id="${site.id}" style="background:transparent; border:none; color:var(--teal); font-size:1.1rem; padding:4px; cursor:pointer;" aria-label="Edit Site">✏️</button>
          <button class="icon-btn" data-action="deleteSite" data-site-id="${site.id}" style="background:transparent; border:none; color:var(--red); font-size:1.1rem; padding:4px; cursor:pointer;" aria-label="Delete Site">🗑️</button>
        </div>
      </div>`;
  }).join('');
}

function getPrimarySiteForDashboard() {
  if (!window.SiteManager) return null;
  const pondWithSite = ponds
    .slice()
    .reverse()
    .map(p => window.SiteManager.getSiteById(p.siteId))
    .find(site => window.SiteManager.hasLocation(site));
  if (pondWithSite) return pondWithSite;

  return window.SiteManager.loadSites().find(s => window.SiteManager.hasLocation(s)) || null;
}

function loadApiSettings() {
  const s = AppStorage.getApiSettings();
  if (s.url)     $('apiUrl').value     = s.url;
  if (s.method)  $('apiMethod').value  = s.method;
  if (s.auth)    $('apiAuth').value    = s.auth;
  if (s.headers) $('apiHeaders').value = s.headers;
}

function saveApiSettings() {
  const url        = $('apiUrl').value.trim();
  const method     = $('apiMethod').value;
  const auth       = $('apiAuth').value.trim();
  const headersRaw = $('apiHeaders').value.trim();

  if (url && !url.startsWith('http')) {
    showToast('⚠️', 'Invalid URL', 'Please check the API URL.');
    return;
  }

  if (headersRaw) {
    try {
      JSON.parse(headersRaw);
      $('errApiHeaders').classList.remove('show');
    } catch (e) {
      $('errApiHeaders').classList.add('show');
      showToast('⚠️', 'Invalid JSON', 'Headers must be valid JSON.');
      return;
    }
  } else {
    $('errApiHeaders').classList.remove('show');
  }

  AppStorage.saveApiSettings({ url, method, auth, headers: headersRaw });
  showToast('✅', 'Settings Saved', 'API connection settings saved.');
}

function loadDemoData() {
  showConfirm(
    'Load Demo Data',
    'This will clear ALL existing data — ponds, batches, feed logs, inventory, weather history, and finance records — and replace it with ~2 years of realistic demo data covering every module (including a disease outbreak and a cyclone event). This cannot be undone.',
    _executeDemoDataLoad,
    { icon: '🚀', danger: true, confirmLabel: 'Load Demo Data', cancelLabel: 'Cancel' }
  );
}

function _executeDemoDataLoad() {
  /* ── helpers ── */
  function uid(prefix) {
    return prefix + '_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7);
  }

  function dateStr(baseDate, offsetDays) {
    const d = new Date(baseDate);
    d.setDate(d.getDate() + offsetDays);
    return fmt(d);
  }

  /* ── seeded pseudo-random for reproducible demo data ── */
  let seed = 20240603;
  function rand() {
    seed = (seed * 1664525 + 1013904223) & 0xffffffff;
    return ((seed >>> 0) / 0xffffffff);
  }
  function randBetween(min, max) { return min + rand() * (max - min); }
  function randInt(min, max) { return Math.floor(randBetween(min, max + 1)); }

  /* ── Feed schedule ── */
  function feedMixForDOC(doc) {
    if (doc <= 20)  return { fs1: 0.90, fs2: 0.10, fs3: 0,    fs4: 0,    fs5: 0 };
    if (doc <= 40)  return { fs1: 0.55, fs2: 0.45, fs3: 0,    fs4: 0,    fs5: 0 };
    if (doc <= 70)  return { fs1: 0,    fs2: 0.60, fs3: 0.40, fs4: 0,    fs5: 0 };
    if (doc <= 100) return { fs1: 0,    fs2: 0,    fs3: 0.55, fs4: 0.45, fs5: 0 };
    return              { fs1: 0,    fs2: 0,    fs3: 0,    fs4: 0.40, fs5: 0.60 };
  }

  function baseQtyForDOC(doc) {
    return Math.min(120000, Math.round(1000 + 100 * doc + 3 * doc * doc));
  }

  function dayQty(doc) {
    let base = baseQtyForDOC(doc);
    if (rand() < 0.10) base *= (0.82 + rand() * 0.08);
    const noise = 0.90 + rand() * 0.20;
    return Math.max(50, Math.round(base * noise));
  }

  const FEED_TIMES = ['7:00 AM', '11:00 AM', '4:00 PM', '7:00 PM'];
  function sessionsForDOC(doc) {
    if (doc <= 15)  return 1;
    if (doc <= 60)  return 2;
    return 2 + (rand() < 0.40 ? 1 : 0);
  }

  /* ── Today's date ── */
  const today = startOfDay();
  const todayStr = fmt(today);

  /* ── Ponds (5 ponds across 3 sites for richer cross-site analytics) ── */
  const demoPonds = [
    { id: 'demo_pond_1', name: 'Growout Pond A',   site: 'AquaFarm Unit 1', sizeSqFt: 15000, active: true },
    { id: 'demo_pond_2', name: 'Growout Pond B',   site: 'AquaFarm Unit 1', sizeSqFt: 12000, active: true },
    { id: 'demo_pond_3', name: 'Nursery Pond C',   site: 'AquaFarm Unit 2', sizeSqFt: 8000,  active: true },
    { id: 'demo_pond_4', name: 'Intensive Pond D', site: 'AquaFarm Unit 2', sizeSqFt: 10000, active: true },
    { id: 'demo_pond_5', name: 'Research Pond E',  site: 'AquaFarm Unit 3', sizeSqFt: 6000,  active: true },
  ];

  /* ── Batch configs — 3 ponds × 6 cycles + 2 extra ponds × 4 cycles = 26 total ── */
  const batchConfigs = [
    // Pond A — long-running growout, highest density
    { pondId: 'demo_pond_1', pondName: 'Growout Pond A', num: 1, stockOffset: -720, duration: 110, count: 250000, active: false },
    { pondId: 'demo_pond_1', pondName: 'Growout Pond A', num: 2, stockOffset: -590, duration: 115, count: 260000, active: false },
    { pondId: 'demo_pond_1', pondName: 'Growout Pond A', num: 3, stockOffset: -455, duration: 105, count: 270000, active: false },
    { pondId: 'demo_pond_1', pondName: 'Growout Pond A', num: 4, stockOffset: -330, duration: 110, count: 280000, active: false },
    { pondId: 'demo_pond_1', pondName: 'Growout Pond A', num: 5, stockOffset: -200, duration: 120, count: 290000, active: false },
    { pondId: 'demo_pond_1', pondName: 'Growout Pond A', num: 6, stockOffset: -60,  duration: 60,  count: 300000, active: true, cycloneDays: [20, 23] },

    // Pond B — medium-density growout
    { pondId: 'demo_pond_2', pondName: 'Growout Pond B', num: 1, stockOffset: -700, duration: 100, count: 200000, active: false },
    { pondId: 'demo_pond_2', pondName: 'Growout Pond B', num: 2, stockOffset: -580, duration: 110, count: 210000, active: false },
    { pondId: 'demo_pond_2', pondName: 'Growout Pond B', num: 3, stockOffset: -450, duration: 105, count: 220000, active: false },
    { pondId: 'demo_pond_2', pondName: 'Growout Pond B', num: 4, stockOffset: -325, duration: 115, count: 230000, active: false },
    { pondId: 'demo_pond_2', pondName: 'Growout Pond B', num: 5, stockOffset: -190, duration: 110, count: 240000, active: false },
    { pondId: 'demo_pond_2', pondName: 'Growout Pond B', num: 6, stockOffset: -40,  duration: 40,  count: 250000, active: true  },

    // Pond C — nursery, lower count, shorter cycle
    { pondId: 'demo_pond_3', pondName: 'Nursery Pond C', num: 1, stockOffset: -680, duration: 90,  count: 150000, active: false },
    { pondId: 'demo_pond_3', pondName: 'Nursery Pond C', num: 2, stockOffset: -570, duration: 95,  count: 160000, active: false },
    { pondId: 'demo_pond_3', pondName: 'Nursery Pond C', num: 3, stockOffset: -455, duration: 100, count: 170000, active: false },
    { pondId: 'demo_pond_3', pondName: 'Nursery Pond C', num: 4, stockOffset: -335, duration: 95,  count: 175000, active: false },
    { pondId: 'demo_pond_3', pondName: 'Nursery Pond C', num: 5, stockOffset: -220, duration: 105, count: 180000, active: false },
    { pondId: 'demo_pond_3', pondName: 'Nursery Pond C', num: 6, stockOffset: -25,  duration: 25,  count: 190000, active: true  },

    // Pond D — intensive, high-DOC active batch for deep analytics
    { pondId: 'demo_pond_4', pondName: 'Intensive Pond D', num: 1, stockOffset: -660, duration: 108, count: 320000, active: false },
    { pondId: 'demo_pond_4', pondName: 'Intensive Pond D', num: 2, stockOffset: -530, duration: 112, count: 330000, active: false },
    { pondId: 'demo_pond_4', pondName: 'Intensive Pond D', num: 3, stockOffset: -400, duration: 118, count: 340000, active: false, diseaseOutbreak: true },
    { pondId: 'demo_pond_4', pondName: 'Intensive Pond D', num: 4, stockOffset: -260, duration: 115, count: 350000, active: false },
    { pondId: 'demo_pond_4', pondName: 'Intensive Pond D', num: 5, stockOffset: -90,  duration: 90,  count: 360000, active: true  },

    // Pond E — research trial, mid-cycle active for sampling/FCR testing
    { pondId: 'demo_pond_5', pondName: 'Research Pond E', num: 1, stockOffset: -580, duration: 100, count: 100000, active: false },
    { pondId: 'demo_pond_5', pondName: 'Research Pond E', num: 2, stockOffset: -460, duration: 95,  count: 110000, active: false },
    { pondId: 'demo_pond_5', pondName: 'Research Pond E', num: 3, stockOffset: -345, duration: 102, count: 120000, active: false },
    { pondId: 'demo_pond_5', pondName: 'Research Pond E', num: 4, stockOffset: -75,  duration: 75,  count: 130000, active: true  },
  ];

  const demoBatches  = [];
  const demoRecords  = [];
  const demoGrowth   = [];
  const demoHapa     = [];
  const demoSampling = [];
  const demoBiomass  = [];

  batchConfigs.forEach((cfg, bi) => {
    const stockingDate = dateStr(today, cfg.stockOffset);
    const batchId = `demo_batch_${bi + 1}`;

    const batch = {
      id:               batchId,
      pondId:           cfg.pondId,
      pond:             cfg.pondName,
      batchNumber:      cfg.num,
      shrimpCount:      cfg.count,
      stockingDate,
      stockingTime:     '06:00',
      notes:            cfg.cycloneDays
        ? `Demo batch #${cfg.num} - ${cfg.pondName}. Feeding suspended DOC ${cfg.cycloneDays[0]}-${cfg.cycloneDays[1]} due to a cyclonic storm; crew evacuated, aerators kept on generator backup.`
        : `Demo batch #${cfg.num} - ${cfg.pondName}`,
      hapaStocked:      100,
      status:           cfg.active ? 'active' : 'completed',
      createdAt:        new Date(stockingDate + 'T06:00:00').toISOString(),
      completedAt:      null,
      harvestDate:      null,
      harvestTime:      null,
      finalShrimpCount: null,
      harvestWeightKg:  null,
      completionNotes:  null,
      survivalPercent:  null
    };

    const finalDOC = cfg.active ? Math.abs(cfg.stockOffset) : cfg.duration;
    const finalWeightG = 0.05 + 0.00133 * finalDOC * finalDOC;

    if (!cfg.active) {
      const harvestDate = dateStr(today, cfg.stockOffset + cfg.duration);
      const survivalPercent = cfg.diseaseOutbreak
        ? Math.round(randBetween(32, 42) * 10) / 10
        : Math.round(randBetween(80, 95) * 10) / 10;
      const finalCount = Math.round(cfg.count * (survivalPercent / 100));
      const finalWeightKg = Math.round((finalCount * finalWeightG) / 1000);

      batch.completedAt = new Date(harvestDate + 'T17:00:00').toISOString();
      batch.harvestDate = harvestDate;
      batch.harvestTime = '17:00';
      batch.finalShrimpCount = finalCount;
      batch.harvestWeightKg = finalWeightKg;
      batch.survivalPercent = survivalPercent;
      batch.completionNotes = cfg.diseaseOutbreak
        ? `Early harvest of batch #${cfg.num} following a White Spot Syndrome Virus (WSSV) outbreak around DOC ${Math.round(cfg.duration * 0.55)}. Emergency partial harvest to salvage biomass; survival well below target.`
        : `Successful harvest of batch #${cfg.num}. Final avg weight ${finalWeightG.toFixed(1)}g.`;
    }

    demoBatches.push(batch);

    // 2. Generate feed records for this batch
    for (let doc = 1; doc <= finalDOC; doc++) {
      const feedDate = dateStr(today, cfg.stockOffset + doc - 1);
      if (feedDate > todayStr) break;

      // Cyclone/storm event: feeding is suspended entirely while the crew
      // evacuates and pond aerators run on generator power only, then
      // appetite ramps back up gradually over the following days.
      if (cfg.cycloneDays && doc >= cfg.cycloneDays[0] && doc <= cfg.cycloneDays[1]) continue;
      const daysSinceCyclone = cfg.cycloneDays ? doc - cfg.cycloneDays[1] : null;
      const cycloneRecoveryFactor = (daysSinceCyclone !== null && daysSinceCyclone >= 1 && daysSinceCyclone <= 5)
        ? (0.5 + daysSinceCyclone * 0.1)
        : 1;

      const nSessions = sessionsForDOC(doc);
      const mix       = feedMixForDOC(doc);
      const times     = FEED_TIMES.slice(0, Math.min(nSessions, 4));
      const dayTotal  = Math.round(dayQty(doc) * cycloneRecoveryFactor); // one random total per day, split across sessions below

      // Weight morning/evening feeds a bit lighter, midday/afternoon a bit heavier,
      // then normalize so the weights always sum to 1 regardless of session count.
      const rawWeights = times.map(time => (time === '7:00 AM' || time === '7:00 PM') ? 0.9 : 1.1);
      const weightSum   = rawWeights.reduce((a, b) => a + b, 0);
      const fractions   = rawWeights.map(w => w / weightSum);

      times.forEach((time, ti) => {
        const sessionTotal = Math.round(dayTotal * fractions[ti]);

        const rec = {
          Date:        feedDate,
          Time:        time,
          PondId:      cfg.pondId,
          PondName:    cfg.pondName,
          Pond:        cfg.pondName,
          BatchId:     batchId,
          BatchNumber: cfg.num,
          'Feed Size 1 Gram': mix.fs1 > 0 ? Math.max(1, Math.round(sessionTotal * mix.fs1)) : '',
          'Feed Size 2 Gram': mix.fs2 > 0 ? Math.max(1, Math.round(sessionTotal * mix.fs2)) : '',
          'Feed Size 3 Gram': mix.fs3 > 0 ? Math.max(1, Math.round(sessionTotal * mix.fs3)) : '',
          'Feed Size 4 Gram': mix.fs4 > 0 ? Math.max(1, Math.round(sessionTotal * mix.fs4)) : '',
          'Feed Size 5 Gram': mix.fs5 > 0 ? Math.max(1, Math.round(sessionTotal * mix.fs5)) : '',
          'Other Feed Name':  '',
          'Other Feed Gram':  '',
          Notes: '',
          _ts: new Date(feedDate + 'T' + (time === '7:00 AM' ? '07' : time === '11:00 AM' ? '11' : time === '4:00 PM' ? '16' : '19') + ':00:00').toISOString()
        };
        demoRecords.push(rec);
      });
    }

    // 3. Generate growth entries
    const step = finalDOC <= 40 ? 5 : 10;
    const sampleDOCs = [];
    for (let d = 1; d <= finalDOC; d += step) sampleDOCs.push(d);
    if (sampleDOCs[sampleDOCs.length - 1] !== finalDOC) sampleDOCs.push(finalDOC);

    sampleDOCs.forEach(doc => {
      const entryDate = dateStr(today, cfg.stockOffset + doc - 1);
      if (entryDate > todayStr) return;

      const baseWeight = 0.05 + 0.00133 * doc * doc;
      const noise = 0.92 + rand() * 0.16;
      const weight = Math.round(baseWeight * noise * 1000) / 1000;

      demoGrowth.push({
        id:          `gt_demo_${bi + 1}_doc${doc}`,
        batchId:     batchId,
        batchNumber: cfg.num,
        pondId:      cfg.pondId,
        pondName:    cfg.pondName,
        date:        entryDate,
        doc:         doc,
        weightGrams: weight,
        notes:       doc === 1 ? 'Post-larvae stocked' : (doc === finalDOC && !cfg.active ? 'Harvest assessment' : ''),
        createdAt:   new Date(entryDate + 'T08:00:00').toISOString()
      });
    });

    // 4. Hapa entry — all batches at DOC >= 7 get one (lowered from 10 so
    //    young active batches still unlock population & biomass analytics)
    const hapaDoc = 7;
    const batchCurrentDOC = Math.abs(cfg.stockOffset);
    if (batchCurrentDOC >= hapaDoc || !cfg.active) {
      const hapaDate = dateStr(today, cfg.stockOffset + hapaDoc - 1);
      if (hapaDate <= todayStr) {
        const survived = Math.round(randBetween(78, 95));
        const survivalPct = Math.round(survived * 10) / 10;
        demoHapa.push({
          id:              `hapa_demo_${bi + 1}`,
          batchId,
          hapaDate,
          hapaStocked:     100,
          survived:        survived,
          survivalPercent: survivalPct,
          notes:           'Demo hapa check at DOC 7',
          recordedAt:      new Date(hapaDate + 'T10:00:00').toISOString()
        });
      }
    }

    // 5. Sampling entries — start at DOC 7 so even short active batches get
    //    ≥2 samplings, enabling FCR and daily-growth analytics.
    const finalDOCForSampling = Math.abs(cfg.stockOffset);
    const samplingStartDoc    = 7;
    if (finalDOCForSampling >= samplingStartDoc || !cfg.active) {
      const samplingDOCs = [];
      const maxSmpDoc = cfg.active ? finalDOCForSampling : cfg.duration;
      for (let d = samplingStartDoc; d <= maxSmpDoc; d += Math.floor(6 + rand() * 5)) {
        samplingDOCs.push(d);
      }
      // Guarantee the very last DOC is included for completed batches
      if (!cfg.active && (samplingDOCs[samplingDOCs.length - 1] !== cfg.duration)) {
        samplingDOCs.push(cfg.duration);
      }

      let prevAbw  = null;
      let prevDate = null;

      samplingDOCs.forEach((smpDoc, si) => {
        const smpDate = dateStr(today, cfg.stockOffset + smpDoc - 1);
        if (smpDate > todayStr) return;

        const baseAbw = 0.05 + 0.00133 * smpDoc * smpDoc;
        const noise   = 0.92 + rand() * 0.16;
        const abw     = Math.round(baseAbw * noise * 100) / 100;

        let growthSincePrev = null, daysSincePrev = null, dailyGrowth = null;
        if (prevAbw !== null && prevDate !== null) {
          growthSincePrev = Math.round((abw - prevAbw) * 1000) / 1000;
          const prevD  = startOfDay(prevDate);
          const curD   = startOfDay(smpDate);
          daysSincePrev = Math.floor((curD - prevD) / MS_PER_DAY);
          if (daysSincePrev > 0) dailyGrowth = Math.round((growthSincePrev / daysSincePrev) * 1000) / 1000;
        }

        const shrimpCountVal = Math.floor(80 + rand() * 40);
        const totalWeightVal = Math.round(abw * shrimpCountVal * 10) / 10;
        demoSampling.push({
          id:              `smp_demo_${bi + 1}_doc${smpDoc}`,
          batchId,
          batchNumber:     cfg.num,
          pondId:          cfg.pondId,
          date:            smpDate,
          doc:             smpDoc,
          totalCastWeight: totalWeightVal,
          shrimpCount:     shrimpCountVal,
          sampleCount:     shrimpCountVal,
          abw,
          notes:           si === 0 ? 'First sampling' : ((!cfg.active && smpDoc === cfg.duration) ? 'Pre-harvest final sample' : ''),
          growthSincePrev,
          daysSincePrev,
          dailyGrowth,
          createdAt:       new Date(smpDate + 'T09:00:00').toISOString(),
        });

        prevAbw  = abw;
        prevDate = smpDate;
      });
    }

    // 6. Biomass audit entries — one entry per sampling so the biomass
    //    estimation history panel shows a full trend.
    const hapaEntryForBatch = demoHapa.find(h => h.batchId === batchId);
    if (hapaEntryForBatch) {
      const survPct = hapaEntryForBatch.survivalPercent;
      const sampForBatch = demoSampling.filter(s => s.batchId === batchId);
      sampForBatch.forEach((s, sIdx) => {
        const estPop    = Math.round(cfg.count * (survPct / 100));
        const bioKg     = Math.round((estPop * s.abw) / 1000);
        demoBiomass.push({
          id:                  `bio_demo_${bi + 1}_s${sIdx}`,
          batchId,
          biomassKg:           bioKg,
          estimatedPopulation: estPop,
          stockedQuantity:     cfg.count,
          hapaSurvivalPercent: survPct,
          abw:                 s.abw,
          abwSource:           'sampling',
          timestamp:           new Date(s.date + 'T10:00:00').toISOString()
        });
      });
    }
  });

  /* ── Write to localStorage ── */
  // Clear legacy/existing sites and inventory transactions
  if (window.SiteManager) window.SiteManager.saveSites([]);
  AppStorage.saveAllInventoryTransactions([]);

  // Migrate ponds to generate new site IDs
  if (window.SiteManager) window.SiteManager.migrate(demoPonds);

  // M11 fix: add approximate locations to demo sites so Weather Intelligence works
  if (window.SiteManager) {
    const demoSites = window.SiteManager.loadSites();
    // Approximate coordinates for coastal Andhra Pradesh (major shrimp farming region)
    const demoLocations = {
      'aquafarm unit 1': { latitude: 16.5062, longitude: 80.6480, address: 'Vijayawada, Andhra Pradesh' },
      'aquafarm unit 2': { latitude: 14.4426, longitude: 79.9865, address: 'Nellore, Andhra Pradesh' },
      'aquafarm unit 3': { latitude: 17.6868, longitude: 83.2185, address: 'Visakhapatnam, Andhra Pradesh' },
    };
    demoSites.forEach(s => {
      const loc = demoLocations[s.name.toLowerCase()];
      if (loc) window.SiteManager.updateSite(s.id, loc);
    });
  }

  // Pre-generate Purchase transactions for each site to cover historical consumption
  const demoInventory = [];
  const startYear = today.getFullYear() - 1;
  const sites = window.SiteManager ? window.SiteManager.loadSites() : [];

  // Assign real coastal coordinates to each demo site so the Weather card,
  // weather alerts, and Farm Intelligence widgets all have a location to work
  // with immediately — without this, sites created by SiteManager.migrate()
  // have latitude/longitude = null and every weather feature shows "no location set".
  const DEMO_SITE_LOCATIONS = [
    { address: 'Surat, Gujarat, India',              latitude: 21.1702, longitude: 72.8311 },
    { address: 'Nellore, Andhra Pradesh, India',     latitude: 14.4426, longitude: 79.9865 },
    { address: 'Visakhapatnam, Andhra Pradesh, India', latitude: 17.6868, longitude: 83.2185 },
  ];
  sites.forEach((site, i) => {
    const loc = DEMO_SITE_LOCATIONS[i % DEMO_SITE_LOCATIONS.length];
    if (window.SiteManager) window.SiteManager.updateSite(site.id, loc);
  });

  sites.forEach(site => {
    // 1. Feed Purchases — initial bulk + 2 annual restocks so monthly-purchase
    //    charts show realistic repeated procurement over the 2-year history.
    for (let sizeNum = 1; sizeNum <= 5; sizeNum++) {
      const feedSizeName = `Feed Size ${sizeNum}`;
      // Year 0 initial bulk
      demoInventory.push({
        id: `demo_tx_feed_${site.id}_fs${sizeNum}_y0`,
        siteId: site.id, type: 'purchase', category: 'feed', itemName: feedSizeName,
        purchaseDate: `${startYear}-01-15`, supplier: 'CP Feed Distributors',
        quantity: 120000, unit: 'kg', unitPrice: 32.50, totalCost: 120000 * 32.50,
        referenceNumber: `PO-${startYear}-F${sizeNum}-A`,
        notes: 'Initial bulk stock — Year 1 (demo)',
        details: { feedBrand: 'CP Feed', feedSize: feedSizeName, bagWeight: 50, numberOfBags: 2400 },
        createdAt: new Date(`${startYear}-01-15T10:00:00`).toISOString(),
        updatedAt: new Date(`${startYear}-01-15T10:00:00`).toISOString()
      });
      // Mid-year restock Y0
      demoInventory.push({
        id: `demo_tx_feed_${site.id}_fs${sizeNum}_y0b`,
        siteId: site.id, type: 'purchase', category: 'feed', itemName: feedSizeName,
        purchaseDate: `${startYear}-07-10`, supplier: 'Growel Feeds Pvt Ltd',
        quantity: 90000, unit: 'kg', unitPrice: 33.20, totalCost: 90000 * 33.20,
        referenceNumber: `PO-${startYear}-F${sizeNum}-B`,
        notes: 'Mid-year restock (demo)',
        details: { feedBrand: 'Growel', feedSize: feedSizeName, bagWeight: 50, numberOfBags: 1800 },
        createdAt: new Date(`${startYear}-07-10T10:00:00`).toISOString(),
        updatedAt: new Date(`${startYear}-07-10T10:00:00`).toISOString()
      });
      // Year 1 start restock
      demoInventory.push({
        id: `demo_tx_feed_${site.id}_fs${sizeNum}_y1`,
        siteId: site.id, type: 'purchase', category: 'feed', itemName: feedSizeName,
        purchaseDate: `${startYear + 1}-01-20`, supplier: 'CP Feed Distributors',
        quantity: 100000, unit: 'kg', unitPrice: 34.00, totalCost: 100000 * 34.00,
        referenceNumber: `PO-${startYear + 1}-F${sizeNum}-A`,
        notes: 'Annual restock — Year 2 (demo)',
        details: { feedBrand: 'CP Feed', feedSize: feedSizeName, bagWeight: 50, numberOfBags: 2000 },
        createdAt: new Date(`${startYear + 1}-01-20T10:00:00`).toISOString(),
        updatedAt: new Date(`${startYear + 1}-01-20T10:00:00`).toISOString()
      });
      // Current month top-up
      const currMonthPurchase = dateStr(today, -5);
      demoInventory.push({
        id: `demo_tx_feed_${site.id}_fs${sizeNum}_y2`,
        siteId: site.id, type: 'purchase', category: 'feed', itemName: feedSizeName,
        purchaseDate: currMonthPurchase, supplier: 'CP Feed Distributors',
        quantity: 80000, unit: 'kg', unitPrice: 34.50, totalCost: 80000 * 34.50,
        referenceNumber: `PO-${startYear + 1}-F${sizeNum}-C`,
        notes: 'Recent top-up (demo)',
        details: { feedBrand: 'CP Feed', feedSize: feedSizeName, bagWeight: 50, numberOfBags: 1600 },
        createdAt: new Date(`${currMonthPurchase}T10:00:00`).toISOString(),
        updatedAt: new Date(`${currMonthPurchase}T10:00:00`).toISOString()
      });
    }

    // 2. Medicine Purchases — expanded to 8 categories so every bar in the
    //    medicine category breakdown fills with real data.
    const meds = [
      { name: 'Super Probiotics',     cat: 'Probiotics',       qty: 600,  price: 450,  unit: 'Bottle' },
      { name: 'Eco Minerals Plus',    cat: 'Minerals',         qty: 1200, price: 180,  unit: 'Bag'    },
      { name: 'Vitasol C',            cat: 'Vitamins',         qty: 400,  price: 650,  unit: 'Packet' },
      { name: 'AquaLime Plus',        cat: 'Lime',             qty: 2000, price: 28,   unit: 'Bag'    },
      { name: 'PureSalt',             cat: 'Salt',             qty: 5000, price: 12,   unit: 'kg'     },
      { name: 'BioMolasses',          cat: 'Molasses',         qty: 800,  price: 55,   unit: 'Liter'  },
      { name: 'ClearWater Treatment', cat: 'Water Treatment',  qty: 500,  price: 320,  unit: 'Bottle' },
      { name: 'AquaZeolite',          cat: 'Zeolite',          qty: 1500, price: 40,   unit: 'Bag'    },
    ];
    meds.forEach((med, mi) => {
      demoInventory.push({
        id: `demo_tx_med_${site.id}_${mi}`,
        siteId: site.id, type: 'purchase', category: 'medicine', itemName: med.name,
        purchaseDate: `${startYear}-01-20`, supplier: 'BioAqua Labs',
        quantity: med.qty, unit: med.unit, unitPrice: med.price, totalCost: med.qty * med.price,
        referenceNumber: `PO-${startYear}-M${mi}`,
        notes: 'Initial supplements purchase for demo',
        details: { itemName: med.name, category: med.cat, unit: med.unit, expiryDate: `${today.getFullYear() + 1}-12-31` },
        createdAt: new Date(`${startYear}-01-20T11:00:00`).toISOString(),
        updatedAt: new Date(`${startYear}-01-20T11:00:00`).toISOString()
      });
      // Year-2 restock for high-use items
      if (['Super Probiotics','Vitasol C','ClearWater Treatment'].includes(med.name)) {
        demoInventory.push({
          id: `demo_tx_med_${site.id}_${mi}_y2`,
          siteId: site.id, type: 'purchase', category: 'medicine', itemName: med.name,
          purchaseDate: `${startYear + 1}-02-15`, supplier: 'AquaVet Supplies',
          quantity: Math.round(med.qty * 0.8), unit: med.unit,
          unitPrice: med.price * 1.05, totalCost: Math.round(med.qty * 0.8) * med.price * 1.05,
          referenceNumber: `PO-${startYear + 1}-M${mi}-R`,
          notes: 'Year-2 restock (demo)',
          details: { itemName: med.name, category: med.cat, unit: med.unit, expiryDate: `${today.getFullYear() + 2}-06-30` },
          createdAt: new Date(`${startYear + 1}-02-15T11:00:00`).toISOString(),
          updatedAt: new Date(`${startYear + 1}-02-15T11:00:00`).toISOString()
        });
      }
    });

    // 3. Fuel Purchases — 3 types + annual restocks
    const fuels = [
      { name: 'Diesel',    qty: 30000, price: 92.50,  unit: 'Liter' },
      { name: 'Petrol',    qty: 6000,  price: 104.20, unit: 'Liter' },
      { name: 'Lubricant', qty: 500,   price: 215.00, unit: 'Liter' },
    ];
    fuels.forEach((fuel, fi) => {
      // Year 0
      demoInventory.push({
        id: `demo_tx_fuel_${site.id}_${fi}`,
        siteId: site.id, type: 'purchase', category: 'fuel', itemName: fuel.name,
        purchaseDate: `${startYear}-01-10`, supplier: 'State Fuel Corp',
        quantity: fuel.qty, unit: fuel.unit, unitPrice: fuel.price, totalCost: fuel.qty * fuel.price,
        referenceNumber: `PO-${startYear}-FL${fi}`,
        notes: 'Fuel bulk procurement for farm generators (demo)',
        details: { fuelType: fuel.name, quantity: fuel.qty, pricePerLiter: fuel.price },
        createdAt: new Date(`${startYear}-01-10T09:00:00`).toISOString(),
        updatedAt: new Date(`${startYear}-01-10T09:00:00`).toISOString()
      });
      // Year 1 restock
      demoInventory.push({
        id: `demo_tx_fuel_${site.id}_${fi}_y1`,
        siteId: site.id, type: 'purchase', category: 'fuel', itemName: fuel.name,
        purchaseDate: `${startYear + 1}-01-12`, supplier: 'IndianOil Retail',
        quantity: Math.round(fuel.qty * 0.9), unit: fuel.unit,
        unitPrice: fuel.price * 1.08, totalCost: Math.round(fuel.qty * 0.9) * fuel.price * 1.08,
        referenceNumber: `PO-${startYear + 1}-FL${fi}`,
        notes: 'Annual fuel restock (demo)',
        details: { fuelType: fuel.name, pricePerLiter: fuel.price * 1.08 },
        createdAt: new Date(`${startYear + 1}-01-12T09:00:00`).toISOString(),
        updatedAt: new Date(`${startYear + 1}-01-12T09:00:00`).toISOString()
      });
    });

    // 4. Medicine consumption — varied dosing so stock balances differ per item,
    //    giving the inventory dashboard non-trivial data to display.
    const medPurchaseDate = new Date(`${startYear}-01-20T00:00:00`);
    const daysSinceMedBuy = Math.floor((today - medPurchaseDate) / MS_PER_DAY);
    const medDosingPlans = [
      { name: 'Super Probiotics',     unit: 'Bottle', perDose: 3,  intervalDays: 14  },
      { name: 'Eco Minerals Plus',    unit: 'Bag',     perDose: 5,  intervalDays: 21  },
      { name: 'Vitasol C',            unit: 'Packet',  perDose: 8,  intervalDays: 7   }, // heavy use → low stock
      { name: 'AquaLime Plus',        unit: 'Bag',     perDose: 20, intervalDays: 30  },
      { name: 'PureSalt',             unit: 'kg',      perDose: 50, intervalDays: 30  },
      { name: 'BioMolasses',          unit: 'Liter',   perDose: 10, intervalDays: 21  },
      { name: 'ClearWater Treatment', unit: 'Bottle',  perDose: 4,  intervalDays: 14  },
      { name: 'AquaZeolite',          unit: 'Bag',     perDose: 15, intervalDays: 45  },
    ];
    medDosingPlans.forEach((plan, pi) => {
      for (let d = plan.intervalDays; d <= daysSinceMedBuy; d += plan.intervalDays) {
        const txDate = dateStr(medPurchaseDate, d);
        if (txDate > todayStr) break;
        demoInventory.push({
          id: `demo_tx_medcons_${site.id}_${pi}_${d}`,
          siteId: site.id, type: 'consumption', category: 'medicine', itemName: plan.name,
          purchaseDate: txDate, supplier: '', quantity: plan.perDose, unit: plan.unit,
          unitPrice: 0, totalCost: 0,
          referenceNumber: `demo_dose_${site.id}_${pi}_${d}`,
          notes: 'Routine dosing (demo)',
          details: { source: 'demo_seed' },
          createdAt: new Date(txDate + 'T08:00:00').toISOString(),
          updatedAt: new Date(txDate + 'T08:00:00').toISOString()
        });
      }
    });

    // 5. Fuel consumption — three usage patterns (generators, vehicles, maintenance)
    const fuelPurchaseDate = new Date(`${startYear}-01-10T00:00:00`);
    const daysSinceFuelBuy = Math.floor((today - fuelPurchaseDate) / MS_PER_DAY);
    const fuelUsagePlans = [
      { name: 'Diesel',    unit: 'Liter', perDose: 140, intervalDays: 7  }, // aerator generators weekly
      { name: 'Petrol',   unit: 'Liter', perDose: 18,  intervalDays: 14 }, // transport bi-weekly
      { name: 'Lubricant',unit: 'Liter', perDose: 4,   intervalDays: 30 }, // machinery monthly
    ];
    fuelUsagePlans.forEach((plan, pi) => {
      for (let d = plan.intervalDays; d <= daysSinceFuelBuy; d += plan.intervalDays) {
        const txDate = dateStr(fuelPurchaseDate, d);
        if (txDate > todayStr) break;
        demoInventory.push({
          id: `demo_tx_fuelcons_${site.id}_${pi}_${d}`,
          siteId: site.id, type: 'consumption', category: 'fuel', itemName: plan.name,
          purchaseDate: txDate, supplier: '', quantity: plan.perDose, unit: plan.unit,
          unitPrice: 0, totalCost: 0,
          referenceNumber: `demo_fuel_use_${site.id}_${pi}_${d}`,
          notes: 'Generator/aerator/vehicle run-time (demo)',
          details: { source: 'demo_seed' },
          createdAt: new Date(txDate + 'T18:00:00').toISOString(),
          updatedAt: new Date(txDate + 'T18:00:00').toISOString()
        });
      }
    });
  });

  // 6. One-off transactions (only for the first site) covering the remaining
  //    transaction types so every code path in InventoryManager gets exercised:
  //    manual_adjustment, transfer_out/transfer_in, expired, damaged.
  if (sites.length) {
    const s0 = sites[0].id;
    const s1 = sites.length > 1 ? sites[1].id : s0;
    const recentDate = dateStr(today, -14);
    const olderDate  = dateStr(today, -45);

    demoInventory.push(
      {
        id: `demo_tx_adjust_${s0}`, siteId: s0, type: 'manual_adjustment', category: 'feed',
        itemName: 'Feed Size 3', purchaseDate: recentDate, supplier: '', quantity: -25, unit: 'kg',
        unitPrice: 0, totalCost: 0, referenceNumber: `demo_adjust_${s0}`,
        notes: 'Physical stock count correction (demo) — spillage during transfer',
        details: { source: 'demo_seed' },
        createdAt: new Date(recentDate + 'T12:00:00').toISOString(),
        updatedAt: new Date(recentDate + 'T12:00:00').toISOString()
      },
      {
        id: `demo_tx_transferout_${s0}`, siteId: s0, type: 'transfer_out', category: 'medicine',
        itemName: 'Eco Minerals Plus', purchaseDate: olderDate, supplier: '', quantity: 50, unit: 'Bag',
        unitPrice: 0, totalCost: 0, referenceNumber: `demo_transfer_${s0}_${s1}`,
        notes: `Transferred to ${sites.length > 1 ? sites[1].name : 'sister site'} (demo)`,
        details: { source: 'demo_seed' },
        createdAt: new Date(olderDate + 'T10:00:00').toISOString(),
        updatedAt: new Date(olderDate + 'T10:00:00').toISOString()
      },
      {
        id: `demo_tx_transferin_${s1}`, siteId: s1, type: 'transfer_in', category: 'medicine',
        itemName: 'Eco Minerals Plus', purchaseDate: olderDate, supplier: '', quantity: 50, unit: 'Bag',
        unitPrice: 0, totalCost: 0, referenceNumber: `demo_transfer_${s0}_${s1}`,
        notes: `Received from ${sites[0].name} (demo)`,
        details: { source: 'demo_seed' },
        createdAt: new Date(olderDate + 'T10:05:00').toISOString(),
        updatedAt: new Date(olderDate + 'T10:05:00').toISOString()
      },
      {
        id: `demo_tx_expired_${s0}`, siteId: s0, type: 'expired', category: 'medicine',
        itemName: 'Vitasol C', purchaseDate: olderDate, supplier: '', quantity: 10, unit: 'Packet',
        unitPrice: 0, totalCost: 0, referenceNumber: `demo_expired_${s0}`,
        notes: 'Past expiry date, written off (demo)',
        details: { source: 'demo_seed' },
        createdAt: new Date(olderDate + 'T09:00:00').toISOString(),
        updatedAt: new Date(olderDate + 'T09:00:00').toISOString()
      },
      {
        id: `demo_tx_damaged_${s0}`, siteId: s0, type: 'damaged', category: 'fuel',
        itemName: 'Diesel', purchaseDate: recentDate, supplier: '', quantity: 20, unit: 'Liter',
        unitPrice: 0, totalCost: 0, referenceNumber: `demo_damaged_${s0}`,
        notes: 'Leaked drum, written off (demo)',
        details: { source: 'demo_seed' },
        createdAt: new Date(recentDate + 'T15:00:00').toISOString(),
        updatedAt: new Date(recentDate + 'T15:00:00').toISOString()
      }
    );
  }

  // 7. Weather history — seed ~90 days of daily snapshots per site so weather
  //    trend views aren't empty on a fresh demo load (normally this only fills
  //    in one day at a time as WeatherService successfully fetches live data).
  const demoWeatherHistory = [];
  const WEATHER_HISTORY_DAYS = 90;

  // Work out which real calendar dates the cyclone hit, and which site's
  // pond it affected, so the Weather Intelligence trend view shows the same
  // storm event that suspended feeding on the batch above.
  const cycloneCfg = batchConfigs.find(c => c.cycloneDays);
  let cycloneSiteId = null;
  const cycloneDateSet = new Set();
  if (cycloneCfg) {
    const cyclonePond = demoPonds.find(p => p.id === cycloneCfg.pondId);
    const cycloneSite = sites.find(s => s.name === (cyclonePond && cyclonePond.site));
    cycloneSiteId = cycloneSite ? cycloneSite.id : null;
    for (let doc = cycloneCfg.cycloneDays[0]; doc <= cycloneCfg.cycloneDays[1]; doc++) {
      cycloneDateSet.add(dateStr(today, cycloneCfg.stockOffset + doc - 1));
    }
  }

  sites.forEach(site => {
    for (let d = WEATHER_HISTORY_DAYS; d >= 0; d--) {
      const wDate = dateStr(today, -d);
      const isCycloneDay = site.id === cycloneSiteId && cycloneDateSet.has(wDate);
      let temperature, humidity, rainProbability;
      if (isCycloneDay) {
        temperature = Math.round((24 + randBetween(-1, 1)) * 10) / 10;
        humidity = Math.round(92 + randBetween(-4, 4));
        rainProbability = Math.round(90 + randBetween(0, 10));
      } else {
        const seasonal = Math.sin((d / 365) * Math.PI * 2);
        temperature = Math.round((29 + seasonal * 2 + randBetween(-1.5, 1.5)) * 10) / 10;
        humidity    = Math.round(70 + randBetween(-12, 12));
        rainProbability = Math.max(0, Math.min(100, Math.round(randBetween(-20, 60))));
      }
      demoWeatherHistory.push({
        siteId: site.id,
        date: wDate,
        temperature,
        humidity,
        rainProbability,
        feedGiven: 0,
        growthWeight: null
      });
    }
  });
  try {
    localStorage.setItem('al_weather_history', JSON.stringify(demoWeatherHistory));
  } catch { /* ignore quota errors, non-critical for demo */ }

  // Seed a "just fetched" reading per site so the live Weather card renders
  // real-looking data immediately (within the 30-min cache TTL) instead of
  // showing a loading/offline state until the next real API call succeeds.
  try {
    const weatherCache = {};
    sites.forEach(site => {
      const seasonal = Math.sin((0 / 365) * Math.PI * 2);
      const temperature = Math.round((29 + seasonal * 2 + randBetween(-1.5, 1.5)) * 10) / 10;
      const humidity = Math.round(70 + randBetween(-12, 12));
      const rainProbability = Math.max(0, Math.min(100, Math.round(randBetween(-20, 60))));
      weatherCache[site.id] = {
        temperature,
        humidity,
        rainProbability,
        windSpeed: Math.round(randBetween(5, 18) * 10) / 10,
        pressure: Math.round(randBetween(1006, 1015)),
        uvIndex: Math.round(randBetween(4, 10)),
        condition: rainProbability > 55 ? 'Light Rain' : (rainProbability > 30 ? 'Partly Cloudy' : 'Mostly Clear'),
        timestamp: new Date().toISOString(),
      };
    });
    localStorage.setItem('al_weather_cache', JSON.stringify(weatherCache));
  } catch { /* ignore quota errors, non-critical for demo */ }

  /* ── Finance module demo data: market prices, sale revenue, manual expenses ──
     Without this, the Finance page (Overview / Expenses / Revenue / Prices
     tabs) renders completely empty on a fresh demo load. ── */
  const demoMarketPrices = [];
  const demoRevenue      = [];
  const demoExpenses     = [];

  const SIZE_CATEGORIES  = ['Count 30', 'Count 40', 'Count 50', 'Count 60', 'Count 70'];
  const MARKET_LOCATIONS = ['Kakinada Fish Market', 'Nellore Wholesale Market', 'Visakhapatnam Export Hub'];
  const BUYERS = ['Sea Gold Exports', 'Coastal Traders Pvt Ltd', 'Krishna Aqua Exports', 'Local Wholesale Buyer', 'Bay Fresh Seafoods'];

  // Market prices — twice-monthly entries for ~2 years with seasonal swing,
  // random noise, and a slight upward trend into the present.
  for (let d = 730; d >= 0; d -= 15) {
    const pDate = dateStr(today, -d);
    if (pDate > todayStr) continue;
    const seasonal  = Math.sin(((730 - d) / 365) * Math.PI * 2);
    const yearsAgo  = d / 365;
    const base      = 300 + (2 - yearsAgo) * 8;
    const price     = Math.max(180, Math.round(base + seasonal * 18 + randBetween(-12, 12)));
    demoMarketPrices.push({
      id: `demo_price_${d}`,
      date: pDate,
      pricePerKg: price,
      sizeCategory: SIZE_CATEGORIES[randInt(0, SIZE_CATEGORIES.length - 1)],
      location: MARKET_LOCATIONS[randInt(0, MARKET_LOCATIONS.length - 1)],
      createdAt: new Date(pDate + 'T09:00:00').toISOString()
    });
  }
  demoMarketPrices.sort((a, b) => a.date.localeCompare(b.date));

  function marketPriceNear(dateVal) {
    if (!demoMarketPrices.length) return 320;
    let closest = demoMarketPrices[0];
    let bestDiff = Infinity;
    demoMarketPrices.forEach(p => {
      const diff = Math.abs(new Date(p.date) - new Date(dateVal));
      if (diff < bestDiff) { bestDiff = diff; closest = p; }
    });
    return closest.pricePerKg;
  }

  demoBatches.forEach((batch, bi) => {
    const cfg     = batchConfigs[bi];
    const pond    = demoPonds.find(p => p.id === batch.pondId);
    const site    = sites.find(s => s.name === (pond && pond.site));
    const siteId  = site ? site.id : null;

    // Seed / post-larvae cost at stocking — not auto-tracked via inventory,
    // so every batch gets a manual "seed" expense.
    const plPrice = 0.30 + rand() * 0.15; // ₹ per post-larvae
    demoExpenses.push({
      id: `demo_exp_seed_${batch.id}`,
      date: batch.stockingDate, category: 'seed',
      amount: Math.round(batch.shrimpCount * plPrice),
      description: `Post-larvae stocking — ${batch.shrimpCount.toLocaleString('en-IN')} PL`,
      batchId: batch.id, pondId: batch.pondId, siteId,
      createdAt: new Date(batch.stockingDate + 'T07:00:00').toISOString()
    });

    // Extra emergency-treatment cost for the disease-outbreak batch.
    if (cfg.diseaseOutbreak) {
      const outbreakDate = dateStr(today, cfg.stockOffset + Math.round(cfg.duration * 0.55) - 1);
      demoExpenses.push({
        id: `demo_exp_wssv_${batch.id}`,
        date: outbreakDate, category: 'medicine',
        amount: 48000,
        description: 'Emergency WSSV response — water exchange, extra probiotics & lab testing',
        batchId: batch.id, pondId: batch.pondId, siteId,
        createdAt: new Date(outbreakDate + 'T14:00:00').toISOString()
      });
    }

    // Revenue — only completed batches get a sale. Larger harvests are
    // sometimes split into two sales (part live, part processed).
    if (batch.status === 'completed' && batch.harvestWeightKg) {
      const priceAtHarvest = marketPriceNear(batch.harvestDate);
      if (batch.harvestWeightKg > 4000 && rand() < 0.6) {
        const splitKg     = Math.round(batch.harvestWeightKg * (0.55 + rand() * 0.1));
        const remainderKg = batch.harvestWeightKg - splitKg;
        const price1      = Math.round(priceAtHarvest * (0.98 + rand() * 0.06));
        const price2      = Math.round(priceAtHarvest * (0.95 + rand() * 0.08));
        const saleDate2   = dateStr(batch.harvestDate, 2) > todayStr ? batch.harvestDate : dateStr(batch.harvestDate, 2);
        demoRevenue.push({
          id: `demo_rev_${batch.id}_a`, date: batch.harvestDate, batchId: batch.id,
          weightKg: splitKg, pricePerKg: price1, buyer: BUYERS[randInt(0, BUYERS.length - 1)],
          siteId, totalAmount: +(splitKg * price1).toFixed(2),
          createdAt: new Date(batch.harvestDate + 'T17:30:00').toISOString()
        });
        demoRevenue.push({
          id: `demo_rev_${batch.id}_b`, date: saleDate2, batchId: batch.id,
          weightKg: remainderKg, pricePerKg: price2, buyer: BUYERS[randInt(0, BUYERS.length - 1)],
          siteId, totalAmount: +(remainderKg * price2).toFixed(2),
          createdAt: new Date(saleDate2 + 'T11:00:00').toISOString()
        });
      } else {
        const price = Math.round(priceAtHarvest * (0.97 + rand() * 0.08));
        demoRevenue.push({
          id: `demo_rev_${batch.id}`, date: batch.harvestDate, batchId: batch.id,
          weightKg: batch.harvestWeightKg, pricePerKg: price, buyer: BUYERS[randInt(0, BUYERS.length - 1)],
          siteId, totalAmount: +(batch.harvestWeightKg * price).toFixed(2),
          createdAt: new Date(batch.harvestDate + 'T17:30:00').toISOString()
        });
      }
    }
  });

  // Recurring operating expenses per site: monthly labor & electricity,
  // quarterly maintenance, annual rent, and one equipment purchase.
  sites.forEach((site, si) => {
    for (let monthsAgo = 24; monthsAgo >= 0; monthsAgo--) {
      const mDate = dateStr(today, -monthsAgo * 30);
      if (mDate > todayStr) continue;
      demoExpenses.push({
        id: `demo_exp_labor_${site.id}_${monthsAgo}`,
        date: mDate, category: 'labor', amount: Math.round(randBetween(16000, 24000)),
        description: 'Monthly farm labor wages',
        batchId: null, pondId: null, siteId: site.id,
        createdAt: new Date(mDate + 'T18:00:00').toISOString()
      });
      const seasonal = Math.sin(((monthsAgo % 12) / 12) * Math.PI * 2);
      demoExpenses.push({
        id: `demo_exp_elec_${site.id}_${monthsAgo}`,
        date: mDate, category: 'electricity',
        amount: Math.round(12000 + seasonal * 3000 + randBetween(-1500, 1500)),
        description: 'Aerator & pump electricity bill',
        batchId: null, pondId: null, siteId: site.id,
        createdAt: new Date(mDate + 'T18:05:00').toISOString()
      });
    }
    for (let q = 8; q >= 0; q--) {
      const qDate = dateStr(today, -q * 90);
      if (qDate > todayStr) continue;
      demoExpenses.push({
        id: `demo_exp_maint_${site.id}_${q}`,
        date: qDate, category: 'maintenance', amount: Math.round(randBetween(6000, 15000)),
        description: 'Pond liner/dyke repair & sludge removal',
        batchId: null, pondId: null, siteId: site.id,
        createdAt: new Date(qDate + 'T10:00:00').toISOString()
      });
    }
    [dateStr(today, -385), dateStr(today, -20)].forEach((rDate, ri) => {
      demoExpenses.push({
        id: `demo_exp_rent_${site.id}_${ri}`,
        date: rDate, category: 'rent', amount: Math.round(randBetween(120000, 230000)),
        description: 'Annual pond lease / land rent',
        batchId: null, pondId: null, siteId: site.id,
        createdAt: new Date(rDate + 'T09:00:00').toISOString()
      });
    });
    demoExpenses.push({
      id: `demo_exp_equip_${site.id}`,
      date: dateStr(today, -Math.round(randBetween(150, 400))), category: 'equipment',
      amount: Math.round(randBetween(35000, 90000)),
      description: si === 0 ? 'Paddlewheel aerator replacement (2 units)' : 'Submersible pump + backup motor',
      batchId: null, pondId: null, siteId: site.id,
      createdAt: new Date().toISOString()
    });
  });

  AppStorage.saveMarketPrices(demoMarketPrices);
  AppStorage.saveFinanceRevenue(demoRevenue);
  AppStorage.saveFinanceExpenses(demoExpenses);

  // Save the pre-generated purchase inventory transactions
  AppStorage.saveAllInventoryTransactions(demoInventory);

  /* —— Write to storage via AppStorage —— */
  AppStorage.bulkSet({
    ponds   : demoPonds,
    batches : demoBatches,
    records : demoRecords,
    queue   : [],
    growth  : demoGrowth,
    hapa    : demoHapa,
    sampling: demoSampling,
  });
  // Save biomass separately (not in bulkSet keys but has its own storage method)
  AppStorage.saveBiomass(demoBiomass);

  /* ── Update in-memory state ── */
  state.setPonds(demoPonds);
  state.setBatches(demoBatches);
  state.setRecords(demoRecords);
  state.setOfflineQ([]);
  state.setGrowthEntries(demoGrowth);
  state.setHapaEntries(demoHapa);
  state.setSamplingEntries(demoSampling);
  state.setBiomassEntries(demoBiomass);  // populated instead of cleared

  /* ── Repopulate inventory site selects with freshly-migrated site IDs ──
     Without this, inventorySiteSelect.value is stale/empty and
     renderInventoryDashboard() silently returns on its !siteId guard. ── */
  const _demoFreshSites  = window.SiteManager ? window.SiteManager.loadSites() : [];
  const _demoFirstSiteId = _demoFreshSites[0]?.id;
  if (_demoFirstSiteId) {
    ['inventorySiteSelect', 'feedDetailSiteSelect', 'medDetailSiteSelect',
     'fuelDetailSiteSelect', 'reportsSiteSelect'].forEach(function(selId) {
      if (typeof populateInventorySiteSelect === 'function') {
        populateInventorySiteSelect(selId, _demoFirstSiteId);
      }
    });
    if (typeof renderInventoryDashboard === 'function') {
      renderInventoryDashboard();
    }
  }

  /* ── Refresh all views immediately so UI isn't blocked ── */
  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  if (currentPage === 'pageReports') renderReportsTab(reportTab);
  if (currentPage === 'pageFinance' && typeof renderFinancePage === 'function') renderFinancePage();

  alSelects.feedTime?.sync();
  alSelects.editFeedTime?.sync();

  const totalRecs = demoRecords.length;
  showToast('🚀', 'Demo Data Loaded!', `2 years history · ${totalRecs} feed sessions — syncing recent inventory…`);

  /* ── Run the heavy backfill off the main thread via setTimeout ── */
  /* Q5 fix: pass limitDays=60 so we only sync the last 60 days of consumption.
     Without this, ~30K transactions would overflow localStorage's 5MB quota. */
  setTimeout(() => {
    if (typeof window.InventoryManager === 'object') {
      try {
        window.InventoryManager.backfillHistoricalFeedConsumption(60);
      } catch (e) {
        console.warn('[AquaLog] Demo inventory backfill failed (non-fatal):', e);
      }
    }
    showToast('✅', 'Inventory Ready', 'Feed consumption (last 60 days) synced to inventory.');
  }, 100);
}

// Window bindings for backward compatibility
window.applyTheme = applyTheme;
window.bindSettingsEvents = bindSettingsEvents;
window.initOutdoorMode = initOutdoorMode;
window.initFontSizeToggle = initFontSizeToggle;
// Removed: initTheme, renderSettingsPage, applyM3Theme, initMaterialYouTheme
// (light theme + Appearance settings section deleted — app is permanently dark)
window.populateSiteSelect = populateSiteSelect;
window.lookupSiteIdByName = lookupSiteIdByName;
window.bindPondSiteSelectNewSiteOption = bindPondSiteSelectNewSiteOption;
window.resetCreateSiteModal = resetCreateSiteModal;
window.openCreateSiteModal = openCreateSiteModal;
window.closeCreateSiteModal = closeCreateSiteModal;
window.openEditSiteModal = openEditSiteModal;
window.confirmDeleteSite = confirmDeleteSite;
window.setStagedSiteLocation = setStagedSiteLocation;
window.handleSiteSearch = handleSiteSearch;
window.handleSiteUseGPS = handleSiteUseGPS;
window.doCreateSite = doCreateSite;
window.renderSitesSettings = renderSitesSettings;
window.renderManageSites = renderManageSites;
window.getPrimarySiteForDashboard = getPrimarySiteForDashboard;
window.loadApiSettings = loadApiSettings;
window.saveApiSettings = saveApiSettings;
window.loadDemoData = loadDemoData;
window._executeDemoDataLoad = _executeDemoDataLoad;

// MODAL_STATE_CLEANUP Registrations
window.MODAL_STATE_CLEANUP = window.MODAL_STATE_CLEANUP || {};
window.MODAL_STATE_CLEANUP.createSiteModal = () => { pendingPondSiteSelectId = null; };
})();

// --- Module: reports.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

let reportDebounceTimeout = null;

let reportsState = {
  selectedSiteId: '',
  reportType: 'feed_purchase',
  searchQuery: '',
  dateFrom: '',
  dateTo: '',
  category: '',
  fuelType: '',
  txType: '',
  lowStockOnly: false,
  outOfStockOnly: false,
  expiringOnly: false,
  currentPage: 1,
  pageSize: 50,
  totalPages: 1,
  currentData: [],
  sortColumn: '',
  sortAsc: true
};

function bindReportEvents() {
  const reportTabs = $('reportTabs');
  if (reportTabs) {
    reportTabs.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        reportTabs.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        document.querySelectorAll('.tab-panel').forEach(p => { p.classList.remove('active'); p.classList.add('hidden'); });
        const panel = $(`tab${capitalize(btn.dataset.tab)}`);
        if (panel) {
          panel.classList.remove('hidden');
          panel.classList.add('active');
          panel.style.animation = 'none';
          panel.offsetHeight; // force reflow
          panel.style.animation = '';
        }
        reportTab = btn.dataset.tab;
        renderReportsTab(reportTab);
      });
    });
  }

  // Navigation buttons — null-guarded addEventListener replaces .onclick=
  $('dailyPrev')?.addEventListener('click',   () => { dailyCursor--; renderDaily(); });
  $('dailyNext')?.addEventListener('click',   () => { if (dailyCursor < 0) { dailyCursor++; renderDaily(); } });
  $('weeklyPrev')?.addEventListener('click',  () => { weeklyCursor--; renderWeekly(); });
  $('weeklyNext')?.addEventListener('click',  () => { if (weeklyCursor < 0) { weeklyCursor++; renderWeekly(); } });
  $('monthlyPrev')?.addEventListener('click', () => { monthlyCursor--; renderMonthly(); });
  $('monthlyNext')?.addEventListener('click', () => { if (monthlyCursor < 0) { monthlyCursor++; renderMonthly(); } });


  $('historySearch')?.addEventListener('input', renderHistory);
  $('csvExportBtn')?.addEventListener('click', exportCSV);
  $('syncBtn')?.addEventListener('click', syncQueue);

  // Delegated click listener on historyList (avoids once:true deletion bug)
  $('historyList')?.addEventListener('click', (e) => {
    const editBtn = e.target.closest('.icon-btn.edit');
    const delBtn  = e.target.closest('.icon-btn.del');
    if (editBtn) openEditFeedModal(+editBtn.dataset.idx);
    if (delBtn)  confirmDelete(+delBtn.dataset.idx);
  });
}

function renderReportsTab(tab) {
  if (tab === 'daily')   renderDaily();
  if (tab === 'weekly')  renderWeekly();
  if (tab === 'monthly') renderMonthly();
  if (tab === 'history') renderHistory();
}

function renderDaily() {
  const d = new Date();
  d.setDate(d.getDate() + dailyCursor);
  const key = fmt(d);
  const _dailyLabel = $('dailyLabel'); if (_dailyLabel) _dailyLabel.textContent = d.toLocaleDateString('en-IN',{weekday:'short',day:'numeric',month:'short',year:'numeric'});

  const recs = records.filter(r => r.Date === key);
  const total = sumGrams(recs);

  const _dailyStats = $('dailyStats');
  if (_dailyStats) renderStatStrip(_dailyStats, [
    { val: fmtGrams(total)+'g', lbl: 'Total Feed' },
    { val: recs.length, lbl: 'Sessions' },
    { val: new Set(recs.map(r=>r.PondId||r.Pond)).size, lbl: 'Ponds' },
  ]);

  const _dailySessions = $('dailySessions'); if (_dailySessions) renderSessionsList(_dailySessions, recs.slice().reverse());
  const _dailyPondList = $('dailyPondList'); if (_dailyPondList) renderPondBreakdown(_dailyPondList, recs);
}

function renderWeekly() {
  const { start, end } = getWeekRange(weeklyCursor);
  const _weeklyLabel = $('weeklyLabel'); if (_weeklyLabel) _weeklyLabel.textContent = `${start.toLocaleDateString('en-IN',{day:'numeric',month:'short'})} – ${end.toLocaleDateString('en-IN',{day:'numeric',month:'short',year:'numeric'})}`;

  const recs = records.filter(r => {
    const d = new Date(r.Date + 'T00:00:00'); // H1 fix: parse as local
    return d >= start && d <= end;
  });
  const total = sumGrams(recs);
  const avgPerDay = recs.length ? Math.round(total/7) : 0;

  const _weeklyStats = $('weeklyStats');
  if (_weeklyStats) renderStatStrip(_weeklyStats, [
    { val: fmtGrams(total)+'g', lbl: 'Total Feed' },
    { val: fmtGrams(avgPerDay)+'g', lbl: 'Avg/Day' },
    { val: recs.length, lbl: 'Sessions' },
  ]);

  const days = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    const key  = fmt(d);
    const dRec = records.filter(r => r.Date === key);
    const pondSet  = [...new Set(dRec.map(r => r.PondName || r.Pond || 'Unknown'))];
    const feedDist = feedSizeDistribution(dRec);
    days.push({
      label: d.toLocaleDateString('en-IN',{weekday:'short'}),
      value: sumGrams(dRec),
      _meta: { type: 'farm-day', dateStr: key, dateLabel: d.toLocaleDateString('en-IN',{weekday:'long',day:'numeric',month:'short'}), sessions: dRec.length, ponds: pondSet, feedDist }
    });
  }
  setTimeout(() => {
    const weeklyCanvas = $('chartWeeklyBar');
    if (weeklyCanvas) {
      const weeklyDesc = "Weekly feed trend: " + days.map(d => `${d.label}: ${fmtGrams(d.value)}g`).join(', ');
      weeklyCanvas.setAttribute('role', 'img');
      weeklyCanvas.setAttribute('aria-label', weeklyDesc);
      weeklyCanvas._onBarClick = (bar) => showBarDetailModal(bar._meta, '#38bdf8');
    }
    drawBarChart('chartWeeklyBar', days, { color: '#38bdf8' });

    // Update weekly summary box
    const summaryBox = $('weeklyChartSummary');
    if (summaryBox) {
      if (recs.length > 0) {
        let highest = days[0];
        let lowest = days[0];
        days.forEach(d => {
          if (d.value > highest.value) highest = d;
          if (d.value < lowest.value) lowest = d;
        });
        const startDay = days[0];
        const endDay = days[6];
        let trendStr = "";
        if (endDay.value > startDay.value) {
          trendStr = `Feed consumption increased from ${fmtGrams(startDay.value)}g on ${startDay.label} to ${fmtGrams(endDay.value)}g on ${endDay.label}.`;
        } else if (endDay.value < startDay.value) {
          trendStr = `Feed consumption decreased from ${fmtGrams(startDay.value)}g on ${startDay.label} to ${fmtGrams(endDay.value)}g on ${endDay.label}.`;
        } else {
          trendStr = `Feed consumption stayed stable at ${fmtGrams(endDay.value)}g.`;
        }
        summaryBox.innerHTML = `Weekly Summary: Peak feed was <strong class="summary-highlight">${fmtGrams(highest.value)}g</strong> on ${highest.label}, and lowest was ${fmtGrams(lowest.value)}g on ${lowest.label}. ${trendStr}`;
        summaryBox.classList.remove('hidden');
      } else {
        summaryBox.classList.add('hidden');
      }
    }
  }, 50);

  const _weeklyPondList = $('weeklyPondList'); if (_weeklyPondList) renderPondBreakdown(_weeklyPondList, recs);

  const fDist = feedSizeDistribution(recs);
  const _weeklyFeedList = $('weeklyFeedList');
  if (_weeklyFeedList) {
    _weeklyFeedList.innerHTML = fDist.length
      ? fDist.map(d => `<div class="fb-row"><div class="fb-dot" style="background:${d.color}"></div><div class="fb-name">${d.label}</div><div class="fb-val">${fmtGrams(d.value)}g</div></div>`).join('')
      : `<div class="empty-state"><div class="empty-icon">🌾</div><div class="empty-text">No Records Available</div></div>`;
  }
}

function renderMonthly() {
  const { year, month } = getMonthOffset(monthlyCursor);
  const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  const _monthlyLabel = $('monthlyLabel'); if (_monthlyLabel) _monthlyLabel.textContent = `${monthNames[month]} ${year}`;

  const recs = records.filter(r => {
    const d = new Date(r.Date + 'T00:00:00'); // H1 fix: parse as local
    return d.getFullYear() === year && d.getMonth() === month;
  });
  const total = sumGrams(recs);
  const daysInMonth = new Date(year, month+1, 0).getDate();
  const avgPerDay = Math.round(total / daysInMonth);

  const _monthlyStats = $('monthlyStats');
  if (_monthlyStats) renderStatStrip(_monthlyStats, [
    { val: fmtGrams(total)+'g', lbl: 'Total' },
    { val: fmtGrams(avgPerDay)+'g', lbl: 'Avg/Day' },
    { val: recs.length, lbl: 'Sessions' },
  ]);

  const weeks = [];
  let weekStart = new Date(year, month, 1);
  while (weekStart.getMonth() === month) {
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 6);
    const wRecs = recs.filter(r => { const d=new Date(r.Date + 'T00:00:00'); return d>=weekStart && d<=weekEnd; }); // H1 fix: parse as local
    const pondSet  = [...new Set(wRecs.map(r => r.PondName || r.Pond || 'Unknown'))];
    const feedDist = feedSizeDistribution(wRecs);
    const wStartStr = fmt(weekStart);
    const wEndStr   = fmt(weekEnd.getMonth() === month ? weekEnd : new Date(year, month+1, 0));
    const weekLabel = `${startOfDay(wStartStr).toLocaleDateString('en-IN',{day:'numeric',month:'short'})} – ${startOfDay(wEndStr).toLocaleDateString('en-IN',{day:'numeric',month:'short'})}`;
    weeks.push({
      label: `W${weeks.length+1}`,
      value: sumGrams(wRecs),
      _meta: { type: 'monthly-week', weekLabel, weekNum: weeks.length + 1, sessions: wRecs.length, ponds: pondSet, feedDist, dateRange: weekLabel }
    });
    weekStart.setDate(weekStart.getDate() + 7);
  }
  setTimeout(() => {
    const monthlyCanvas = $('chartMonthlyBar');
    if (monthlyCanvas) {
      const monthlyDesc = "Monthly feed trend: " + weeks.map(w => `${w.label}: ${fmtGrams(w.value)}g`).join(', ');
      monthlyCanvas.setAttribute('role', 'img');
      monthlyCanvas.setAttribute('aria-label', monthlyDesc);
      monthlyCanvas._onBarClick = (bar) => showBarDetailModal(bar._meta, '#818cf8');
    }
    drawBarChart('chartMonthlyBar', weeks, { color: '#818cf8' });

    // Update monthly summary box
    const summaryBox = $('monthlyChartSummary');
    if (summaryBox) {
      if (recs.length > 0) {
        let highest = weeks[0];
        let lowest = weeks[0];
        weeks.forEach(w => {
          if (w.value > highest.value) highest = w;
          if (w.value < lowest.value) lowest = w;
        });
        const startWeek = weeks[0];
        const endWeek = weeks[weeks.length - 1];
        let trendStr = "";
        if (endWeek.value > startWeek.value) {
          trendStr = `Feed consumption increased from ${fmtGrams(startWeek.value)}g in week 1 to ${fmtGrams(endWeek.value)}g in the final week.`;
        } else if (endWeek.value < startWeek.value) {
          trendStr = `Feed consumption decreased from ${fmtGrams(startWeek.value)}g in week 1 to ${fmtGrams(endWeek.value)}g in the final week.`;
        } else {
          trendStr = `Feed consumption remained stable at ${fmtGrams(endWeek.value)}g.`;
        }
        summaryBox.innerHTML = `Monthly Summary: Highest week was <strong class="summary-highlight">${highest.label}</strong> (${fmtGrams(highest.value)}g), and lowest was ${lowest.label} (${fmtGrams(lowest.value)}g). ${trendStr}`;
        summaryBox.classList.remove('hidden');
      } else {
        summaryBox.classList.add('hidden');
      }
    }
  }, 50);

  const _monthlyPondList = $('monthlyPondList'); if (_monthlyPondList) renderPondBreakdown(_monthlyPondList, recs);

  const { year: py, month: pm } = getMonthOffset(monthlyCursor - 1);
  const prevRecs = records.filter(r => {
    const d = new Date(r.Date + 'T00:00:00'); // H1 fix: parse as local
    return d.getFullYear() === py && d.getMonth() === pm;
  });
  const prevTotal    = sumGrams(prevRecs);
  const prevSessions = prevRecs.length;
  const prevPonds    = new Set(prevRecs.map(r=>r.PondId||r.Pond)).size;

  function trendBadge(cur, prev) {
    if (!prev) return `<span class="tc-trend tc-same">—</span>`;
    const diff = Math.round((cur - prev) / prev * 100);
    if (diff > 0) return `<span class="tc-trend tc-up">▲ ${diff}%</span>`;
    if (diff < 0) return `<span class="tc-trend tc-down">▼ ${Math.abs(diff)}%</span>`;
    return `<span class="tc-trend tc-same">—</span>`;
  }

  const _trendCompare = $('trendCompare');
  if (_trendCompare) {
    _trendCompare.innerHTML = `
      <div class="tc-row"><div class="tc-label">Total Feed</div><div class="tc-val">${fmtGrams(total)}g</div>${trendBadge(total,prevTotal)}</div>
      <div class="tc-row"><div class="tc-label">Sessions</div><div class="tc-val">${recs.length}</div>${trendBadge(recs.length,prevSessions)}</div>
      <div class="tc-row"><div class="tc-label">Active Ponds</div><div class="tc-val">${new Set(recs.map(r=>r.PondId||r.Pond)).size}</div>${trendBadge(new Set(recs.map(r=>r.PondId||r.Pond)).size,prevPonds)}</div>
    `;
  }

  renderFarmMonthlyConsumption();
}

function renderHistory() {
  const chips = $('historyFilters');
  if (!chips) return;
  const usedPondIds = [...new Set(records.map(r=>r.PondId||r.Pond))];
  chips.innerHTML = `<button class="chip ${historyPond==='all'?'active':''}" data-pond="all">All Ponds</button>` +
    usedPondIds.map(pid => {
      const pond = ponds.find(p => p.id === pid);
      const label = pond ? pond.name : pid;
      return `<button class="chip ${historyPond===pid?'active':''}" data-pond="${pid}">${label}</button>`;
    }).join('');
  chips.querySelectorAll('.chip').forEach(c => {
    c.addEventListener('click', () => { historyPond = c.dataset.pond; renderHistory(); });
  });

  const q = ($('historySearch')?.value || '').toLowerCase();
  let filtered = records.filter(r => {
    const matchPond = historyPond === 'all' || (r.PondId||r.Pond) === historyPond;
    // M2 fix: search explicit fields only (was JSON.stringify(r) which matched field names too)
    const matchQ    = !q || (r.PondName||r.Pond||'').toLowerCase().includes(q)
      || (r.Date||'').toLowerCase().includes(q)
      || (r.Time||'').toLowerCase().includes(q)
      || (r.Notes||'').toLowerCase().includes(q)
      || (r.BatchNumber||'').toString().toLowerCase().includes(q)
      || (r['Other Feed Name']||'').toLowerCase().includes(q);
    return matchPond && matchQ;
  }).slice().reverse();

  const list = $('historyList');
  if (!list) return;

  if (!filtered.length) {
    list.innerHTML = `<div class="empty-state"><div class="empty-icon">🔍</div><div class="empty-text">No Records Available</div></div>`;
  } else {
    // Build card HTML without user-controlled r.Notes (injected safely below)
    list.innerHTML = filtered.map(r => {
      const grams = sumGrams([r]);
      const feeds = feedSummaryStr(r);
      const idx   = records.indexOf(r);
      const pondDisplay = r.PondName || r.Pond || '—';
      const batchTag = r.BatchId ? `<span class="hist-batch">Batch #${r.BatchNumber}</span>` : '';
      return `<div class="hist-card" data-idx="${idx}">
        <div class="hist-top">
          <div class="hist-date">${r.Date} · ${r.Time}</div>
          <div class="hist-total">${fmtGrams(grams)}g</div>
        </div>
        <div class="hist-meta">
          <span class="hist-pond">${pondDisplay}</span>${batchTag}
          <button class="icon-btn edit" data-idx="${idx}" style="margin-left:auto" title="Edit" aria-label="Edit Feed Entry">✏</button>
          <button class="icon-btn del"  data-idx="${idx}" title="Delete" aria-label="Delete Feed Entry">🗑</button>
        </div>
        ${feeds ? `<div class="hist-feeds">${feeds}</div>` : ''}
      </div>`;
    }).join('');

    // Safely inject user-entered Notes text via textContent (prevents XSS)
    filtered.forEach((r, i) => {
      if (r.Notes) {
        const idx   = records.indexOf(r);
        const card  = list.querySelector(`.hist-card[data-idx="${idx}"]`);
        if (card) {
          const noteEl = document.createElement('div');
          noteEl.className = 'hist-feeds';
          noteEl.style.marginTop = '4px';
          noteEl.style.fontStyle = 'italic';
          noteEl.textContent = r.Notes;  // Safe: textContent, no innerHTML
          card.appendChild(noteEl);
        }
      }
    });
  }
  updateExportCount();
}

function renderStatStrip(container, stats) {
  container.innerHTML = stats.map(s => `
    <div class="ss-card">
      <div class="ss-val">${s.val}</div>
      <div class="ss-lbl">${s.lbl}</div>
    </div>`).join('');
}

function triggerReportRenderDebounced() {
  if (reportDebounceTimeout) clearTimeout(reportDebounceTimeout);
  reportDebounceTimeout = setTimeout(() => {
    reportsState.searchQuery = $('reportSearchInput')?.value.trim() || '';
    reportsState.currentPage = 1;
    renderInventoryReports();
  }, 300);
}

function initReportsPage() {
  const activeSiteId = $('reportsSiteSelect')?.value || $('inventorySiteSelect')?.value || (window.SiteManager?.loadSites()[0]?.id);
  reportsState.selectedSiteId = activeSiteId;
  
  const activeSite = window.SiteManager?.getSiteById(activeSiteId);
  const siteNameEl = $('reportsSiteName');
  if (siteNameEl) {
    siteNameEl.textContent = activeSite ? activeSite.name : 'Unknown Site';
  }

  // Restore filter values to DOM from reportsState
  restoreReportsFiltersToUI();
}

function restoreReportsFiltersToUI() {
  const typeSelect = $('inventoryReportTypeSelect');
  if (typeSelect) typeSelect.value = reportsState.reportType;

  const searchInp = $('reportSearchInput');
  if (searchInp) searchInp.value = reportsState.searchQuery;

  const fromInp = $('reportFilterDateFrom');
  if (fromInp) fromInp.value = reportsState.dateFrom;

  const toInp = $('reportFilterDateTo');
  if (toInp) toInp.value = reportsState.dateTo;

  const catSelect = $('reportCategorySelect');
  if (catSelect) catSelect.value = reportsState.category;

  const fuelSelect = $('reportFuelTypeSelect');
  if (fuelSelect) fuelSelect.value = reportsState.fuelType;

  const txSelect = $('reportTxTypeSelect');
  if (txSelect) txSelect.value = reportsState.txType;

  const lowChk = $('reportFilterLowStock');
  if (lowChk) lowChk.checked = reportsState.lowStockOnly;

  const outChk = $('reportFilterOutOfStock');
  if (outChk) outChk.checked = reportsState.outOfStockOnly;

  const expChk = $('reportFilterExpiring');
  if (expChk) expChk.checked = reportsState.expiringOnly;

  updateFilterFieldsVisibility();
  renderInventoryReports();
}

function clearReportsFiltersState() {
  reportsState.searchQuery = '';
  reportsState.dateFrom = '';
  reportsState.dateTo = '';
  reportsState.category = '';
  reportsState.fuelType = '';
  reportsState.txType = '';
  reportsState.lowStockOnly = false;
  reportsState.outOfStockOnly = false;
  reportsState.expiringOnly = false;
  reportsState.currentPage = 1;
  reportsState.sortColumn = '';
  reportsState.sortAsc = true;

  const searchInp = $('reportSearchInput');
  if (searchInp) searchInp.value = '';

  const fromInp = $('reportFilterDateFrom');
  if (fromInp) fromInp.value = '';

  const toInp = $('reportFilterDateTo');
  if (toInp) toInp.value = '';

  const catSelect = $('reportCategorySelect');
  if (catSelect) catSelect.value = '';

  const fuelSelect = $('reportFuelTypeSelect');
  if (fuelSelect) fuelSelect.value = '';

  const txSelect = $('reportTxTypeSelect');
  if (txSelect) txSelect.value = '';

  const lowChk = $('reportFilterLowStock');
  if (lowChk) lowChk.checked = false;

  const outChk = $('reportFilterOutOfStock');
  if (outChk) outChk.checked = false;

  const expChk = $('reportFilterExpiring');
  if (expChk) expChk.checked = false;
}

function updateFilterFieldsVisibility() {
  const type = reportsState.reportType;

  const catFilter = $('reportCategoryFilterGroup');
  if (catFilter) {
    catFilter.classList.toggle('hidden', type !== 'medicine_purchase' && type !== 'current_inventory');
  }

  const fuelFilter = $('reportFuelTypeFilterGroup');
  if (fuelFilter) {
    fuelFilter.classList.toggle('hidden', type !== 'fuel_purchase');
  }

  const txFilter = $('reportTxTypeFilterGroup');
  if (txFilter) {
    txFilter.classList.toggle('hidden', type !== 'stock_movement');
  }

  const lowPill = $('lblReportLowStock');
  if (lowPill) {
    lowPill.classList.toggle('hidden', type !== 'current_inventory');
  }

  const outPill = $('lblReportOutOfStock');
  if (outPill) {
    outPill.classList.toggle('hidden', type !== 'current_inventory');
  }

  const expPill = $('lblReportExpiring');
  if (expPill) {
    expPill.classList.toggle('hidden', type !== 'medicine_purchase');
  }

  const dateFilter = $('reportDateFilterGroup');
  if (dateFilter) {
    dateFilter.classList.toggle('hidden', type === 'low_stock');
  }
}

function formatCommas(num) {
  if (num === null || num === undefined || isNaN(num)) return '0';
  return num.toLocaleString('en-US');
}

function renderInventoryReports() {
  const siteId = reportsState.selectedSiteId;
  const wrapper = $('reportTableWrapper');
  const loader = $('reportLoadingState');
  if (!siteId || !wrapper) return;

  // Show loading state
  if (loader) loader.classList.remove('hidden');
  wrapper.classList.add('hidden');
  $('reportPaginationBar')?.classList.add('hidden');

  setTimeout(() => {
    try {
      // Fetch all transactions or items
      let rawData = [];
      const type = reportsState.reportType;

      if (type === 'feed_purchase') {
        rawData = window.AppStorage.getInventoryByCategory(siteId, 'feed').filter(t => t.type === 'purchase');
      } else if (type === 'medicine_purchase') {
        rawData = window.AppStorage.getInventoryByCategory(siteId, 'medicine').filter(t => t.type === 'purchase');
      } else if (type === 'fuel_purchase') {
        rawData = window.AppStorage.getInventoryByCategory(siteId, 'fuel').filter(t => t.type === 'purchase');
      } else if (type === 'stock_movement') {
        rawData = window.AppStorage.getAllInventoryTransactions().filter(t => t.siteId === siteId);
      } else if (type === 'current_inventory' || type === 'low_stock') {
        // Build items catalog
        const allTx = window.AppStorage.getAllInventoryTransactions().filter(t => t.siteId === siteId);
        const uniqueKeys = {};
        allTx.forEach(t => {
          const key = `${t.category}__${t.itemName.toLowerCase()}`;
          if (!uniqueKeys[key]) {
            uniqueKeys[key] = {
              category: t.category,
              itemName: t.itemName,
              unit: t.unit || '',
              // H13 fix: propagate details.category (sub-category) from transactions
              // so the reports category filter can match medicine sub-categories like 'Probiotics'
              details: t.details || {},
            };
          } else {
            // Merge in sub-category if we don't have it yet
            if (!uniqueKeys[key].details?.category && t.details?.category) {
              uniqueKeys[key].details = Object.assign({}, uniqueKeys[key].details, { category: t.details.category });
            }
          }
        });

        const catalog = Object.values(uniqueKeys).map(item => {
          const stock = window.InventoryManager.calculateStock(siteId, item.category, item.itemName);
          
          // Calculate Average Purchase Price
          const purchases = allTx.filter(t => t.category === item.category && t.itemName.toLowerCase() === item.itemName.toLowerCase() && t.type === 'purchase');
          const totalQty = purchases.reduce((sum, t) => sum + Math.abs(t.quantity), 0);
          const totalCost = purchases.reduce((sum, t) => sum + t.totalCost, 0);
          const avgPrice = totalQty > 0 ? +(totalCost / totalQty).toFixed(2) : 0;
          const totalValue = +(stock * avgPrice).toFixed(2);

          // Get low stock threshold
          const thresholds = window.AppStorage.getInventoryThresholds();
          const threshKey = `${siteId}__${item.category}__${item.itemName.toLowerCase()}`;
          const defaultThresholds = { feed: 50, medicine: 5, fuel: 20 }; // H5 fix: aligned with InventoryManager defaults
          const threshold = thresholds[threshKey] !== undefined ? thresholds[threshKey] : (defaultThresholds[item.category] || 0);

          let status = 'OK';
          if (stock <= 0) status = 'Out';
          else if (stock <= threshold) status = 'Low';

          // For low stock shortfall last purchase date
          const lastPurchase = purchases.sort((a, b) => b.purchaseDate.localeCompare(a.purchaseDate))[0];

          return {
            category: item.category,
            itemName: item.itemName,
            currentStock: stock,
            unit: item.unit,
            avgPurchasePrice: avgPrice,
            totalValue: totalValue,
            status: status,
            threshold: threshold,
            shortfall: Math.max(0, threshold - stock),
            lastPurchaseDate: lastPurchase ? lastPurchase.purchaseDate : '—',
            supplier: lastPurchase ? lastPurchase.supplier : ''
          };
        });

        if (type === 'current_inventory') {
          rawData = catalog;
        } else {
          // Low stock only
          rawData = catalog.filter(item => item.currentStock <= item.threshold);
        }
      }

      // Apply AND filters
      let filtered = rawData.filter(item => {
        // Date filters (except for low stock report)
        if (type !== 'low_stock') {
          const dateVal = item.purchaseDate || item.lastPurchaseDate;
          if (reportsState.dateFrom && dateVal && dateVal < reportsState.dateFrom) return false;
          if (reportsState.dateTo && dateVal && dateVal > reportsState.dateTo) return false;
        }

        // Search text query
        if (reportsState.searchQuery) {
          const q = reportsState.searchQuery.toLowerCase();
          const matchItem = item.itemName?.toLowerCase().includes(q);
          const matchSupplier = item.supplier?.toLowerCase().includes(q);
          const matchCat = item.category?.toLowerCase().includes(q);
          const matchRef = item.referenceNumber?.toLowerCase().includes(q);
          const matchNotes = item.notes?.toLowerCase().includes(q);

          if (!matchItem && !matchSupplier && !matchCat && !matchRef && !matchNotes) return false;
        }

        // Contextual Dropdowns
        if (type === 'medicine_purchase' || type === 'current_inventory') {
          if (reportsState.category) {
            const itemCat = item.details?.category || item.category;
            if (itemCat?.toLowerCase() !== reportsState.category.toLowerCase()) return false;
          }
        }
        if (type === 'fuel_purchase') {
          if (reportsState.fuelType && item.itemName?.toLowerCase() !== reportsState.fuelType.toLowerCase()) return false;
        }
        if (type === 'stock_movement') {
          if (reportsState.txType && item.type !== reportsState.txType) return false;
        }

        // Toggles
        if (type === 'current_inventory') {
          if (reportsState.lowStockOnly && item.status !== 'Low' && item.status !== 'Out') return false;
          if (reportsState.outOfStockOnly && item.status !== 'Out') return false;
        }
        if (type === 'medicine_purchase') {
          if (reportsState.expiringOnly) {
            if (!item.details?.expiryDate) return false;
            const exp = new Date(item.details.expiryDate);
            const limit = new Date();
            limit.setDate(limit.getDate() + 30);
            if (exp > limit) return false;
          }
        }

        return true;
      });

      // Apply Sort
      if (reportsState.sortColumn) {
        filtered = sortReportData(filtered, reportsState.sortColumn, reportsState.sortAsc);
      } else if (type === 'low_stock') {
        // Default low stock sorting: zero stock first, then below threshold
        filtered.sort((a, b) => {
          const aZero = a.currentStock <= 0 ? 1 : 0;
          const bZero = b.currentStock <= 0 ? 1 : 0;
          if (aZero !== bZero) return bZero - aZero;
          return a.currentStock - b.currentStock;
        });
      }

      // Cache current filtered items
      reportsState.currentData = filtered;

      // Calculate Pagination
      const totalRows = filtered.length;
      reportsState.totalPages = Math.max(1, Math.ceil(totalRows / reportsState.pageSize));
      if (reportsState.currentPage > reportsState.totalPages) reportsState.currentPage = reportsState.totalPages;

      const start = (reportsState.currentPage - 1) * reportsState.pageSize;
      const paginated = filtered.slice(start, start + reportsState.pageSize);

      // Render Table
      if (totalRows === 0) {
        wrapper.innerHTML = `
          <div class="inv-empty-state-placeholder">
            <span class="inv-empty-state-icon">📊</span>
            <div class="inv-empty-state-title">No Data Found</div>
            <div class="inv-empty-state-desc">No records matches the current filters. Clear filters or add transactions to populate reports.</div>
          </div>
        `;
      } else {
        wrapper.innerHTML = generateReportTableHTML(paginated, type);
      }

      // Setup Pagination Bar visibility
      const pagBar = $('reportPaginationBar');
      if (pagBar) {
        pagBar.classList.toggle('hidden', reportsState.totalPages <= 1);
        const label = $('reportPaginationLabel');
        if (label) label.textContent = `Page ${reportsState.currentPage} of ${reportsState.totalPages}`;
      }

      if (loader) loader.classList.add('hidden');
      wrapper.classList.remove('hidden');

    } catch (err) {
      showToast('❌', 'Report Error', 'Could not compile reports: ' + err.message);
      if (loader) loader.classList.add('hidden');
    }
  }, 100);
}

function sortReportData(data, col, asc) {
  return data.sort((a, b) => {
    let valA = a[col];
    let valB = b[col];

    if (col === 'size') {
      valA = a.details?.feedSize || '';
      valB = b.details?.feedSize || '';
    } else if (col === 'bags') {
      valA = a.details?.numberOfBags || 0;
      valB = b.details?.numberOfBags || 0;
    } else if (col === 'expiry') {
      valA = a.details?.expiryDate || '';
      valB = b.details?.expiryDate || '';
    } else if (col === 'med_category') {
      valA = a.details?.category || '';
      valB = b.details?.category || '';
    }

    if (typeof valA === 'string') {
      return asc ? valA.localeCompare(valB) : valB.localeCompare(valA);
    } else {
      valA = valA || 0;
      valB = valB || 0;
      return asc ? valA - valB : valB - valA;
    }
  });
}

function getSortIndicator(col) {
  if (reportsState.sortColumn !== col) return '<span class="sort-arrow">⇅</span>';
  return reportsState.sortAsc ? '<span class="sort-arrow">▲</span>' : '<span class="sort-arrow">▼</span>';
}

function generateReportTableHTML(rows, type) {
  const today = new Date();
  const thirtyDaysLater = new Date();
  thirtyDaysLater.setDate(today.getDate() + 30);

  if (type === 'feed_purchase') {
    // Totals calculations
    const totalBags = reportsState.currentData.reduce((s, r) => s + (r.details?.numberOfBags || 0), 0);
    const totalWeight = reportsState.currentData.reduce((s, r) => s + r.quantity, 0);
    const totalCost = reportsState.currentData.reduce((s, r) => s + r.totalCost, 0);

    return `
      <table class="report-table">
        <thead>
          <tr>
            <th class="sortable" onclick="handleReportHeaderSort('purchaseDate')">Date ${getSortIndicator('purchaseDate')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('supplier')">Supplier ${getSortIndicator('supplier')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('itemName')">Brand ${getSortIndicator('itemName')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('size')">Size ${getSortIndicator('size')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('bags')">Bags ${getSortIndicator('bags')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('quantity')">Weight (kg) ${getSortIndicator('quantity')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('unitPrice')">Price/Bag ${getSortIndicator('unitPrice')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('totalCost')">Total Cost ${getSortIndicator('totalCost')}</th>
            <th>Notes</th>
          </tr>
        </thead>
        <tbody>
          ${rows.map(r => {
            const priceBag = r.unitPrice * (r.details?.bagWeight || 0);
            return `
              <tr>
                <td>${r.purchaseDate}</td>
                <td>${escapeHTML(r.supplier)}</td>
                <td style="font-weight:600; color:var(--teal);">${escapeHTML(r.itemName)}</td>
                <td>${r.details?.feedSize || '—'}</td>
                <td class="text-right">${formatCommas(r.details?.numberOfBags || 0)}</td>
                <td class="text-right">${formatCommas(r.quantity)} kg</td>
                <td class="text-right">₹${formatCommas(priceBag)}</td>
                <td class="text-right" style="font-weight:700;">₹${formatCommas(r.totalCost)}</td>
                <td style="font-size:0.75rem; color:var(--t3);">${escapeHTML(r.notes) || '—'}</td>
              </tr>
            `;
          }).join('')}
          <tr class="summary-row">
            <td colspan="4">TOTAL</td>
            <td class="text-right">${formatCommas(totalBags)}</td>
            <td class="text-right">${formatCommas(totalWeight)} kg</td>
            <td class="text-right">—</td>
            <td class="text-right" style="color:var(--teal);">₹${formatCommas(totalCost)}</td>
            <td></td>
          </tr>
        </tbody>
      </table>
    `;
  }

  if (type === 'medicine_purchase') {
    const totalItems = reportsState.currentData.reduce((s, r) => s + r.quantity, 0);
    const totalCost = reportsState.currentData.reduce((s, r) => s + r.totalCost, 0);

    return `
      <table class="report-table">
        <thead>
          <tr>
            <th class="sortable" onclick="handleReportHeaderSort('purchaseDate')">Date ${getSortIndicator('purchaseDate')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('itemName')">Item ${getSortIndicator('itemName')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('med_category')">Category ${getSortIndicator('med_category')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('supplier')">Supplier ${getSortIndicator('supplier')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('quantity')">Qty ${getSortIndicator('quantity')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('unit')">Unit ${getSortIndicator('unit')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('unitPrice')">Unit Price ${getSortIndicator('unitPrice')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('totalCost')">Total Cost ${getSortIndicator('totalCost')}</th>
            <th class="sortable text-center" onclick="handleReportHeaderSort('expiry')">Expiry ${getSortIndicator('expiry')}</th>
            <th>Notes</th>
          </tr>
        </thead>
        <tbody>
          ${rows.map(r => {
            let expiryClass = '';
            let expiryTextClass = '';
            let expiryLabel = r.details?.expiryDate || '—';
            if (r.details?.expiryDate) {
              const exp = new Date(r.details.expiryDate);
              if (exp <= today) {
                expiryClass = 'expired-row';
                expiryTextClass = 'warning-text-expired';
                expiryLabel = `${r.details.expiryDate} (EXPIRED)`;
              } else if (exp <= thirtyDaysLater) {
                expiryClass = 'expiring-soon-row';
                expiryTextClass = 'warning-text-expiring';
                expiryLabel = `${r.details.expiryDate} (EXPIRING)`;
              }
            }
            return `
              <tr class="${expiryClass}">
                <td>${r.purchaseDate}</td>
                <td style="font-weight:600; color:var(--teal);">${escapeHTML(r.itemName)}</td>
                <td>${r.details?.category || '—'}</td>
                <td>${escapeHTML(r.supplier)}</td>
                <td class="text-right">${formatCommas(r.quantity)}</td>
                <td>${r.unit}</td>
                <td class="text-right">₹${formatCommas(r.unitPrice)}</td>
                <td class="text-right" style="font-weight:700;">₹${formatCommas(r.totalCost)}</td>
                <td class="text-center ${expiryTextClass}">${expiryLabel}</td>
                <td style="font-size:0.75rem; color:var(--t3);">${escapeHTML(r.notes) || '—'}</td>
              </tr>
            `;
          }).join('')}
          <tr class="summary-row">
            <td colspan="4">TOTAL</td>
            <td class="text-right">${formatCommas(totalItems)}</td>
            <td></td>
            <td></td>
            <td class="text-right" style="color:var(--teal);">₹${formatCommas(totalCost)}</td>
            <td></td>
            <td></td>
          </tr>
        </tbody>
      </table>
    `;
  }

  if (type === 'fuel_purchase') {
    const totalLiters = reportsState.currentData.reduce((s, r) => s + r.quantity, 0);
    const totalCost = reportsState.currentData.reduce((s, r) => s + r.totalCost, 0);

    return `
      <table class="report-table">
        <thead>
          <tr>
            <th class="sortable" onclick="handleReportHeaderSort('purchaseDate')">Date ${getSortIndicator('purchaseDate')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('itemName')">Fuel Type ${getSortIndicator('itemName')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('supplier')">Supplier ${getSortIndicator('supplier')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('quantity')">Quantity (L) ${getSortIndicator('quantity')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('unitPrice')">Price/Liter ${getSortIndicator('unitPrice')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('totalCost')">Total Cost ${getSortIndicator('totalCost')}</th>
            <th>Notes</th>
          </tr>
        </thead>
        <tbody>
          ${rows.map(r => {
            return `
              <tr>
                <td>${r.purchaseDate}</td>
                <td style="font-weight:600; color:var(--teal);">${escapeHTML(r.itemName)}</td>
                <td>${escapeHTML(r.supplier)}</td>
                <td class="text-right">${formatCommas(r.quantity)} L</td>
                <td class="text-right">₹${formatCommas(r.unitPrice)}</td>
                <td class="text-right" style="font-weight:700;">₹${formatCommas(r.totalCost)}</td>
                <td style="font-size:0.75rem; color:var(--t3);">${escapeHTML(r.notes) || '—'}</td>
              </tr>
            `;
          }).join('')}
          <tr class="summary-row">
            <td colspan="3">TOTAL</td>
            <td class="text-right">${formatCommas(totalLiters)} L</td>
            <td></td>
            <td class="text-right" style="color:var(--teal);">₹${formatCommas(totalCost)}</td>
            <td></td>
          </tr>
        </tbody>
      </table>
    `;
  }

  if (type === 'current_inventory') {
    const totalVal = reportsState.currentData.reduce((s, r) => s + r.totalValue, 0);

    return `
      <table class="report-table">
        <thead>
          <tr>
            <th class="sortable" onclick="handleReportHeaderSort('category')">Category ${getSortIndicator('category')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('itemName')">Item ${getSortIndicator('itemName')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('currentStock')">Current Stock ${getSortIndicator('currentStock')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('unit')">Unit ${getSortIndicator('unit')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('avgPurchasePrice')">
              Avg Price
              <div class="inv-tooltip-container">
                <span class="inv-tooltip-trigger">?</span>
                <div class="inv-tooltip-bubble">Average Price = Total Purchase Cost &divide; Total Quantity Purchased.</div>
              </div>
            </th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('totalValue')">
              Total Value
              <div class="inv-tooltip-container">
                <span class="inv-tooltip-trigger">?</span>
                <div class="inv-tooltip-bubble">Total Value = Current Stock &times; Avg Purchase Price.</div>
              </div>
            </th>
            <th class="sortable text-center" onclick="handleReportHeaderSort('status')">Status ${getSortIndicator('status')}</th>
          </tr>
        </thead>
        <tbody>
          ${rows.map(r => {
            let badgeClass = 'status-ok';
            if (r.status === 'Low') badgeClass = 'status-low';
            else if (r.status === 'Out') badgeClass = 'status-out';
            
            return `
              <tr>
                <td>${r.category.toUpperCase()}</td>
                <td style="font-weight:600; color:var(--teal);">${escapeHTML(r.itemName)}</td>
                <td class="text-right">${formatCommas(r.currentStock)}</td>
                <td>${r.unit || 'units'}</td>
                <td class="text-right">₹${formatCommas(r.avgPurchasePrice)}</td>
                <td class="text-right" style="font-weight:700;">₹${formatCommas(r.totalValue)}</td>
                <td class="text-center"><span class="status-badge ${badgeClass}">${r.status}</span></td>
              </tr>
            `;
          }).join('')}
          <tr class="summary-row">
            <td colspan="5">TOTAL VALUE</td>
            <td class="text-right" style="color:var(--teal);">₹${formatCommas(totalVal)}</td>
            <td></td>
          </tr>
        </tbody>
      </table>
    `;
  }

  if (type === 'low_stock') {
    return `
      <table class="report-table">
        <thead>
          <tr>
            <th class="sortable" onclick="handleReportHeaderSort('category')">Category ${getSortIndicator('category')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('itemName')">Item ${getSortIndicator('itemName')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('currentStock')">Current Stock ${getSortIndicator('currentStock')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('threshold')">Threshold ${getSortIndicator('threshold')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('shortfall')">
              Shortfall
              <div class="inv-tooltip-container">
                <span class="inv-tooltip-trigger">?</span>
                <div class="inv-tooltip-bubble">Shortfall is the remaining quantity needed to reach the threshold boundary.</div>
              </div>
            </th>
            <th class="sortable text-center" onclick="handleReportHeaderSort('lastPurchaseDate')">Last Purchase ${getSortIndicator('lastPurchaseDate')}</th>
          </tr>
        </thead>
        <tbody>
          ${rows.map(r => {
            const isZero = r.currentStock <= 0;
            const style = isZero ? 'color: var(--red); font-weight: 700;' : 'color: var(--amber); font-weight: 700;';
            return `
              <tr>
                <td>${r.category.toUpperCase()}</td>
                <td style="font-weight:600; color:var(--teal);">${escapeHTML(r.itemName)}</td>
                <td class="text-right" style="${style}">${formatCommas(r.currentStock)} ${r.unit}</td>
                <td class="text-right">${formatCommas(r.threshold)} ${r.unit}</td>
                <td class="text-right" style="font-weight:700;">${formatCommas(r.shortfall)} ${r.unit}</td>
                <td class="text-center">${r.lastPurchaseDate}</td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;
  }

  if (type === 'stock_movement') {
    return `
      <table class="report-table">
        <thead>
          <tr>
            <th class="sortable" onclick="handleReportHeaderSort('purchaseDate')">Date ${getSortIndicator('purchaseDate')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('type')">Type ${getSortIndicator('type')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('category')">Category ${getSortIndicator('category')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('itemName')">Item ${getSortIndicator('itemName')}</th>
            <th class="sortable text-right" onclick="handleReportHeaderSort('quantity')">Quantity ${getSortIndicator('quantity')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('unit')">Unit ${getSortIndicator('unit')}</th>
            <th class="sortable" onclick="handleReportHeaderSort('referenceNumber')">Reference ${getSortIndicator('referenceNumber')}</th>
            <th>Notes</th>
          </tr>
        </thead>
        <tbody>
          ${rows.map(r => {
            // Signed quantities
            const isPositive = ['purchase', 'transfer_in'].includes(r.type) || (r.type === 'manual_adjustment' && r.quantity > 0);
            const valSign = isPositive ? '+' : '';
            const valColor = isPositive ? 'var(--green)' : 'var(--red)';
            const typeLabel = r.type.replace('_', ' ').toUpperCase();

            return `
              <tr>
                <td>${r.purchaseDate}</td>
                <td><span style="font-size:0.7rem; font-weight:700; color:var(--teal);">${typeLabel}</span></td>
                <td>${r.category.toUpperCase()}</td>
                <td style="font-weight:600; color:var(--teal);">${escapeHTML(r.itemName)}</td>
                <td class="text-right" style="font-weight:700; color:${valColor};">${valSign}${formatCommas(r.quantity)}</td>
                <td>${r.unit}</td>
                <td style="font-size:0.75rem;">${escapeHTML(r.referenceNumber) || '—'}</td>
                <td style="font-size:0.75rem; color:var(--t3);">${escapeHTML(r.notes) || '—'}</td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;
  }

  return '';
}

function handleReportHeaderSort(col) {
  if (reportsState.sortColumn === col) {
    reportsState.sortAsc = !reportsState.sortAsc;
  } else {
    reportsState.sortColumn = col;
    reportsState.sortAsc = true;
  }
  renderInventoryReports();
}

function escapeCSVField(val) {
  if (val === null || val === undefined) return '';
  const str = String(val);
  if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function doExportReportCSV() {
  const type = reportsState.reportType;
  const data = reportsState.currentData;
  if (!data || data.length === 0) {
    showToast('⚠️', 'Export Failed', 'No records to export.');
    return;
  }

  let headers = [];
  let rows = [];

  if (type === 'feed_purchase') {
    headers = ['Date', 'Supplier', 'Brand', 'Size', 'Bags', 'Weight (kg)', 'Price/Bag (INR)', 'Total Cost (INR)', 'Notes'];
    rows = data.map(r => [
      r.purchaseDate,
      r.supplier,
      r.itemName,
      r.details?.feedSize || '',
      r.details?.numberOfBags || 0,
      r.quantity,
      r.unitPrice * (r.details?.bagWeight || 0),
      r.totalCost,
      r.notes || ''
    ]);
    // Add summary row
    const totalBags = data.reduce((s, r) => s + (r.details?.numberOfBags || 0), 0);
    const totalWeight = data.reduce((s, r) => s + r.quantity, 0);
    const totalCost = data.reduce((s, r) => s + r.totalCost, 0);
    rows.push(['TOTAL', '', '', '', totalBags, totalWeight, '', totalCost, '']);

  } else if (type === 'medicine_purchase') {
    headers = ['Date', 'Item', 'Category', 'Supplier', 'Qty', 'Unit', 'Unit Price (INR)', 'Total Cost (INR)', 'Expiry Date', 'Notes'];
    rows = data.map(r => [
      r.purchaseDate,
      r.itemName,
      r.details?.category || '',
      r.supplier,
      r.quantity,
      r.unit,
      r.unitPrice,
      r.totalCost,
      r.details?.expiryDate || '',
      r.notes || ''
    ]);
    const totalItems = data.reduce((s, r) => s + r.quantity, 0);
    const totalCost = data.reduce((s, r) => s + r.totalCost, 0);
    rows.push(['TOTAL', '', '', '', totalItems, '', '', totalCost, '', '']);

  } else if (type === 'fuel_purchase') {
    headers = ['Date', 'Fuel Type', 'Supplier', 'Quantity (L)', 'Price/Liter (INR)', 'Total Cost (INR)', 'Notes'];
    rows = data.map(r => [
      r.purchaseDate,
      r.itemName,
      r.supplier,
      r.quantity,
      r.unitPrice,
      r.totalCost,
      r.notes || ''
    ]);
    const totalLiters = data.reduce((s, r) => s + r.quantity, 0);
    const totalCost = data.reduce((s, r) => s + r.totalCost, 0);
    rows.push(['TOTAL', '', '', totalLiters, '', totalCost, '']);

  } else if (type === 'current_inventory') {
    headers = ['Category', 'Item', 'Current Stock', 'Unit', 'Avg Purchase Price (INR)', 'Total Value (INR)', 'Status'];
    rows = data.map(r => [
      r.category.toUpperCase(),
      r.itemName,
      r.currentStock,
      r.unit || 'units',
      r.avgPurchasePrice,
      r.totalValue,
      r.status
    ]);
    const totalVal = data.reduce((s, r) => s + r.totalValue, 0);
    rows.push(['TOTAL VALUE', '', '', '', '', totalVal, '']);

  } else if (type === 'low_stock') {
    headers = ['Category', 'Item', 'Current Stock', 'Threshold', 'Shortfall', 'Last Purchase Date', 'Last Supplier'];
    rows = data.map(r => [
      r.category.toUpperCase(),
      r.itemName,
      r.currentStock,
      r.threshold,
      r.shortfall,
      r.lastPurchaseDate,
      r.supplier || ''
    ]);

  } else if (type === 'stock_movement') {
    headers = ['Date', 'Type', 'Category', 'Item', 'Quantity', 'Unit', 'Reference Number', 'Notes'];
    rows = data.map(r => [
      r.purchaseDate,
      r.type.toUpperCase(),
      r.category.toUpperCase(),
      r.itemName,
      r.quantity,
      r.unit,
      r.referenceNumber || '',
      r.notes || ''
    ]);
  }

  // Compile CSV string
  const csvContent = [
    headers.map(escapeCSVField).join(','),
    ...rows.map(row => row.map(escapeCSVField).join(','))
  ].join('\r\n');

  const todayStr = new Date().toISOString().slice(0, 10);
  const filename = `aqualog_inventory_${type}_${todayStr}.csv`;

  // Trigger download
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', filename);
  link.style.visibility = 'hidden';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url); // M12 fix: revoke blob URL to prevent leak

  showToast('📥', 'Export Complete', `CSV saved as ${filename}`);
}

function checkFeedBrandExistence(record) {
  if (!record) return;
  const pond = window.AppStorage.getPonds().find(p => p.id === record.PondId);
  const siteId = pond ? pond.siteId : null;
  if (!siteId) return;

  const FEED_SLOT_FIELDS = [
    { field: 'Feed Size 1 Gram', label: 'Feed Size 1' },
    { field: 'Feed Size 2 Gram', label: 'Feed Size 2' },
    { field: 'Feed Size 3 Gram', label: 'Feed Size 3' },
    { field: 'Feed Size 4 Gram', label: 'Feed Size 4' },
    { field: 'Feed Size 5 Gram', label: 'Feed Size 5' },
  ];

  const warnBrands = [];

  FEED_SLOT_FIELDS.forEach(({ field, label }) => {
    const grams = Number(record[field]) || 0;
    if (grams > 0) {
      const exists = window.AppStorage.getInventoryByCategory(siteId, 'feed')
        .some(t => t.itemName.toLowerCase() === label.toLowerCase());
      if (!exists) {
        warnBrands.push(label);
      }
    }
  });

  const otherGrams = Number(record['Other Feed Gram']) || 0;
  if (otherGrams > 0) {
    const otherName = (record['Other Feed Name'] || '').trim() || 'Other Feed';
    const exists = window.AppStorage.getInventoryByCategory(siteId, 'feed')
      .some(t => t.itemName.toLowerCase() === otherName.toLowerCase());
    if (!exists) {
      warnBrands.push(otherName);
    }
  }

  if (warnBrands.length > 0) {
    showToast(
      '⚠️',
      'Unregistered Feed Brand',
      `Feed brand(s) [${warnBrands.join(', ')}] are not registered in feed inventory. Logging is allowed, but please record a purchase to track stock.`
    );
  }
}

function bindReportsEvents() {
  $('btnGoToInventoryReports')?.addEventListener('click', () => switchPage('pageInventoryReports'));
  $('btnBackInventoryReports')?.addEventListener('click', () => switchPage('pageInventory'));

  $('reportsSiteSelect')?.addEventListener('change', (e) => {
    syncAllSiteDropdowns(e.target.value);
  });

  $('inventoryReportTypeSelect')?.addEventListener('change', (e) => {
    reportsState.reportType = e.target.value;
    reportsState.currentPage = 1;
    reportsState.sortColumn = '';
    updateFilterFieldsVisibility();
    renderInventoryReports();
  });

  $('reportSearchInput')?.addEventListener('input', triggerReportRenderDebounced);
  
  ['reportFilterDateFrom', 'reportFilterDateTo'].forEach(id => {
    $(id)?.addEventListener('input', () => {
      reportsState.currentPage = 1;
      renderInventoryReports();
    });
  });

  ['reportCategorySelect', 'reportFuelTypeSelect', 'reportTxTypeSelect'].forEach(id => {
    $(id)?.addEventListener('change', () => {
      reportsState.currentPage = 1;
      renderInventoryReports();
    });
  });

  ['reportFilterLowStock', 'reportFilterOutOfStock', 'reportFilterExpiring'].forEach(id => {
    $(id)?.addEventListener('change', () => {
      reportsState.currentPage = 1;
      renderInventoryReports();
    });
  });

  $('btnClearReportFilters')?.addEventListener('click', () => {
    clearReportsFiltersState();
    updateFilterFieldsVisibility();
    renderInventoryReports();
  });

  $('btnExportReportCSV')?.addEventListener('click', doExportReportCSV);

  $('btnReportPrevPage')?.addEventListener('click', () => {
    if (reportsState.currentPage > 1) {
      reportsState.currentPage--;
      renderInventoryReports();
    }
  });

  $('btnReportNextPage')?.addEventListener('click', () => {
    if (reportsState.currentPage < reportsState.totalPages) {
      reportsState.currentPage++;
      renderInventoryReports();
    }
  });
}

// Window bindings for backward compatibility
window.bindReportEvents = bindReportEvents;
window.renderReportsTab = renderReportsTab;
window.renderDaily = renderDaily;
window.renderWeekly = renderWeekly;
window.renderMonthly = renderMonthly;
window.renderHistory = renderHistory;
window.renderStatStrip = renderStatStrip;
window.triggerReportRenderDebounced = triggerReportRenderDebounced;
window.initReportsPage = initReportsPage;
window.restoreReportsFiltersToUI = restoreReportsFiltersToUI;
window.clearReportsFiltersState = clearReportsFiltersState;
window.updateFilterFieldsVisibility = updateFilterFieldsVisibility;
window.formatCommas = formatCommas;
window.renderInventoryReports = renderInventoryReports;
window.sortReportData = sortReportData;
window.getSortIndicator = getSortIndicator;
window.generateReportTableHTML = generateReportTableHTML;
window.handleReportHeaderSort = handleReportHeaderSort;
window.escapeCSVField = escapeCSVField;
window.doExportReportCSV = doExportReportCSV;
window.checkFeedBrandExistence = checkFeedBrandExistence;
window.bindReportsEvents = bindReportsEvents;
})();

// --- Module: inventory.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

let thresholdItemKey = null;
let thresholdCategory = null;
let thresholdItemName = null;

  function getInventoryMedicineItems(siteId) {
    if (!window.AppStorage) return [];

    // If we have a specific siteId use it; otherwise aggregate across all sites
    let txs;
    if (siteId) {
      txs = window.AppStorage.getInventoryByCategory(siteId, 'medicine');
    } else {
      // No pond selected yet — show items from every site so farmer can browse
      txs = window.AppStorage.getAllInventoryTransactions()
              .filter(t => t.category === 'medicine');
    }

    if (!txs.length) return [];

    // Collect distinct item names from any stock-adding transaction type
    const names = [...new Set(txs.map(t => t.itemName).filter(Boolean))];

    return names.map(name => {
      let stock;
      if (siteId) {
        stock = window.AppStorage.getStockBalance(siteId, 'medicine', name);
      } else {
        // Sum across all sites
        const allSites = window.SiteManager ? window.SiteManager.loadSites() : [];
        stock = allSites.reduce((sum, s) =>
          sum + (window.AppStorage.getStockBalance(s.id, 'medicine', name) || 0), 0);
      }
      const sample = txs.find(t => t.itemName === name);
      return { name, stock, unit: sample?.unit || '' };
    }).filter(i => i.name);
  }

function populateInventorySiteSelect(selectId, targetVal) {
  const select = $(selectId);
  if (!select || !window.SiteManager) return;
  const sites = window.SiteManager.loadSites();
  select.innerHTML = '';
  
  sites.forEach(site => {
    const opt = document.createElement('option');
    opt.value = site.id;
    opt.textContent = site.name;
    select.appendChild(opt);
  });
  
  if (targetVal) {
    select.value = targetVal;
  } else if (sites.length > 0) {
    select.value = sites[0].id;
  }
}

function syncAllSiteDropdowns(selectedSiteId) {
  ['inventorySiteSelect', 'feedDetailSiteSelect', 'medDetailSiteSelect', 'fuelDetailSiteSelect'].forEach(id => {
    const select = $(id);
    if (select) select.value = selectedSiteId;
  });

  refreshActiveInventoryPage();
}

function refreshActiveInventoryPage() {
  if (currentPage === 'pageInventory') {
    renderInventoryDashboard();
  } else if (currentPage === 'pageFeedDetail') {
    renderFeedDetailPage();
  } else if (currentPage === 'pageMedicineDetail') {
    renderMedicineDetailPage();
  } else if (currentPage === 'pageFuelDetail') {
    renderFuelDetailPage();
  } else if (currentPage === 'pageInventoryReports') {
    renderInventoryReports();
  }
}

function sumSignedQuantity(txs) {
  return txs.reduce((sum, t) => {
    const q = Number(t.quantity) || 0;
    switch (t.type) {
      case 'purchase':
      case 'transfer_in':
        return sum + Math.abs(q);
      case 'consumption':
      case 'transfer_out':
      case 'expired':
      case 'damaged':
        return sum - Math.abs(q);
      case 'manual_adjustment':
        return sum + q;
      default:
        return sum;
    }
  }, 0);
}

function getThresholdValue(siteId, category, itemName) {
  if (!window.AppStorage || !window.AppStorage.getInventoryThresholds) return 0;
  const customThresholds = window.AppStorage.getInventoryThresholds();
  const key = `${siteId}::${category}::${itemName.toLowerCase()}`;
  if (customThresholds[key] !== undefined) {
    return Number(customThresholds[key]);
  }
  const defaults = { feed: 100, medicine: 10, fuel: 50 };
  return defaults[category] ?? 0;
}

function getItemStatus(stock, threshold) {
  if (stock <= 0) {
    return { code: 'out', label: 'Out of Stock', colorClass: 'status-out' };
  } else if (stock <= threshold) {
    return { code: 'low', label: 'Low Stock', colorClass: 'status-low' };
  } else {
    return { code: 'ok', label: 'OK', colorClass: 'status-ok' };
  }
}

function getExpiryStatus(expiryDateStr) {
  if (!expiryDateStr) return null;
  const exp = new Date(expiryDateStr);
  if (isNaN(exp.getTime())) return null;

  const today = new Date();
  today.setHours(0,0,0,0);
  const thirtyDaysLater = new Date();
  thirtyDaysLater.setDate(today.getDate() + 30);
  thirtyDaysLater.setHours(0,0,0,0);

  if (exp <= today) {
    return { code: 'expired', color: 'var(--red)', label: 'Expired' };
  } else if (exp <= thirtyDaysLater) {
    return { code: 'expiring', color: 'var(--amber)', label: 'Expiring Soon' };
  } else {
    return { code: 'ok', color: 'var(--t1)', label: 'Good' };
  }
}

function getUniqueItemNamesForCategory(siteId, category) {
  if (!window.AppStorage) return [];
  const txs = window.AppStorage.getInventoryByCategory(siteId, category);
  const seen = new Set();
  const list = [];
  txs.forEach(t => {
    const nameLower = (t.itemName || '').trim().toLowerCase();
    if (!seen.has(nameLower)) {
      seen.add(nameLower);
      list.push({
        itemName: t.itemName.trim(),
        unit: t.unit,
        details: t.details || {},
        category: category
      });
    }
  });
  return list;
}

function getItemDetails(siteId, category, itemName) {
  const txs = (window.AppStorage?.getInventoryByCategory(siteId, category) || [])
    .filter(t => (t.itemName || '').trim().toLowerCase() === itemName.toLowerCase());
  
  const purchases = txs.filter(t => t.type === 'purchase');
  purchases.sort((a, b) => {
    const da = a.purchaseDate || '';
    const db = b.purchaseDate || '';
    const ca = a.createdAt || '';
    const cb = b.createdAt || '';
    return db.localeCompare(da) || cb.localeCompare(ca);
  });
  
  const lastPurchase = purchases[0] || null;
  const detailHolder = txs.find(t => t.details && Object.keys(t.details).length > 0) || null;
  const details = detailHolder ? detailHolder.details : {};
  const unit = txs[0]?.unit || (category === 'feed' ? 'kg' : (category === 'fuel' ? 'Liter' : 'units'));
  
  return {
    itemName,
    details,
    unit,
    lastPurchaseDate: lastPurchase ? lastPurchase.purchaseDate : '—',
    lastSupplier: lastPurchase ? lastPurchase.supplier : '—',
    transactions: txs
  };
}

function renderInventoryDashboard() {
  const siteId = $('inventorySiteSelect')?.value;
  if (!siteId) return;

  const today = new Date();
  // H3 fix: use LOCAL month, not UTC. toISOString() returns UTC which can be
  // off by one month near midnight in UTC+ timezones.
  const currentMonthStr = fmt(today).slice(0, 7); // "YYYY-MM" in local tz

  // 1. FEED CARD
  const feedTx = window.AppStorage?.getInventoryByCategory(siteId, 'feed') || [];
  const feedStock = sumSignedQuantity(feedTx);
  const feedPurchased = window.InventoryManager?.getMonthlyPurchase(siteId, 'feed', currentMonthStr)?.quantity || 0;
  const feedConsumed = window.InventoryManager?.getMonthlyConsumption(siteId, 'feed', currentMonthStr)?.quantity || 0;
  const feedLowStockItems = (window.InventoryManager?.getLowStockItems(siteId) || []).filter(item => item.category === 'feed');
  const feedLowStockCount = feedLowStockItems.length;

  const _feedStockEl = $('feedCurrentStock'); if (_feedStockEl) _feedStockEl.textContent = `${feedStock.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} kg`;
  const _feedPurchEl = $('feedPurchasedMonth'); if (_feedPurchEl) _feedPurchEl.textContent = `${feedPurchased.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} kg`;
  const _feedConsEl = $('feedConsumedMonth'); if (_feedConsEl) _feedConsEl.textContent = `${feedConsumed.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} kg`;
  
  const feedBadge = $('feedLowStockCount');
  if (feedBadge) {
    feedBadge.textContent = feedLowStockCount;
    feedBadge.style.display = feedLowStockCount > 0 ? 'inline-block' : 'none';
  }

  // 2. MEDICINE CARD
  const medTx = window.AppStorage?.getInventoryByCategory(siteId, 'medicine') || [];
  const medStock = sumSignedQuantity(medTx);
  const medLowStockItems = (window.InventoryManager?.getLowStockItems(siteId) || []).filter(item => item.category === 'medicine');
  const medLowStockCount = medLowStockItems.length;

  // Expiring soon (within 30 days)
  let medExpiringCount = 0;
  const thirtyDaysLater = new Date();
  thirtyDaysLater.setDate(today.getDate() + 30);
  
  const medItems = new Set(medTx.map(t => t.itemName.toLowerCase()));
  medItems.forEach(name => {
    const stock = window.AppStorage?.getStockBalance(siteId, 'medicine', name) || 0;
    if (stock > 0) {
      const purchases = medTx.filter(t => t.itemName.toLowerCase() === name && t.type === 'purchase');
      const hasExpiring = purchases.some(p => {
        if (!p.details || !p.details.expiryDate) return false;
        const exp = new Date(p.details.expiryDate + 'T00:00:00'); // H1 fix: parse as local
        // H4 fix: only count items expiring WITHIN 30 days that are NOT already expired.
        // Previously any date <= thirtyDaysLater matched, including past dates.
        return exp >= today && exp <= thirtyDaysLater;
      });
      if (hasExpiring) {
        medExpiringCount++;
      }
    }
  });

  const _medStockEl = $('medCurrentStock'); if (_medStockEl) _medStockEl.textContent = `${(Math.round(medStock * 10) / 10).toLocaleString('en-US')} units`;
  const _medExpEl = $('medExpiringSoon'); if (_medExpEl) _medExpEl.textContent = medExpiringCount;
  
  const medBadge = $('medLowStockCount');
  if (medBadge) {
    medBadge.textContent = medLowStockCount;
    medBadge.style.display = medLowStockCount > 0 ? 'inline-block' : 'none';
  }

  // Render Feed Progress Bar
  const feedPct = feedPurchased > 0 ? Math.min(100, (feedConsumed / feedPurchased) * 100) : 0;
  const feedBarEl = $('feedCardProgressBar');
  if (feedBarEl) {
    feedBarEl.innerHTML = `
      <div class="db-progress-labels">
        <span>Monthly Ratio</span>
        <span>${feedPct.toFixed(0)}% Consumed</span>
      </div>
      <div class="db-progress-bar-bg">
        <div class="db-progress-bar-fill blue" style="width: ${feedPct}%"></div>
      </div>
    `;
  }

  // Render Medicine category list progress bars
  const medCounts = {};
  const standardMedCategories = ['Probiotics', 'Minerals', 'Lime', 'Salt', 'Molasses', 'Zeolite', 'Chlorine', 'Bleaching Powder', 'Vitamins', 'Water Treatment'];
  standardMedCategories.forEach(cat => medCounts[cat] = 0);
  medTx.forEach(t => {
    if (t.type === 'purchase') {
      const cat = t.details?.category || 'Other';
      if (medCounts[cat] !== undefined) medCounts[cat]++;
      else medCounts[cat] = (medCounts[cat] || 0) + 1;
    }
  });
  const activeMedCats = Object.entries(medCounts).filter(([_, count]) => count > 0).sort((a, b) => b[1] - a[1]).slice(0, 3);
  const medBarsEl = $('medCardCategoryBars');
  if (medBarsEl) {
    if (activeMedCats.length === 0) {
      medBarsEl.innerHTML = '<div style="font-size:0.7rem; color:var(--t3); text-align:center;">No stock categories yet</div>';
    } else {
      const maxMedCount = Math.max(...activeMedCats.map(c => c[1]));
      medBarsEl.innerHTML = activeMedCats.map(([cat, count]) => {
        const pct = maxMedCount > 0 ? (count / maxMedCount) * 100 : 0;
        return `
          <div class="med-dashboard-item">
            <div class="med-dashboard-item-header">
              <span>${cat}</span>
              <span>${count} items</span>
            </div>
            <div class="db-progress-bar-bg" style="height: 4px;">
              <div class="db-progress-bar-fill green" style="width: ${pct}%"></div>
            </div>
          </div>
        `;
      }).join('');
    }
  }

  // 3. FUEL CARD
  const fuelTx = window.AppStorage?.getInventoryByCategory(siteId, 'fuel') || [];
  const fuelStock = sumSignedQuantity(fuelTx);
  const fuelPurchased = window.InventoryManager?.getMonthlyPurchase(siteId, 'fuel', currentMonthStr)?.quantity || 0;
  const fuelConsumed = window.InventoryManager?.getMonthlyConsumption(siteId, 'fuel', currentMonthStr)?.quantity || 0;

  const _fuelStockEl = $('fuelCurrentStock'); if (_fuelStockEl) _fuelStockEl.textContent = `${fuelStock.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} L`;
  const _fuelPurchEl = $('fuelPurchasedMonth'); if (_fuelPurchEl) _fuelPurchEl.textContent = `${fuelPurchased.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} L`;
  const _fuelConsEl = $('fuelConsumedMonth'); if (_fuelConsEl) _fuelConsEl.textContent = `${fuelConsumed.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} L`;

  // Render Fuel Progress Bar
  const fuelPct = fuelPurchased > 0 ? Math.min(100, (fuelConsumed / fuelPurchased) * 100) : 0;
  const fuelBarEl = $('fuelCardProgressBar');
  if (fuelBarEl) {
    fuelBarEl.innerHTML = `
      <div class="db-progress-labels">
        <span>Monthly Ratio</span>
        <span>${fuelPct.toFixed(0)}% Consumed</span>
      </div>
      <div class="db-progress-bar-bg">
        <div class="db-progress-bar-fill amber" style="width: ${fuelPct}%"></div>
      </div>
    `;
  }
}

function renderFeedDetailPage() {
  const siteId = $('feedDetailSiteSelect')?.value;
  if (!siteId) return;

  const sites = window.SiteManager?.loadSites() || [];
  const activeSite = sites.find(s => s.id === siteId);
  const _feedSiteNameEl = $('feedDetailSiteName'); if (_feedSiteNameEl) _feedSiteNameEl.textContent = activeSite ? activeSite.name : 'Unknown Site';

  const searchQuery = ($('feedSearchInput')?.value || '').trim().toLowerCase();
  const fromStr = $('feedFilterDateFrom')?.value || '';
  const toStr = $('feedFilterDateTo')?.value || '';
  const lowStockOnly = $('feedFilterLowOnly')?.checked;
  const outOfStockOnly = $('feedFilterOutOnly')?.checked;

  const uniqueNames = getUniqueItemNamesForCategory(siteId, 'feed');
  
  let totalStock = 0;
  let totalItemsCount = 0;
  let lowStockCount = 0;
  let outOfStockCount = 0;
  
  const itemsData = uniqueNames.map(un => {
    const item = getItemDetails(siteId, 'feed', un.itemName);
    const stock = sumSignedQuantity(item.transactions);
    const threshold = getThresholdValue(siteId, 'feed', un.itemName);
    const status = getItemStatus(stock, threshold);
    
    totalStock += stock;
    totalItemsCount++;
    if (status.code === 'out') outOfStockCount++;
    else if (status.code === 'low') lowStockCount++;
    
    return { ...item, stock, threshold, status };
  });

  const filtered = itemsData.filter(item => {
    if (searchQuery) {
      const matchName = item.itemName.toLowerCase().includes(searchQuery);
      const matchSize = (item.details.feedSize || '').toLowerCase().includes(searchQuery);
      const matchSupplier = item.lastSupplier.toLowerCase().includes(searchQuery);
      if (!matchName && !matchSize && !matchSupplier) return false;
    }
    if (fromStr || toStr) {
      const hasTxInRange = item.transactions.some(t => {
        if (fromStr && t.purchaseDate < fromStr) return false;
        if (toStr && t.purchaseDate > toStr) return false;
        return true;
      });
      if (!hasTxInRange) return false;
    }
    if (lowStockOnly && item.status.code !== 'low') return false;
    if (outOfStockOnly && item.status.code !== 'out') return false;
    return true;
  });

  const _fsTsEl = $('feedSumTotalStock'); if (_fsTsEl) _fsTsEl.textContent = `${totalStock.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} kg`;
  const _fsTiEl = $('feedSumTotalItems'); if (_fsTiEl) _fsTiEl.textContent = totalItemsCount;
  const _fsLsEl = $('feedSumLowStock'); if (_fsLsEl) _fsLsEl.textContent = lowStockCount;
  const _fsOsEl = $('feedSumOutOfStock'); if (_fsOsEl) _fsOsEl.textContent = outOfStockCount;

  const listEl = $('feedDetailItemsList');
  if (!listEl) return;
  listEl.innerHTML = '';

  if (itemsData.length === 0) {
    listEl.innerHTML = `
      <div class="empty-state-card">
        <span class="empty-state-icon">🌾</span>
        <div class="empty-state-title">No feed inventory yet</div>
        <div class="empty-state-desc">Add your first feed purchase to start tracking supplies.</div>
        <button class="pill-btn green-btn" id="btnFeedEmptyAdd" style="margin-top:10px; padding:0 20px; height:38px; font-size:0.82rem; border-radius:10px;">Add Purchase</button>
      </div>
    `;
    $('btnFeedEmptyAdd')?.addEventListener('click', openPurchaseFeedModal);
  } else if (filtered.length === 0) {
    listEl.innerHTML = `
      <div style="text-align: center; color: var(--t3); padding: 40px 20px; font-size: 0.85rem;">
        No items found. Try a different search.
      </div>
    `;
  } else {
    filtered.forEach(item => {
      const card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML = `
        <div class="item-card-top">
          <div class="item-card-title-wrap">
            <div class="item-card-title">${escapeHTML(item.itemName)}</div>
            <div class="item-card-subtitle">Size: ${item.details.feedSize || '—'}</div>
          </div>
          <div class="item-status-indicator">
            <span class="status-dot ${item.status.colorClass}"></span>
            <span class="status-badge ${item.status.colorClass}">${item.status.label}</span>
          </div>
        </div>
        <div class="item-card-details">
          <div class="detail-item-col">
            <span class="detail-item-lbl">Current Stock</span>
            <span class="detail-item-val" style="color:var(--teal); font-weight:800;">${item.stock.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} kg</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Low Stock Limit</span>
            <span class="detail-item-val">${item.threshold.toLocaleString('en-US')} kg</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Last Purchase</span>
            <span class="detail-item-val">${item.lastPurchaseDate}</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Supplier</span>
            <span class="detail-item-val" style="white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${escapeHTML(item.lastSupplier)}</span>
          </div>
        </div>
        <div class="item-card-actions">
          <button class="pill-btn grey-btn edit-threshold-btn" data-category="feed" data-name="${escapeHTML(item.itemName)}">Edit Limit</button>
          <button class="pill-btn grey-btn view-tx-btn" data-category="feed" data-name="${escapeHTML(item.itemName)}">History</button>
        </div>
      `;
      listEl.appendChild(card);
    });
    
    listEl.querySelectorAll('.edit-threshold-btn').forEach(btn => {
      btn.addEventListener('click', () => openEditThresholdModal(siteId, btn.dataset.category, btn.dataset.name));
    });
    listEl.querySelectorAll('.view-tx-btn').forEach(btn => {
      btn.addEventListener('click', () => openItemTransactionHistory(siteId, btn.dataset.category, btn.dataset.name));
    });
  }
}

function renderMedicineDetailPage() {
  const siteId = $('medDetailSiteSelect')?.value;
  if (!siteId) return;

  const sites = window.SiteManager?.loadSites() || [];
  const activeSite = sites.find(s => s.id === siteId);
  const _medSiteNameEl = $('medDetailSiteName'); if (_medSiteNameEl) _medSiteNameEl.textContent = activeSite ? activeSite.name : 'Unknown Site';

  const searchQuery = ($('medSearchInput')?.value || '').trim().toLowerCase();
  const fromStr = $('medFilterDateFrom')?.value || '';
  const toStr = $('medFilterDateTo')?.value || '';
  const lowStockOnly = $('medFilterLowOnly')?.checked;
  const outOfStockOnly = $('medFilterOutOnly')?.checked;
  const expiringOnly = $('medFilterExpiringOnly')?.checked;

  const uniqueNames = getUniqueItemNamesForCategory(siteId, 'medicine');
  
  let totalItemsCount = 0;
  let lowStockCount = 0;
  let outOfStockCount = 0;
  let expiringSoonCount = 0;

  const itemsData = uniqueNames.map(un => {
    const item = getItemDetails(siteId, 'medicine', un.itemName);
    const stock = sumSignedQuantity(item.transactions);
    const threshold = getThresholdValue(siteId, 'medicine', un.itemName);
    const status = getItemStatus(stock, threshold);
    
    totalItemsCount++;
    if (status.code === 'out') outOfStockCount++;
    else if (status.code === 'low') lowStockCount++;
    
    const expiry = getExpiryStatus(item.details.expiryDate || null);
    if (stock > 0 && expiry && (expiry.code === 'expired' || expiry.code === 'expiring')) {
      expiringSoonCount++;
    }
    
    return { ...item, stock, threshold, status, expiry };
  });

  const filtered = itemsData.filter(item => {
    if (searchQuery) {
      const matchName = item.itemName.toLowerCase().includes(searchQuery);
      const matchCategory = (item.details.category || '').toLowerCase().includes(searchQuery);
      const matchSupplier = item.lastSupplier.toLowerCase().includes(searchQuery);
      if (!matchName && !matchCategory && !matchSupplier) return false;
    }
    if (fromStr || toStr) {
      const hasTxInRange = item.transactions.some(t => {
        if (fromStr && t.purchaseDate < fromStr) return false;
        if (toStr && t.purchaseDate > toStr) return false;
        return true;
      });
      if (!hasTxInRange) return false;
    }
    if (lowStockOnly && item.status.code !== 'low') return false;
    if (outOfStockOnly && item.status.code !== 'out') return false;
    if (expiringOnly && (!item.expiry || (item.expiry.code !== 'expired' && item.expiry.code !== 'expiring') || item.stock <= 0)) return false;
    return true;
  });

  const _msTiEl = $('medSumTotalItems'); if (_msTiEl) _msTiEl.textContent = totalItemsCount;
  const _msExEl = $('medSumExpiring'); if (_msExEl) _msExEl.textContent = expiringSoonCount;
  const _msLsEl = $('medSumLowStock'); if (_msLsEl) _msLsEl.textContent = lowStockCount;
  const _msOsEl = $('medSumOutOfStock'); if (_msOsEl) _msOsEl.textContent = outOfStockCount;

  const listEl = $('medDetailItemsList');
  if (!listEl) return;
  listEl.innerHTML = '';

  if (itemsData.length === 0) {
    listEl.innerHTML = `
      <div class="empty-state-card">
        <span class="empty-state-icon">🧪</span>
        <div class="empty-state-title">No medicine inventory yet</div>
        <div class="empty-state-desc">Add your first medicine or mineral purchase to start tracking supplies.</div>
        <button class="pill-btn green-btn" id="btnMedEmptyAdd" style="margin-top:10px; padding:0 20px; height:38px; font-size:0.82rem; border-radius:10px;">Add Purchase</button>
      </div>
    `;
    $('btnMedEmptyAdd')?.addEventListener('click', openPurchaseMedicineModal);
  } else if (filtered.length === 0) {
    listEl.innerHTML = `
      <div style="text-align: center; color: var(--t3); padding: 40px 20px; font-size: 0.85rem;">
        No items found. Try a different search.
      </div>
    `;
  } else {
    filtered.forEach(item => {
      const expiryStyle = item.expiry ? `color:${item.expiry.color}; font-weight:700;` : '';
      const expiryText = item.expiry ? `${item.details.expiryDate} (${item.expiry.label})` : '—';
      
      const card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML = `
        <div class="item-card-top">
          <div class="item-card-title-wrap">
            <div class="item-card-title">${escapeHTML(item.itemName)}</div>
            <div class="item-card-subtitle">Category: ${item.details.category || 'Other'}</div>
          </div>
          <div class="item-status-indicator">
            <span class="status-dot ${item.status.colorClass}"></span>
            <span class="status-badge ${item.status.colorClass}">${item.status.label}</span>
          </div>
        </div>
        <div class="item-card-details">
          <div class="detail-item-col">
            <span class="detail-item-lbl">Current Stock</span>
            <span class="detail-item-val" style="color:var(--teal); font-weight:800;">${item.stock.toLocaleString('en-US', {maximumFractionDigits:2})} ${item.unit}</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Low Stock Limit</span>
            <span class="detail-item-val">${item.threshold.toLocaleString('en-US')} ${item.unit}</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Expiry Date</span>
            <span class="detail-item-val" style="${expiryStyle}">${expiryText}</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Supplier</span>
            <span class="detail-item-val" style="white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${escapeHTML(item.lastSupplier)}</span>
          </div>
        </div>
        <div class="item-card-actions">
          <button class="pill-btn grey-btn edit-threshold-btn" data-category="medicine" data-name="${escapeHTML(item.itemName)}">Edit Limit</button>
          <button class="pill-btn grey-btn view-tx-btn" data-category="medicine" data-name="${escapeHTML(item.itemName)}">History</button>
        </div>
      `;
      listEl.appendChild(card);
    });
    
    listEl.querySelectorAll('.edit-threshold-btn').forEach(btn => {
      btn.addEventListener('click', () => openEditThresholdModal(siteId, btn.dataset.category, btn.dataset.name));
    });
    listEl.querySelectorAll('.view-tx-btn').forEach(btn => {
      btn.addEventListener('click', () => openItemTransactionHistory(siteId, btn.dataset.category, btn.dataset.name));
    });
  }
}

function renderFuelDetailPage() {
  const siteId = $('fuelDetailSiteSelect')?.value;
  if (!siteId) return;

  const sites = window.SiteManager?.loadSites() || [];
  const activeSite = sites.find(s => s.id === siteId);
  const _fuelSiteNameEl = $('fuelDetailSiteName'); if (_fuelSiteNameEl) _fuelSiteNameEl.textContent = activeSite ? activeSite.name : 'Unknown Site';

  const searchQuery = ($('fuelSearchInput')?.value || '').trim().toLowerCase();
  const fromStr = $('fuelFilterDateFrom')?.value || '';
  const toStr = $('fuelFilterDateTo')?.value || '';
  const lowStockOnly = $('fuelFilterLowOnly')?.checked;
  const outOfStockOnly = $('fuelFilterOutOnly')?.checked;

  const uniqueNames = getUniqueItemNamesForCategory(siteId, 'fuel');
  
  let totalStock = 0;
  let totalItemsCount = 0;
  let lowStockCount = 0;
  let outOfStockCount = 0;

  const itemsData = uniqueNames.map(un => {
    const item = getItemDetails(siteId, 'fuel', un.itemName);
    const stock = sumSignedQuantity(item.transactions);
    const threshold = getThresholdValue(siteId, 'fuel', un.itemName);
    const status = getItemStatus(stock, threshold);
    
    totalStock += stock;
    totalItemsCount++;
    if (status.code === 'out') outOfStockCount++;
    else if (status.code === 'low') lowStockCount++;
    
    return { ...item, stock, threshold, status };
  });

  const filtered = itemsData.filter(item => {
    if (searchQuery) {
      const matchName = item.itemName.toLowerCase().includes(searchQuery);
      const matchSupplier = item.lastSupplier.toLowerCase().includes(searchQuery);
      if (!matchName && !matchSupplier) return false;
    }
    if (fromStr || toStr) {
      const hasTxInRange = item.transactions.some(t => {
        if (fromStr && t.purchaseDate < fromStr) return false;
        if (toStr && t.purchaseDate > toStr) return false;
        return true;
      });
      if (!hasTxInRange) return false;
    }
    if (lowStockOnly && item.status.code !== 'low') return false;
    if (outOfStockOnly && item.status.code !== 'out') return false;
    return true;
  });

  const _fuTsEl = $('fuelSumTotalStock'); if (_fuTsEl) _fuTsEl.textContent = `${totalStock.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} L`;
  const _fuTiEl = $('fuelSumTotalItems'); if (_fuTiEl) _fuTiEl.textContent = totalItemsCount;
  const _fuLsEl = $('fuelSumLowStock'); if (_fuLsEl) _fuLsEl.textContent = lowStockCount;
  const _fuOsEl = $('fuelSumOutOfStock'); if (_fuOsEl) _fuOsEl.textContent = outOfStockCount;

  const listEl = $('fuelDetailItemsList');
  if (!listEl) return;
  listEl.innerHTML = '';

  if (itemsData.length === 0) {
    listEl.innerHTML = `
      <div class="empty-state-card">
        <span class="empty-state-icon">⛽</span>
        <div class="empty-state-title">No fuel inventory yet</div>
        <div class="empty-state-desc">Add your first fuel purchase to start tracking supplies.</div>
        <button class="pill-btn green-btn" id="btnFuelEmptyAdd" style="margin-top:10px; padding:0 20px; height:38px; font-size:0.82rem; border-radius:10px;">Add Purchase</button>
      </div>
    `;
    $('btnFuelEmptyAdd')?.addEventListener('click', openPurchaseFuelModal);
  } else if (filtered.length === 0) {
    listEl.innerHTML = `
      <div style="text-align: center; color: var(--t3); padding: 40px 20px; font-size: 0.85rem;">
        No items found. Try a different search.
      </div>
    `;
  } else {
    filtered.forEach(item => {
      const card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML = `
        <div class="item-card-top">
          <div class="item-card-title-wrap">
            <div class="item-card-title">${escapeHTML(item.itemName)}</div>
            <div class="item-card-subtitle">Fuel Type</div>
          </div>
          <div class="item-status-indicator">
            <span class="status-dot ${item.status.colorClass}"></span>
            <span class="status-badge ${item.status.colorClass}">${item.status.label}</span>
          </div>
        </div>
        <div class="item-card-details">
          <div class="detail-item-col">
            <span class="detail-item-lbl">Current Stock</span>
            <span class="detail-item-val" style="color:var(--teal); font-weight:800;">${item.stock.toLocaleString('en-US', {minimumFractionDigits:1, maximumFractionDigits:1})} L</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Low Stock Limit</span>
            <span class="detail-item-val">${item.threshold.toLocaleString('en-US')} L</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Last Purchase</span>
            <span class="detail-item-val">${item.lastPurchaseDate}</span>
          </div>
          <div class="detail-item-col">
            <span class="detail-item-lbl">Supplier</span>
            <span class="detail-item-val" style="white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${escapeHTML(item.lastSupplier)}</span>
          </div>
        </div>
        <div class="item-card-actions">
          <button class="pill-btn grey-btn edit-threshold-btn" data-category="fuel" data-name="${escapeHTML(item.itemName)}">Edit Limit</button>
          <button class="pill-btn grey-btn view-tx-btn" data-category="fuel" data-name="${escapeHTML(item.itemName)}">History</button>
        </div>
      `;
      listEl.appendChild(card);
    });
    
    listEl.querySelectorAll('.edit-threshold-btn').forEach(btn => {
      btn.addEventListener('click', () => openEditThresholdModal(siteId, btn.dataset.category, btn.dataset.name));
    });
    listEl.querySelectorAll('.view-tx-btn').forEach(btn => {
      btn.addEventListener('click', () => openItemTransactionHistory(siteId, btn.dataset.category, btn.dataset.name));
    });
  }
}

function openEditThresholdModal(siteId, category, itemName) {
  thresholdItemKey = `${siteId}::${category}::${itemName.toLowerCase()}`;
  thresholdCategory = category;
  thresholdItemName = itemName;

  const currentVal = getThresholdValue(siteId, category, itemName);
  $('thresholdInputValue').value = currentVal;
  const _etNameEl = $('editThresholdItemName'); if (_etNameEl) _etNameEl.textContent = itemName;

  const unitLabels = { feed: 'kg', medicine: 'units', fuel: 'L' };
  const _etUnitEl = $('thresholdUnitLabel'); if (_etUnitEl) _etUnitEl.textContent = unitLabels[category] || 'units';

  clearFieldError('errThresholdInputValue', 'thresholdInputValue');
  openModal('editThresholdModal');
}

function doSaveThreshold() {
  clearFieldError('errThresholdInputValue', 'thresholdInputValue');
  const val = Number($('thresholdInputValue').value);

  if (isNaN(val) || val < 0) {
    showFieldError('errThresholdInputValue', 'thresholdInputValue', 'Enter a valid positive number');
    return;
  }

  if (window.AppStorage && window.AppStorage.getInventoryThresholds) {
    const customThresholds = window.AppStorage.getInventoryThresholds();
    if (thresholdItemKey) {
      customThresholds[thresholdItemKey] = val;
      window.AppStorage.saveInventoryThresholds(customThresholds);
      showToast('✅', 'Threshold Saved', 'Low stock limit updated successfully');
      closeModal('editThresholdModal');
      
      renderInventoryDashboard();
      if (currentPage === 'pageFeedDetail') renderFeedDetailPage();
      else if (currentPage === 'pageMedicineDetail') renderMedicineDetailPage();
      else if (currentPage === 'pageFuelDetail') renderFuelDetailPage();
    }
  }
}

function isValidPurchaseDate(dateStr) {
  if (!dateStr || !dateStr.trim()) return false;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return false;
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return false;
  const today = new Date();
  today.setHours(23, 59, 59, 999);
  if (d > today) return false;
  return true;
}

function checkDuplicatePurchase(currentSiteId, category, purchaseData) {
  if (!window.AppStorage) return false;
  const transactions = window.AppStorage.getAllInventoryTransactions() || [];
  
  const targetSupplier = (purchaseData.supplier || '').trim().toLowerCase();
  const targetRef = (purchaseData.referenceNumber || '').trim().toLowerCase();
  const targetDate = purchaseData.purchaseDate;
  const targetQty = Number(purchaseData.quantity);
  const targetItem = (purchaseData.itemName || '').trim().toLowerCase();

  return transactions.some(t => {
    if (t.siteId !== currentSiteId || t.category !== category || t.type !== 'purchase') return false;
    
    const sameSupplier = (t.supplier || '').trim().toLowerCase() === targetSupplier;
    const sameDate = t.purchaseDate === targetDate;
    const sameQty = Number(t.quantity) === targetQty;
    const sameItem = (t.itemName || '').trim().toLowerCase() === targetItem;
    const sameRef = (t.referenceNumber || '').trim().toLowerCase() === targetRef;
    
    return sameSupplier && sameDate && sameQty && sameItem && sameRef;
  });
}

function setSaveButtonLoading(btnId, isLoading) {
  const btn = $(btnId);
  if (!btn) return;
  if (isLoading) {
    btn.disabled = true;
    if (!btn.dataset.originalText) {
      btn.dataset.originalText = btn.textContent;
    }
    btn.textContent = 'Saving...';
    btn.style.opacity = '0.6';
    btn.style.cursor = 'not-allowed';
  } else {
    btn.disabled = false;
    if (btn.dataset.originalText) {
      btn.textContent = btn.dataset.originalText;
    }
    btn.style.opacity = '';
    btn.style.cursor = '';
  }
}

function updateFeedPurchaseCalc() {
  const weightEl = $('feedCalcWeight');
  const costEl = $('feedCalcCost');

  const bagWeightVal = $('feedBagWeight')?.value || '';
  const numBagsVal = $('feedNumBags')?.value || '';
  const priceBagVal = $('feedPricePerBag')?.value || '';

  const bagWeight = Number(bagWeightVal);
  const numBags = Number(numBagsVal);
  const priceBag = Number(priceBagVal);

  const isBagWeightValid = bagWeightVal !== '' && !isNaN(bagWeight) && bagWeight > 0;
  const isNumBagsValid = numBagsVal !== '' && !isNaN(numBags) && Number.isInteger(numBags) && numBags > 0;

  if (!isBagWeightValid || !isNumBagsValid) {
    if (weightEl) {
      if (weightEl.tagName === 'INPUT') weightEl.value = '';
      else weightEl.textContent = '';
    }
    if (costEl) {
      if (costEl.tagName === 'INPUT') costEl.value = '';
      else costEl.textContent = '';
    }
    return;
  }

  const totalWeight = bagWeight * numBags;
  const totalCost = (priceBagVal !== '' && !isNaN(priceBag) && priceBag >= 0) ? priceBag * numBags : 0;

  if (weightEl) {
    const txt = `${totalWeight.toFixed(1)} kg`;
    if (weightEl.tagName === 'INPUT') weightEl.value = txt;
    else weightEl.textContent = txt;
  }
  if (costEl) {
    const txt = `${totalCost.toFixed(2)}`;
    if (costEl.tagName === 'INPUT') costEl.value = txt;
    else costEl.textContent = txt;
  }
}

function updateMedicinePurchaseCalc() {
  // L14 fix: null-check elements (was throwing if element was missing)
  const qtyEl = $('medQty');
  const priceEl = $('medUnitPrice');
  const costEl = $('medCalcCost');
  if (!qtyEl || !priceEl || !costEl) return;
  const qty = Number(qtyEl.value) || 0;
  const price = Number(priceEl.value) || 0;
  costEl.textContent = `${(qty * price).toFixed(2)}`;
}

function updateFuelPurchaseCalc() {
  // L14 fix: null-check elements
  const qtyEl = $('fuelQty');
  const priceEl = $('fuelPricePerLiter');
  const costEl = $('fuelCalcCost');
  if (!qtyEl || !priceEl || !costEl) return;
  const qty = Number(qtyEl.value) || 0;
  const price = Number(priceEl.value) || 0;
  const totalCost = qty * price;
  $('fuelCalcCost').textContent = `${totalCost.toFixed(2)}`;
}

function openPurchaseFeedModal() {
  const t = new Date();
  const yyyy = t.getFullYear();
  const mm = String(t.getMonth()+1).padStart(2,'0');
  const dd = String(t.getDate()).padStart(2,'0');
  const today = `${yyyy}-${mm}-${dd}`;
  
  $('feedPurchaseDate').value = today;
  $('feedSupplier').value = '';
  $('feedBrand').value = '';
  $('feedSize').value = '';
  $('feedBagWeight').value = '';
  $('feedNumBags').value = '';
  $('feedPricePerBag').value = '';
  $('feedNotes').value = '';

  // Clear errors
  // L1 fix: errFeedSize was missing from this list
  ['errFeedPurchaseDate', 'errFeedSupplier', 'errFeedBrand', 'errFeedSize', 'errFeedBagWeight', 'errFeedNumBags', 'errFeedPricePerBag'].forEach(errId => {
    const fieldId = errId.replace('errFeed', 'feed').charAt(0).toLowerCase() + errId.replace('errFeed', 'feed').slice(1);
    clearFieldError(errId, fieldId);
  });

  updateFeedPurchaseCalc();
  openModal('purchaseFeedModal');
}

function openPurchaseMedicineModal() {
  const t = new Date();
  const yyyy = t.getFullYear();
  const mm = String(t.getMonth()+1).padStart(2,'0');
  const dd = String(t.getDate()).padStart(2,'0');
  const today = `${yyyy}-${mm}-${dd}`;
  
  $('medPurchaseDate').value = today;
  $('medItemName').value = '';
  $('medCategory').value = '';
  $('medSupplier').value = '';
  $('medUnit').value = '';
  $('medQty').value = '';
  $('medUnitPrice').value = '';
  $('medExpiryDate').value = '';
  $('medNotes').value = '';

  // Clear errors
  ['errMedPurchaseDate', 'errMedItemName', 'errMedCategory', 'errMedSupplier', 'errMedUnit', 'errMedQty', 'errMedUnitPrice'].forEach(errId => {
    const fieldId = errId.replace('errMed', 'med').charAt(0).toLowerCase() + errId.replace('errMed', 'med').slice(1);
    clearFieldError(errId, fieldId);
  });

  updateMedicinePurchaseCalc();
  openModal('purchaseMedicineModal');
}

function openPurchaseFuelModal() {
  const t = new Date();
  const yyyy = t.getFullYear();
  const mm = String(t.getMonth()+1).padStart(2,'0');
  const dd = String(t.getDate()).padStart(2,'0');
  const today = `${yyyy}-${mm}-${dd}`;
  
  $('fuelPurchaseDate').value = today;
  $('fuelType').value = '';
  $('fuelSupplier').value = '';
  $('fuelQty').value = '';
  $('fuelPricePerLiter').value = '';
  $('fuelNotes').value = '';

  // Clear errors
  ['errFuelPurchaseDate', 'errFuelType', 'errFuelSupplier', 'errFuelQty', 'errFuelPricePerLiter'].forEach(errId => {
    const fieldId = errId.replace('errFuel', 'fuel').charAt(0).toLowerCase() + errId.replace('errFuel', 'fuel').slice(1);
    clearFieldError(errId, fieldId);
  });

  updateFuelPurchaseCalc();
  openModal('purchaseFuelModal');
}

function checkDuplicateItemName(siteId, category, itemName) {
  const transactions = window.AppStorage.getInventoryByCategory(siteId, category);
  return transactions.some(t => t.itemName.toLowerCase() === itemName.toLowerCase());
}

function doSaveFeedPurchase() {
  clearFieldError('errFeedPurchaseDate', 'feedPurchaseDate');
  clearFieldError('errFeedSupplier', 'feedSupplier');
  clearFieldError('errFeedBrand', 'feedBrand');
  clearFieldError('errFeedSize', 'feedSize');
  clearFieldError('errFeedBagWeight', 'feedBagWeight');
  clearFieldError('errFeedNumBags', 'feedNumBags');
  clearFieldError('errFeedPricePerBag', 'feedPricePerBag');

  // Disable button to prevent multiple saves
  setSaveButtonLoading('purchaseFeedSave', true);

  const date = $('feedPurchaseDate').value;
  const supplier = $('feedSupplier').value.trim();
  const feedBrand = $('feedBrand').value.trim();
  const feedSize = $('feedSize').value.trim();
  const bagWeightVal = $('feedBagWeight').value;
  const numBagsVal = $('feedNumBags').value;
  const pricePerBagVal = $('feedPricePerBag').value;

  const bagWeight = Number(bagWeightVal) || 0;
  const numBags = Number(numBagsVal) || 0;
  const pricePerBag = Number(pricePerBagVal) || 0;
  const notes = $('feedNotes').value.trim();

  let hasError = false;
  let firstErrId = null;

  const markError = (errId, inputId, msg) => {
    showFieldError(errId, inputId, msg);
    hasError = true;
    if (!firstErrId) firstErrId = inputId;
  };

  if (!date) {
    markError('errFeedPurchaseDate', 'feedPurchaseDate', 'Date is required');
  } else if (!isValidPurchaseDate(date)) {
    if (isFutureDateStr(date)) {
      markError('errFeedPurchaseDate', 'feedPurchaseDate', 'Purchase date cannot be in the future');
    } else {
      markError('errFeedPurchaseDate', 'feedPurchaseDate', 'Malformed or invalid date format');
    }
  }

  if (!supplier) {
    markError('errFeedSupplier', 'feedSupplier', 'Supplier is required');
  }
  if (!feedBrand) {
    markError('errFeedBrand', 'feedBrand', 'Feed brand is required');
  }
  if (!feedSize) {
    markError('errFeedSize', 'feedSize', 'Feed size is required');
  }
  
  if (bagWeightVal === '' || isNaN(bagWeight) || bagWeight <= 0) {
    markError('errFeedBagWeight', 'feedBagWeight', 'Bag weight must be positive');
  }
  if (numBagsVal === '' || isNaN(numBags) || !Number.isInteger(numBags) || numBags <= 0) {
    markError('errFeedNumBags', 'feedNumBags', 'Number of bags must be positive integer');
  }
  if (pricePerBagVal === '' || isNaN(pricePerBag) || pricePerBag < 0) {
    markError('errFeedPricePerBag', 'feedPricePerBag', 'Price cannot be negative');
  }

  if (hasError) {
    setSaveButtonLoading('purchaseFeedSave', false);
    if (firstErrId) $(firstErrId).focus();
    return;
  }

  const currentSiteId = $('inventorySiteSelect')?.value;
  if (!currentSiteId) {
    showToast('⚠️', 'Error', 'No site selected');
    setSaveButtonLoading('purchaseFeedSave', false);
    return;
  }

  const targetItemName = feedSize === 'Other' ? feedBrand : feedSize;

  const saveAction = () => {
    setSaveButtonLoading('purchaseFeedSave', true);
    try {
      const result = window.InventoryManager.createTransaction({
        siteId: currentSiteId,
        type: 'purchase',
        category: 'feed',
        itemName: targetItemName,
        purchaseDate: date,
        supplier: supplier,
        notes: notes,
        unitPrice: bagWeight > 0 ? +(pricePerBag / bagWeight).toFixed(4) : 0,
        totalCost: numBags * pricePerBag,
        details: {
          feedBrand: feedBrand,
          feedSize: feedSize,
          bagWeight: bagWeight,
          numberOfBags: numBags,
        }
      });

      if (result.success) {
        showToast('✅', 'Purchase Saved', 'Feed purchase recorded successfully');
        closeModal('purchaseFeedModal');
        refreshActiveInventoryPage();
      } else {
        showToast('❌', 'Save Failed', result.errors.join(' '));
      }
    } catch (err) {
      showToast('❌', 'Error', err.message);
    } finally {
      setSaveButtonLoading('purchaseFeedSave', false);
    }
  };

  const isDupPurchase = checkDuplicatePurchase(currentSiteId, 'feed', {
    supplier,
    purchaseDate: date,
    quantity: bagWeight * numBags,
    itemName: targetItemName,
    referenceNumber: ''
  });

  if (isDupPurchase) {
    setSaveButtonLoading('purchaseFeedSave', false);
    showConfirm(
      'Duplicate Purchase Detected',
      `An identical purchase already exists. Do you want to save anyway?`,
      saveAction,
      { danger: false, confirmLabel: 'Save Anyway' }
    );
  } else {
    const isDuplicate = checkDuplicateItemName(currentSiteId, 'feed', targetItemName);
    if (isDuplicate) {
      setSaveButtonLoading('purchaseFeedSave', false);
      showConfirm(
        'Duplicate Item Name',
        `An item named "${targetItemName}" already exists in the Feed category. Do you want to record another purchase for this item?`,
        saveAction,
        { danger: false, confirmLabel: 'Save Purchase' }
      );
    } else {
      saveAction();
    }
  }
}

function doSaveMedicinePurchase() {
  clearFieldError('errMedPurchaseDate', 'medPurchaseDate');
  clearFieldError('errMedItemName', 'medItemName');
  clearFieldError('errMedCategory', 'medCategory');
  clearFieldError('errMedSupplier', 'medSupplier');
  clearFieldError('errMedUnit', 'medUnit');
  clearFieldError('errMedQty', 'medQty');
  clearFieldError('errMedUnitPrice', 'medUnitPrice');

  setSaveButtonLoading('purchaseMedicineSave', true);

  const date = $('medPurchaseDate').value;
  const itemName = $('medItemName').value.trim();
  const category = $('medCategory').value;
  const supplier = $('medSupplier').value.trim();
  const unit = $('medUnit').value;
  const qtyVal = $('medQty').value;
  const unitPriceVal = $('medUnitPrice').value;
  const expiryDate = $('medExpiryDate').value;
  const notes = $('medNotes').value.trim();

  const qty = Number(qtyVal) || 0;
  const unitPrice = Number(unitPriceVal) || 0;

  let hasError = false;
  let firstErrId = null;

  const markError = (errId, inputId, msg) => {
    showFieldError(errId, inputId, msg);
    hasError = true;
    if (!firstErrId) firstErrId = inputId;
  };

  if (!date) {
    markError('errMedPurchaseDate', 'medPurchaseDate', 'Date is required');
  } else if (!isValidPurchaseDate(date)) {
    if (isFutureDateStr(date)) {
      markError('errMedPurchaseDate', 'medPurchaseDate', 'Purchase date cannot be in the future');
    } else {
      markError('errMedPurchaseDate', 'medPurchaseDate', 'Malformed or invalid date format');
    }
  }

  if (!itemName) {
    markError('errMedItemName', 'medItemName', 'Item name is required');
  }
  if (!category) {
    markError('errMedCategory', 'medCategory', 'Category is required');
  }
  if (!supplier) {
    markError('errMedSupplier', 'medSupplier', 'Supplier is required');
  }
  if (!unit) {
    markError('errMedUnit', 'medUnit', 'Unit is required');
  }
  if (qtyVal === '' || isNaN(qty) || qty <= 0) {
    markError('errMedQty', 'medQty', 'Quantity must be positive');
  }
  if (unitPriceVal === '' || isNaN(unitPrice) || unitPrice < 0) {
    markError('errMedUnitPrice', 'medUnitPrice', 'Price cannot be negative');
  }

  if (hasError) {
    setSaveButtonLoading('purchaseMedicineSave', false);
    if (firstErrId) $(firstErrId).focus();
    return;
  }

  const currentSiteId = $('inventorySiteSelect')?.value;
  if (!currentSiteId) {
    showToast('⚠️', 'Error', 'No site selected');
    setSaveButtonLoading('purchaseMedicineSave', false);
    return;
  }

  const saveAction = () => {
    setSaveButtonLoading('purchaseMedicineSave', true);
    try {
      const result = window.InventoryManager.createTransaction({
        siteId: currentSiteId,
        type: 'purchase',
        category: 'medicine',
        itemName: itemName,
        purchaseDate: date,
        supplier: supplier,
        quantity: qty,
        unit: unit,
        unitPrice: unitPrice,
        totalCost: +(qty * unitPrice).toFixed(2),
        notes: notes,
        details: {
          itemName: itemName,
          category: category,
          unit: unit,
          expiryDate: expiryDate || null
        }
      });

      if (result.success) {
        showToast('✅', 'Purchase Saved', 'Medicine purchase recorded successfully');
        closeModal('purchaseMedicineModal');
        refreshActiveInventoryPage();
      } else {
        showToast('❌', 'Save Failed', result.errors.join(' '));
      }
    } catch (err) {
      showToast('❌', 'Error', err.message);
    } finally {
      setSaveButtonLoading('purchaseMedicineSave', false);
    }
  };

  const isDupPurchase = checkDuplicatePurchase(currentSiteId, 'medicine', {
    supplier,
    purchaseDate: date,
    quantity: qty,
    itemName: itemName,
    referenceNumber: ''
  });

  if (isDupPurchase) {
    setSaveButtonLoading('purchaseMedicineSave', false);
    showConfirm(
      'Duplicate Purchase Detected',
      `An identical purchase already exists. Do you want to save anyway?`,
      saveAction,
      { danger: false, confirmLabel: 'Save Anyway' }
    );
  } else {
    const isDuplicate = checkDuplicateItemName(currentSiteId, 'medicine', itemName);
    if (isDuplicate) {
      setSaveButtonLoading('purchaseMedicineSave', false);
      showConfirm(
        'Duplicate Item Name',
        `An item named "${itemName}" already exists in the Medicine category. Do you want to record another purchase for this item?`,
        saveAction,
        { danger: false, confirmLabel: 'Save Purchase' }
      );
    } else {
      saveAction();
    }
  }
}

function doSaveFuelPurchase() {
  clearFieldError('errFuelPurchaseDate', 'fuelPurchaseDate');
  clearFieldError('errFuelType', 'fuelType');
  clearFieldError('errFuelSupplier', 'fuelSupplier');
  clearFieldError('errFuelQty', 'fuelQty');
  clearFieldError('errFuelPricePerLiter', 'fuelPricePerLiter');

  setSaveButtonLoading('purchaseFuelSave', true);

  const date = $('fuelPurchaseDate').value;
  const fuelType = $('fuelType').value;
  const supplier = $('fuelSupplier').value.trim();
  const qtyVal = $('fuelQty').value;
  const pricePerLiterVal = $('fuelPricePerLiter').value;
  const notes = $('fuelNotes').value.trim();

  const qty = Number(qtyVal) || 0;
  const pricePerLiter = Number(pricePerLiterVal) || 0;

  let hasError = false;
  let firstErrId = null;

  const markError = (errId, inputId, msg) => {
    showFieldError(errId, inputId, msg);
    hasError = true;
    if (!firstErrId) firstErrId = inputId;
  };

  if (!date) {
    markError('errFuelPurchaseDate', 'fuelPurchaseDate', 'Date is required');
  } else if (!isValidPurchaseDate(date)) {
    if (isFutureDateStr(date)) {
      markError('errFuelPurchaseDate', 'fuelPurchaseDate', 'Purchase date cannot be in the future');
    } else {
      markError('errFuelPurchaseDate', 'fuelPurchaseDate', 'Malformed or invalid date format');
    }
  }

  if (!fuelType) {
    markError('errFuelType', 'fuelType', 'Fuel type is required');
  }
  if (!supplier) {
    markError('errFuelSupplier', 'fuelSupplier', 'Supplier is required');
  }
  if (qtyVal === '' || isNaN(qty) || qty <= 0) {
    markError('errFuelQty', 'fuelQty', 'Quantity must be positive');
  }
  if (pricePerLiterVal === '' || isNaN(pricePerLiter) || pricePerLiter < 0) {
    markError('errFuelPricePerLiter', 'fuelPricePerLiter', 'Price cannot be negative');
  }

  if (hasError) {
    setSaveButtonLoading('purchaseFuelSave', false);
    if (firstErrId) $(firstErrId).focus();
    return;
  }

  const currentSiteId = $('inventorySiteSelect')?.value;
  if (!currentSiteId) {
    showToast('⚠️', 'Error', 'No site selected');
    setSaveButtonLoading('purchaseFuelSave', false);
    return;
  }

  const saveAction = () => {
    setSaveButtonLoading('purchaseFuelSave', true);
    try {
      const result = window.InventoryManager.createTransaction({
        siteId: currentSiteId,
        type: 'purchase',
        category: 'fuel',
        itemName: fuelType,
        purchaseDate: date,
        supplier: supplier,
        quantity: qty,
        unit: 'Liter',
        unitPrice: pricePerLiter,
        totalCost: +(qty * pricePerLiter).toFixed(2),
        notes: notes,
        details: {
          fuelType: fuelType,
          quantity: qty,
          pricePerLiter: pricePerLiter
        }
      });

      if (result.success) {
        showToast('✅', 'Purchase Saved', 'Fuel purchase recorded successfully');
        closeModal('purchaseFuelModal');
        refreshActiveInventoryPage();
      } else {
        showToast('❌', 'Save Failed', result.errors.join(' '));
      }
    } catch (err) {
      showToast('❌', 'Error', err.message);
    } finally {
      setSaveButtonLoading('purchaseFuelSave', false);
    }
  };

  const isDupPurchase = checkDuplicatePurchase(currentSiteId, 'fuel', {
    supplier,
    purchaseDate: date,
    quantity: qty,
    itemName: fuelType,
    referenceNumber: ''
  });

  if (isDupPurchase) {
    setSaveButtonLoading('purchaseFuelSave', false);
    showConfirm(
      'Duplicate Purchase Detected',
      `An identical purchase already exists. Do you want to save anyway?`,
      saveAction,
      { danger: false, confirmLabel: 'Save Anyway' }
    );
  } else {
    const isDuplicate = checkDuplicateItemName(currentSiteId, 'fuel', fuelType);
    if (isDuplicate) {
      setSaveButtonLoading('purchaseFuelSave', false);
      showConfirm(
        'Duplicate Item Name',
        `An item named "${fuelType}" already exists in the Fuel category. Do you want to record another purchase for this item?`,
        saveAction,
        { danger: false, confirmLabel: 'Save Purchase' }
      );
    } else {
      saveAction();
    }
  }
}

function openItemTransactionHistory(siteId, category, itemName) {
  const titleEl = $('inventoryDetailTitle');
  if (titleEl) titleEl.textContent = `${itemName} — History`;

  const contentEl = $('inventoryDetailContent');
  if (!contentEl) return;
  contentEl.innerHTML = '';

  const txs = window.AppStorage.getInventoryByCategory(siteId, category)
    .filter(t => (t.itemName || '').trim().toLowerCase() === itemName.toLowerCase())
    .sort((a, b) => b.purchaseDate.localeCompare(a.purchaseDate) || b.createdAt.localeCompare(a.createdAt));

  if (txs.length === 0) {
    contentEl.innerHTML = `<div style="text-align: center; color: var(--t3); padding: 20px; font-size: 0.85rem;">No transaction history found.</div>`;
  } else {
    txs.forEach(tx => {
      const row = document.createElement('div');
      row.className = 'tx-detail-row';
      row.style.cssText = 'background: rgba(255, 255, 255, 0.02); border: 1px solid var(--border); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; gap: 4px;';
      
      const isPurchase = tx.type === 'purchase';
      const typeLabel = tx.type.replace('_', ' ');
      const valSign = isPurchase ? '+' : '-';
      const valColor = isPurchase ? 'var(--green)' : 'var(--red)';
      
      let costBlock = '';
      if (isPurchase) {
        const qty = Math.abs(tx.quantity || 0);
        const price = tx.unitPrice || 0;
        const totalCost = qty * price;
        costBlock = `<div style="font-size: 0.72rem; color: var(--t3); margin-top: 1px;">Cost: ₹${totalCost.toFixed(2)} (₹${price.toFixed(2)}/${tx.unit})</div>`;
      }

      let refBlock = '';
      if (tx.details && tx.details.source === 'feed_log') {
        refBlock = `<div style="font-size: 0.72rem; color: var(--teal); font-weight:600; margin-top: 1px;">Linked Feed Log Entry</div>`;
      }

      row.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span style="font-weight: 700; color: var(--t1); font-size: 0.88rem;">${escapeHTML(tx.itemName)}</span>
          <span class="tx-badge badge-${tx.type}">${typeLabel}</span>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 0.8rem; color: var(--t2); margin-top: 2px;">
          <span>Date: ${tx.purchaseDate}</span>
          <span style="font-weight: 700; color: ${valColor};">${valSign}${Math.abs(tx.quantity)} ${tx.unit}</span>
        </div>
        ${tx.supplier ? `<div style="font-size: 0.72rem; color: var(--t3); margin-top: 1px;">Supplier: ${escapeHTML(tx.supplier)}</div>` : ''}
        ${costBlock}
        ${refBlock}
        ${tx.notes ? `<div style="font-size: 0.72rem; color: var(--t3); font-style: italic; margin-top: 1px;">Notes: ${escapeHTML(tx.notes)}</div>` : ''}
      `;
      contentEl.appendChild(row);
    });
  }

  openModal('inventoryDetailModal');
}

function bindEnterKeyToSave(inputId, saveBtnId) {
  $(inputId)?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      $(saveBtnId)?.click();
    }
  });
}

function bindInventoryEvents() {
  // Site selector listeners
  $('inventorySiteSelect')?.addEventListener('change', (e) => syncAllSiteDropdowns(e.target.value));
  $('feedDetailSiteSelect')?.addEventListener('change', (e) => syncAllSiteDropdowns(e.target.value));
  $('medDetailSiteSelect')?.addEventListener('change', (e) => syncAllSiteDropdowns(e.target.value));
  $('fuelDetailSiteSelect')?.addEventListener('change', (e) => syncAllSiteDropdowns(e.target.value));

  // Quick Add click listeners
  $('btnQuickAddFeed')?.addEventListener('click', openPurchaseFeedModal);
  $('btnQuickAddMedicine')?.addEventListener('click', openPurchaseMedicineModal);
  $('btnQuickAddFuel')?.addEventListener('click', openPurchaseFuelModal);

  // View Details click listeners (Detail page navigation)
  $('btnViewDetailsFeed')?.addEventListener('click', () => switchPage('pageFeedDetail'));
  $('btnViewDetailsMedicine')?.addEventListener('click', () => switchPage('pageMedicineDetail'));
  $('btnViewDetailsFuel')?.addEventListener('click', () => switchPage('pageFuelDetail'));

  // Detail View Back buttons
  $('btnBackFeedDetail')?.addEventListener('click', () => switchPage('pageInventory'));
  $('btnBackMedicineDetail')?.addEventListener('click', () => switchPage('pageInventory'));
  $('btnBackFuelDetail')?.addEventListener('click', () => switchPage('pageInventory'));

  // Cancel click listeners
  $('purchaseFeedCancel')?.addEventListener('click', () => closeModal('purchaseFeedModal'));
  $('purchaseMedicineCancel')?.addEventListener('click', () => closeModal('purchaseMedicineModal'));
  $('purchaseFuelCancel')?.addEventListener('click', () => closeModal('purchaseFuelModal'));
  $('inventoryDetailClose')?.addEventListener('click', () => closeModal('inventoryDetailModal'));
  $('editThresholdCancel')?.addEventListener('click', () => closeModal('editThresholdModal'));

  // Threshold modal save
  $('editThresholdSave')?.addEventListener('click', doSaveThreshold);
  bindEnterKeyToSave('thresholdInputValue', 'editThresholdSave');

  // Backdrop overlay click listeners
  $('purchaseFeedModal')?.addEventListener('click', (e) => {
    if (e.target === $('purchaseFeedModal')) closeModal('purchaseFeedModal');
  });
  $('purchaseMedicineModal')?.addEventListener('click', (e) => {
    if (e.target === $('purchaseMedicineModal')) closeModal('purchaseMedicineModal');
  });
  $('purchaseFuelModal')?.addEventListener('click', (e) => {
    if (e.target === $('purchaseFuelModal')) closeModal('purchaseFuelModal');
  });
  $('inventoryDetailModal')?.addEventListener('click', (e) => {
    if (e.target === $('inventoryDetailModal')) closeModal('inventoryDetailModal');
  });
  $('editThresholdModal')?.addEventListener('click', (e) => {
    if (e.target === $('editThresholdModal')) closeModal('editThresholdModal');
  });

  // Real-time calculation inputs
  ['feedBagWeight', 'feedNumBags', 'feedPricePerBag'].forEach(id => {
    $(id)?.addEventListener('input', updateFeedPurchaseCalc);
  });
  ['medQty', 'medUnitPrice'].forEach(id => {
    $(id)?.addEventListener('input', updateMedicinePurchaseCalc);
  });
  ['fuelQty', 'fuelPricePerLiter'].forEach(id => {
    $(id)?.addEventListener('input', updateFuelPurchaseCalc);
  });

  // Save buttons
  $('purchaseFeedSave')?.addEventListener('click', doSaveFeedPurchase);
  $('purchaseMedicineSave')?.addEventListener('click', doSaveMedicinePurchase);
  $('purchaseFuelSave')?.addEventListener('click', doSaveFuelPurchase);

  // Enter key down bindings
  ['feedSupplier', 'feedBrand', 'feedSize', 'feedBagWeight', 'feedNumBags', 'feedPricePerBag'].forEach(id => {
    bindEnterKeyToSave(id, 'purchaseFeedSave');
  });
  ['medItemName', 'medCategory', 'medSupplier', 'medUnit', 'medQty', 'medUnitPrice'].forEach(id => {
    bindEnterKeyToSave(id, 'purchaseMedicineSave');
  });
  ['fuelSupplier', 'fuelQty', 'fuelPricePerLiter'].forEach(id => {
    bindEnterKeyToSave(id, 'purchaseFuelSave');
  });

  // Instant Search listeners
  $('feedSearchInput')?.addEventListener('input', renderFeedDetailPage);
  $('medSearchInput')?.addEventListener('input', renderMedicineDetailPage);
  $('fuelSearchInput')?.addEventListener('input', renderFuelDetailPage);

  // Filter inputs
  ['feedFilterDateFrom', 'feedFilterDateTo'].forEach(id => {
    $(id)?.addEventListener('input', renderFeedDetailPage);
  });
  ['feedFilterLowOnly', 'feedFilterOutOnly'].forEach(id => {
    $(id)?.addEventListener('change', renderFeedDetailPage);
  });

  ['medFilterDateFrom', 'medFilterDateTo'].forEach(id => {
    $(id)?.addEventListener('input', renderMedicineDetailPage);
  });
  ['medFilterLowOnly', 'medFilterOutOnly', 'medFilterExpiringOnly'].forEach(id => {
    $(id)?.addEventListener('change', renderMedicineDetailPage);
  });

  ['fuelFilterDateFrom', 'fuelFilterDateTo'].forEach(id => {
    $(id)?.addEventListener('input', renderFuelDetailPage);
  });
  ['fuelFilterLowOnly', 'fuelFilterOutOnly'].forEach(id => {
    $(id)?.addEventListener('change', renderFuelDetailPage);
  });

  // Clear filters
  $('btnClearFeedFilters')?.addEventListener('click', () => {
    if ($('feedFilterDateFrom')) $('feedFilterDateFrom').value = '';
    if ($('feedFilterDateTo')) $('feedFilterDateTo').value = '';
    if ($('feedFilterLowOnly')) $('feedFilterLowOnly').checked = false;
    if ($('feedFilterOutOnly')) $('feedFilterOutOnly').checked = false;
    if ($('feedSearchInput')) $('feedSearchInput').value = '';
    renderFeedDetailPage();
  });
  $('btnClearMedFilters')?.addEventListener('click', () => {
    if ($('medFilterDateFrom')) $('medFilterDateFrom').value = '';
    if ($('medFilterDateTo')) $('medFilterDateTo').value = '';
    if ($('medFilterLowOnly')) $('medFilterLowOnly').checked = false;
    if ($('medFilterOutOnly')) $('medFilterOutOnly').checked = false;
    if ($('medFilterExpiringOnly')) $('medFilterExpiringOnly').checked = false;
    if ($('medSearchInput')) $('medSearchInput').value = '';
    renderMedicineDetailPage();
  });
  $('btnClearFuelFilters')?.addEventListener('click', () => {
    if ($('fuelFilterDateFrom')) $('fuelFilterDateFrom').value = '';
    if ($('fuelFilterDateTo')) $('fuelFilterDateTo').value = '';
    if ($('fuelFilterLowOnly')) $('fuelFilterLowOnly').checked = false;
    if ($('fuelFilterOutOnly')) $('fuelFilterOutOnly').checked = false;
    if ($('fuelSearchInput')) $('fuelSearchInput').value = '';
    renderFuelDetailPage();
  });
}

// Window bindings for backward compatibility
window.getInventoryMedicineItems = getInventoryMedicineItems;
window.populateInventorySiteSelect = populateInventorySiteSelect;
window.syncAllSiteDropdowns = syncAllSiteDropdowns;
window.refreshActiveInventoryPage = refreshActiveInventoryPage;
window.sumSignedQuantity = sumSignedQuantity;
window.getThresholdValue = getThresholdValue;
window.getItemStatus = getItemStatus;
window.getExpiryStatus = getExpiryStatus;
window.getUniqueItemNamesForCategory = getUniqueItemNamesForCategory;
window.getItemDetails = getItemDetails;
window.renderInventoryDashboard = renderInventoryDashboard;
window.renderFeedDetailPage = renderFeedDetailPage;
window.renderMedicineDetailPage = renderMedicineDetailPage;
window.renderFuelDetailPage = renderFuelDetailPage;
window.openEditThresholdModal = openEditThresholdModal;
window.doSaveThreshold = doSaveThreshold;
window.isValidPurchaseDate = isValidPurchaseDate;
window.checkDuplicatePurchase = checkDuplicatePurchase;
window.setSaveButtonLoading = setSaveButtonLoading;
window.updateFeedPurchaseCalc = updateFeedPurchaseCalc;
window.updateMedicinePurchaseCalc = updateMedicinePurchaseCalc;
window.updateFuelPurchaseCalc = updateFuelPurchaseCalc;
window.openPurchaseFeedModal = openPurchaseFeedModal;
window.openPurchaseMedicineModal = openPurchaseMedicineModal;
window.openPurchaseFuelModal = openPurchaseFuelModal;
window.checkDuplicateItemName = checkDuplicateItemName;
window.doSaveFeedPurchase = doSaveFeedPurchase;
window.doSaveMedicinePurchase = doSaveMedicinePurchase;
window.doSaveFuelPurchase = doSaveFuelPurchase;
window.openItemTransactionHistory = openItemTransactionHistory;
window.bindEnterKeyToSave = bindEnterKeyToSave;
window.bindInventoryEvents = bindInventoryEvents;
})();

// --- Module: pond.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

let archivePondId = null;
let deletePondId = null;

function renderManagePage() {
  const activePonds   = ponds.filter(p => p.active);
  const inactivePonds = ponds.filter(p => !p.active);
  const sitesCount    = (window.SiteManager && window.SiteManager.loadSites) ? window.SiteManager.loadSites().length : 0;
  const activeBatchesCount = batches.filter(b => b.status === 'active' || !b.completedAt).length;

  // ── Primary action cards: counts ──
  const mpcSitesEl   = $('mpcSitesCount');
  const mpcPondsEl   = $('mpcPondsCount');
  const mpcBatchesEl = $('mpcBatchesCount');
  if (mpcSitesEl)   mpcSitesEl.textContent   = sitesCount + (sitesCount === 1 ? ' site'  : ' sites');
  if (mpcPondsEl)   mpcPondsEl.textContent   = activePonds.length + (activePonds.length === 1 ? ' pond'   : ' ponds');
  if (mpcBatchesEl) mpcBatchesEl.textContent = activeBatchesCount + ' active';

  // ── Active Pond chips selector ──
  renderManagePondChips(activePonds);

  // ── Pond Management Card carousel ──
  renderManagePondPager(activePonds);

  // ── Inactive ponds section ──
  const inactiveSection = $('inactiveSection');
  if (inactivePonds.length) {
    if (!inactiveSection) return;
    inactiveSection.classList.remove('hidden');
    const inactiveContainer = $('inactivePondsList');
    if (!inactiveContainer) return;
    inactiveContainer.innerHTML = '';
    inactivePonds.forEach(pond => renderPondCard(pond, inactiveContainer));
  } else if (inactiveSection) {
    inactiveSection.classList.add('hidden');
  }

  // ── Tools & Analytics section: render the compare buttons inline ──
  renderManageToolsSection();

  // ── Sites list (inline, hidden by default; toggled via primary card) ──
  renderManageSites();

  renderCompletedBatches();
}

/* ── Active Pond chips: rendered at top of Manage page ── */
let manageActivePondIndex = 0; // currently selected pond in the pager

function renderManagePondChips(activePonds) {
  const chipsContainer = $('managePondChips');
  if (!chipsContainer) return;
  if (!activePonds.length) {
    chipsContainer.innerHTML = '';
    return;
  }
  // Clamp index to valid range
  if (manageActivePondIndex >= activePonds.length) manageActivePondIndex = 0;
  if (manageActivePondIndex < 0) manageActivePondIndex = 0;

  chipsContainer.innerHTML = activePonds.map((pond, idx) => {
    const isActive = idx === manageActivePondIndex;
    return `<button class="manage-pond-chip${isActive ? ' active' : ''}" data-pond-idx="${idx}" role="tab" aria-selected="${isActive ? 'true' : 'false'}">
      <span class="mpc-dot"></span>
      <span class="mpc-name">${escapeHTML(pond.name)}</span>
    </button>`;
  }).join('');

  // Bind click → scroll pager to that card
  chipsContainer.querySelectorAll('.manage-pond-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      const idx = parseInt(chip.dataset.pondIdx, 10);
      manageActivePondIndex = idx;
      const pager = $('managePondPager');
      const card = pager && pager.children[idx];
      if (card) {
        pager.scrollTo({ left: card.offsetLeft - pager.offsetLeft - 8, behavior: 'smooth' });
      }
      // Update active styles
      chipsContainer.querySelectorAll('.manage-pond-chip').forEach((c, i) => {
        const a = i === idx;
        c.classList.toggle('active', a);
        c.setAttribute('aria-selected', a ? 'true' : 'false');
      });
    });
  });
}

/* ── Pond Management Card carousel: one full-screen-width card per active pond ── */
function renderManagePondPager(activePonds) {
  const pager = $('managePondPager');
  const empty = $('managePondPagerEmpty');
  if (!pager) return;

  if (!activePonds.length) {
    pager.innerHTML = '';
    pager.classList.add('hidden');
    if (empty) empty.classList.remove('hidden');
    return;
  }
  pager.classList.remove('hidden');
  if (empty) empty.classList.add('hidden');

  if (manageActivePondIndex >= activePonds.length) manageActivePondIndex = 0;

  pager.innerHTML = activePonds.map(pond => renderManagePondCardHTML(pond)).join('');

  // Bind action buttons inside each card
  pager.querySelectorAll('[data-pond-id]').forEach(card => {
    const pondId = card.dataset.pondId;
    const editBtn = card.querySelector('.mppc-edit-btn');
    if (editBtn) editBtn.addEventListener('click', () => openEditPondModal(pondId));

    const viewBtn = card.querySelector('.mppc-view-btn');
    if (viewBtn) viewBtn.addEventListener('click', () => {
      const batch = getActiveBatchForPond(pondId);
      if (batch) openViewBatchModal(batch.id);
      else showToast('ℹ️', 'No Active Batch', 'Create a batch first to view details.');
    });

    const completeBtn = card.querySelector('.mppc-complete-btn');
    if (completeBtn) completeBtn.addEventListener('click', () => {
      const batch = getActiveBatchForPond(pondId);
      if (batch) openCompleteBatchModal(batch.id);
    });

    const createBtn = card.querySelector('.mppc-create-batch-btn');
    if (createBtn) createBtn.addEventListener('click', () => openCreateBatchModal(pondId));

    const feedBtn = card.querySelector('.mppc-feed-btn');
    if (feedBtn) feedBtn.addEventListener('click', () => {
      switchPage('pageLog');
      const batch = getActiveBatchForPond(pondId);
      setTimeout(() => {
        const sel = $('pondSelect');
        if (sel) sel.value = pondId;
        if (window.alSelects && alSelects.pondSelect) alSelects.pondSelect.sync();
      }, 100);
    });

    const wqBtn = card.querySelector('.mppc-wq-btn');
    if (wqBtn) wqBtn.addEventListener('click', () => {
      if (typeof window.openWaterQualityModal === 'function') {
        window.openWaterQualityModal(pondId);
      } else {
        showToast('ℹ️', 'Water Quality', 'Open from the batch view to log water quality.');
      }
    });
  });

  // Sync chip active state when user scrolls the pager
  if (!pager._aqScrollHooked) {
    pager._aqScrollHooked = true;
    let scrollTimer = null;
    pager.addEventListener('scroll', () => {
      if (scrollTimer) clearTimeout(scrollTimer);
      scrollTimer = setTimeout(() => {
        const cardWidth = pager.children[0] ? pager.children[0].offsetWidth + 12 : 1;
        const idx = Math.round(pager.scrollLeft / cardWidth);
        if (idx !== manageActivePondIndex && idx >= 0 && idx < activePonds.length) {
          manageActivePondIndex = idx;
          const chipsContainer = $('managePondChips');
          if (chipsContainer) {
            chipsContainer.querySelectorAll('.manage-pond-chip').forEach((c, i) => {
              const a = i === idx;
              c.classList.toggle('active', a);
              c.setAttribute('aria-selected', a ? 'true' : 'false');
            });
            // Auto-scroll the chip into view
            const activeChip = chipsContainer.children[idx];
            if (activeChip) activeChip.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
          }
        }
      }, 120);
    });
  }

  // Scroll to the currently-selected card
  setTimeout(() => {
    const card = pager.children[manageActivePondIndex];
    if (card) pager.scrollTo({ left: card.offsetLeft - pager.offsetLeft - 8, behavior: 'auto' });
  }, 30);
}

/* ── Build a single Pond Management Card's HTML ── */
function renderManagePondCardHTML(pond) {
  const activeBatch = getActiveBatchForPond(pond.id);
  const doc = activeBatch ? calcDOC(activeBatch.stockingDate) : null;
  const siteName = pond.site || 'No site assigned';
  const sizeStr = pond.sizeSqFt > 0 ? Number(pond.sizeSqFt).toLocaleString() + ' sqft' : '';

  // Status pill
  const statusPill = activeBatch
    ? `<span class="mppc-status-pill active">Active</span>`
    : `<span class="mppc-status-pill idle">Idle</span>`;

  // Active batch section
  let batchSection = '';
  if (activeBatch) {
    const stocked = Number(activeBatch.shrimpCount || 0).toLocaleString();
    const feedCount = records.filter(r => r.BatchId === activeBatch.id).length;
    const totalFeedG = records
      .filter(r => r.BatchId === activeBatch.id)
      .reduce((sum, r) => sum + sumGrams([r]), 0);
    const totalFeedKg = (totalFeedG / 1000).toFixed(2);

    // Latest sampling ABW
    let abw = '—';
    if (window.sampling && Array.isArray(window.sampling)) {
      const s = window.sampling.filter(x => x.batchId === activeBatch.id).slice(-1)[0];
      if (s && s.abw) abw = Number(s.abw).toFixed(1) + 'g';
    } else if (activeBatch.latestABW) {
      abw = Number(activeBatch.latestABW).toFixed(1) + 'g';
    }

    // Survival estimate
    const survival = activeBatch.survivalRate != null
      ? Number(activeBatch.survivalRate).toFixed(0) + '%'
      : '—';

    // Estimated biomass
    let biomass = '—';
    if (activeBatch.shrimpCount && abw !== '—') {
      const abwNum = parseFloat(abw);
      const est = (Number(activeBatch.shrimpCount) * abwNum) / 1000;
      biomass = est.toFixed(1) + ' kg';
    }

    batchSection = `
      <div class="mppc-section">
        <div class="mppc-section-title">🦐 Active Batch</div>
        <div class="mppc-metric-grid">
          <div class="mppc-metric">
            <div class="mppc-metric-label">Batch</div>
            <div class="mppc-metric-value teal">#${activeBatch.batchNumber}</div>
          </div>
          <div class="mppc-metric">
            <div class="mppc-metric-label">DOC</div>
            <div class="mppc-metric-value">${doc} d</div>
          </div>
          <div class="mppc-metric">
            <div class="mppc-metric-label">Stocked</div>
            <div class="mppc-metric-value">${stocked}</div>
          </div>
          <div class="mppc-metric">
            <div class="mppc-metric-label">ABW</div>
            <div class="mppc-metric-value teal">${abw}</div>
          </div>
          <div class="mppc-metric">
            <div class="mppc-metric-label">Survival</div>
            <div class="mppc-metric-value">${survival}</div>
          </div>
          <div class="mppc-metric">
            <div class="mppc-metric-label">Biomass</div>
            <div class="mppc-metric-value">${biomass}</div>
          </div>
        </div>
        <div class="mppc-section" style="margin-top:10px;padding-top:10px;">
          <div class="mppc-section-title">📊 Feed Summary</div>
          <div class="mppc-metric-grid">
            <div class="mppc-metric">
              <div class="mppc-metric-label">Sessions</div>
              <div class="mppc-metric-value">${feedCount}</div>
            </div>
            <div class="mppc-metric" style="grid-column: span 2;">
              <div class="mppc-metric-label">Total Feed</div>
              <div class="mppc-metric-value teal">${totalFeedKg} kg</div>
            </div>
          </div>
        </div>
      </div>
    `;
  } else {
    batchSection = `
      <div class="mppc-section">
        <div class="mppc-alert-row ok">
          <span class="mpa-icon">✅</span>
          <span>No active batch — ready to stock</span>
        </div>
      </div>
    `;
  }

  // Alerts section (sampling due, etc.)
  let alertsSection = '';
  if (activeBatch) {
    const samplingBadge = getSamplingBadgeHTML ? getSamplingBadgeHTML(activeBatch) : '';
    const hapaBadge = getHapaBadgeHTML ? getHapaBadgeHTML(activeBatch.id, doc) : '';
    if (samplingBadge || hapaBadge) {
      // Crude extraction of badge text to determine alert level
      const combined = (samplingBadge || '') + (hapaBadge || '');
      let cls = 'ok';
      let icon = '✅';
      let msg = 'All checks up to date';
      if (/due|overdue/i.test(combined)) { cls = ''; icon = '⏰'; msg = 'Sampling due — schedule a check'; }
      if (/critical|alert/i.test(combined)) { cls = 'critical'; icon = '⚠️'; msg = 'Critical: needs attention'; }
      alertsSection = `
        <div class="mppc-section">
          <div class="mppc-alert-row ${cls}">
            <span class="mpa-icon">${icon}</span>
            <span>${msg}</span>
          </div>
        </div>
      `;
    }
  }

  // Quick actions
  let actionsSection;
  if (activeBatch) {
    actionsSection = `
      <div class="mppc-actions">
        <button class="mppc-action-btn mppc-feed-btn">🍚 Log Feed</button>
        <button class="mppc-action-btn mppc-view-btn">👁 View Batch</button>
        <button class="mppc-action-btn mppc-complete-btn">✓ Complete</button>
        <button class="mppc-action-btn mppc-edit-btn">✏ Edit Pond</button>
      </div>
    `;
  } else {
    actionsSection = `
      <div class="mppc-actions">
        <button class="mppc-action-btn primary mppc-create-batch-btn">＋ Create Batch</button>
        <button class="mppc-action-btn mppc-edit-btn">✏ Edit Pond</button>
        <button class="mppc-action-btn mppc-wq-btn">💧 Water Quality</button>
      </div>
    `;
  }

  return `
    <div class="manage-pond-pager-card" data-pond-id="${pond.id}">
      <div class="mppc-header">
        <div class="mppc-title-block">
          <div class="mppc-pond-name">${escapeHTML(pond.name)}</div>
          <div class="mppc-site-name">📍 ${escapeHTML(siteName)}${sizeStr ? ' · ' + sizeStr : ''}</div>
        </div>
        ${statusPill}
      </div>
      ${batchSection}
      ${alertsSection}
      ${actionsSection}
    </div>
  `;
}

/* ── Tools & Analytics section: render the compare buttons inside the collapsible card ── */
function renderManageToolsSection() {
  const grid = $('manageToolsGrid');
  if (!grid) return;
  // Only render once; extra-features.js's injected buttons may also land here.
  if (grid.dataset.aqRendered === '1') return;
  grid.dataset.aqRendered = '1';

  grid.innerHTML = `
    <button class="manage-tool-btn" id="manageToolComparePonds" type="button">
      <span class="mtb-icon">🛤</span>
      <span class="mtb-label">Compare Ponds</span>
      <span class="mtb-sub">Side-by-side pond metrics</span>
    </button>
    <button class="manage-tool-btn" id="manageToolCompareBatches" type="button">
      <span class="mtb-icon">⚖️</span>
      <span class="mtb-label">Compare Batches</span>
      <span class="mtb-sub">Compare active batches</span>
    </button>
    <button class="manage-tool-btn" id="manageToolGrowth" type="button">
      <span class="mtb-icon">📈</span>
      <span class="mtb-label">Growth Comparison</span>
      <span class="mtb-sub">Track ABW milestones</span>
    </button>
    <button class="manage-tool-btn" id="manageToolSites" type="button">
      <span class="mtb-icon">📍</span>
      <span class="mtb-label">Manage Sites</span>
      <span class="mtb-sub">View, add, edit farm sites</span>
    </button>
  `;

  // Wire buttons to trigger the existing compare modals
  const wire = (id, fallback) => {
    const btn = $(id);
    if (!btn) return;
    btn.addEventListener('click', () => {
      // Try to click the dynamically-injected compare button if it exists
      const injected = document.querySelector('.aq-compare-btn-wrap .aq-compare-btn, .aq-pond-compare-btn-wrap .aq-compare-btn, .aq-growth-compare-btn-wrap .aq-compare-btn');
      if (injected && fallback && typeof fallback === 'function') fallback();
      else if (typeof fallback === 'function') fallback();
    });
  };
  wire('manageToolComparePonds',  () => { const b = document.getElementById('aqPondCompareBtn');  if (b) b.click(); else showToast('ℹ️', 'Compare Ponds',  'Open after a moment…'); });
  wire('manageToolCompareBatches', () => { const b = document.getElementById('aqBatchCompareBtn'); if (b) b.click(); else showToast('ℹ️', 'Compare Batches', 'Open after a moment…'); });
  wire('manageToolGrowth',        () => { const b = document.getElementById('aqGrowthCompareBtn'); if (b) b.click(); else showToast('ℹ️', 'Growth Comparison', 'Open after a moment…'); });
  wire('manageToolSites',         () => toggleManageSitesSection(true));
}

/* ── Toggle the inline Sites section visibility (driven by primary card + Tools button) ── */
function toggleManageSitesSection(forceShow) {
  const section = $('manageSitesSection');
  if (!section) return;
  if (forceShow === true) {
    section.classList.remove('hidden');
    setTimeout(() => section.scrollIntoView({ behavior: 'smooth', block: 'start' }), 80);
  } else if (forceShow === false) {
    section.classList.add('hidden');
  } else {
    section.classList.toggle('hidden');
  }
}

function renderPondCard(pond, container) {
  const activeBatch = getActiveBatchForPond(pond.id);
  const doc = activeBatch ? calcDOC(activeBatch.stockingDate) : null;
  const feedCount = activeBatch ? records.filter(r => r.BatchId === activeBatch.id).length : 0;
  const isInactive = !pond.active;

  const card = document.createElement('div');
  card.className = 'pond-card' + (isInactive ? ' inactive-pond' : '');

  let batchSection = '';
  let actionSection = '';

  if (isInactive) {
    // Inactive pond: show restore and (if clean) delete
    const hasBatches = batches.some(b => b.pondId === pond.id);
    const hasFeedLogs = records.some(r => r.PondId === pond.id);
    const canDelete = !hasBatches && !hasFeedLogs;

    batchSection = `<div class="pond-card-batch no-batch-info">
      <div class="pca-no-badge">Archived</div>
    </div>`;
    actionSection = `<div class="pond-card-actions" style="flex-wrap:wrap;gap:8px;">
      <button class="pond-action-btn edit-pond-btn" data-pondid="${pond.id}">Edit Pond</button>
      <button class="pond-action-btn restore-pond-btn" data-pondid="${pond.id}">↺ Restore</button>
      ${canDelete ? `<button class="pond-action-btn delete-pond-btn" data-pondid="${pond.id}">Delete</button>` : ''}
    </div>`;
  } else if (activeBatch) {
    // Active pond with active batch — no archive button, show batch controls
    const stockedCountFormatted = Number(activeBatch.shrimpCount || 0).toLocaleString();
    const hapaBadge = getHapaBadgeHTML(activeBatch.id, doc);
    const samplingBadge = getSamplingBadgeHTML(activeBatch);
    const hapaEntry = getHapaForBatch(activeBatch.id);
    const hapaActionBtn = !hapaEntry
      ? `<button class="pond-action-btn hapa-entry-btn" data-batchid="${activeBatch.id}">🔍 Hapa Check</button>`
      : '';
    
    let badgesHTML = '';
    if (hapaBadge || samplingBadge) {
      badgesHTML = `<div class="pbs-badges" style="margin-top:8px; display:flex; flex-wrap:wrap; gap:8px;">
        ${hapaBadge}
        ${samplingBadge}
      </div>`;
    }

    batchSection = `
      <div class="pond-batch-summary">
        <div class="pbs-header">Active Batch</div>
        <div class="pbs-grid">
          <span class="pbs-pill batch-pill">Batch #${activeBatch.batchNumber}</span>
          <span class="pbs-pill doc-pill">DOC ${doc}</span>
          <span class="pbs-pill stocked-pill">${stockedCountFormatted} Stocked</span>
        </div>
        ${badgesHTML}
      </div>
    `;
    actionSection = `<div class="pond-card-actions" style="flex-wrap:wrap;gap:8px;">
      <button class="pond-action-btn edit-pond-btn" data-pondid="${pond.id}">Edit Pond</button>
      <button class="pond-action-btn view-batch-btn" data-batchid="${activeBatch.id}">View Batch</button>
      ${hapaActionBtn}
      <button class="pond-action-btn complete-batch-btn" data-batchid="${activeBatch.id}">Complete Batch</button>
    </div>`;
  } else {
    // Active pond, no active batch — can create batch, archive, or delete if clean
    const hasBatches = batches.some(b => b.pondId === pond.id);
    const hasFeedLogs = records.some(r => r.PondId === pond.id);
    const canDelete = !hasBatches && !hasFeedLogs;

    batchSection = `<div class="pond-card-batch no-batch-info">
      <div class="pca-no-badge">No Active Batch</div>
    </div>`;
    actionSection = `<div class="pond-card-actions" style="flex-wrap:wrap;gap:8px;">
      <button class="pond-action-btn edit-pond-btn" data-pondid="${pond.id}">Edit Pond</button>
      <button class="pond-action-btn create-batch-btn" data-pondid="${pond.id}">＋ Create Batch</button>
      <button class="pond-action-btn archive-pond-btn" data-pondid="${pond.id}">Archive</button>
      ${canDelete ? `<button class="pond-action-btn delete-pond-btn" data-pondid="${pond.id}">Delete</button>` : ''}
    </div>`;
  }

  card.innerHTML = `
    <div class="pond-card-top">
      <div class="pond-card-info">
        <div class="pond-card-name">${escapeHTML(pond.name)}</div>
        <div class="pond-card-meta">${pond.site} · ${pond.sizeSqFt > 0 ? Number(pond.sizeSqFt).toLocaleString() + ' sqft' : 'Size not set'}</div>
      </div>
    </div>
    ${batchSection}
    ${actionSection}
  `;

  container.appendChild(card);

  // Bind buttons
  const editBtn = card.querySelector('.edit-pond-btn');
  if (editBtn) editBtn.addEventListener('click', () => openEditPondModal(editBtn.dataset.pondid));

  const viewBtn = card.querySelector('.view-batch-btn');
  if (viewBtn) viewBtn.addEventListener('click', () => openViewBatchModal(viewBtn.dataset.batchid));

  const completeBtnEl = card.querySelector('.complete-batch-btn');
  if (completeBtnEl) completeBtnEl.addEventListener('click', () => openCompleteBatchModal(completeBtnEl.dataset.batchid));

  const createBtnEl = card.querySelector('.create-batch-btn');
  if (createBtnEl) createBtnEl.addEventListener('click', () => openCreateBatchModal(createBtnEl.dataset.pondid));

  const archiveBtn = card.querySelector('.archive-pond-btn');
  if (archiveBtn) archiveBtn.addEventListener('click', () => openArchivePondModal(archiveBtn.dataset.pondid));

  const restoreBtn = card.querySelector('.restore-pond-btn');
  if (restoreBtn) restoreBtn.addEventListener('click', () => doRestorePond(restoreBtn.dataset.pondid));

  const deletePondBtn = card.querySelector('.delete-pond-btn');
  if (deletePondBtn) deletePondBtn.addEventListener('click', () => openDeletePondModal(deletePondBtn.dataset.pondid));

  const hapaBtnEl = card.querySelector('.hapa-entry-btn');
  if (hapaBtnEl) hapaBtnEl.addEventListener('click', () => openHapaEntryModal(hapaBtnEl.dataset.batchid));
}

function openEditPondModal(pondId) {
  const pond = ponds.find(p => p.id === pondId);
  if (!pond) return;
  editPondId = pondId;

  $('editPondName').value = pond.name || '';
  populateSiteSelect('editPondSite', pond.site || '');
  // Sync the custom AlSelect trigger so it shows the current site (not stale or overlapping text)
  if (window.alSelects && alSelects.editPondSite) {
    alSelects.editPondSite.sync();
  }
  $('editPondSize').value = pond.sizeSqFt || '';
  clearFieldError('errEditPondName', 'editPondName', 'Pond name is required');
  clearFieldError('errEditPondSite', 'editPondSite', 'Site is required');
  clearFieldError('errEditPondSize', 'editPondSize', 'Enter a valid size (positive number)');

  $('editPondModal').classList.remove('hidden');
  setTimeout(() => $('editPondName').focus(), 100);
}

function doEditPond() {
  if (!editPondId) return;
  const pond = ponds.find(p => p.id === editPondId);
  if (!pond) return;

  const name = $('editPondName').value.trim();
  const site = $('editPondSite').value.trim();
  const size = $('editPondSize').value;

  const validation = validatePondData(name, site, size, editPondId);
  clearFieldError('errEditPondName', 'editPondName', 'Pond name is required');
  clearFieldError('errEditPondSite', 'editPondSite', 'Site is required');
  clearFieldError('errEditPondSize', 'editPondSize', 'Enter a valid size (positive number)');
  if (validation.errors.name) showFieldError('errEditPondName', 'editPondName', validation.errors.name);
  if (validation.errors.site) showFieldError('errEditPondSite', 'editPondSite', validation.errors.site);
  if (validation.errors.size) showFieldError('errEditPondSize', 'editPondSize', validation.errors.size);
  if (!validation.ok) return;

  pond.name = name;
  pond.site = site;
  pond.siteId = lookupSiteIdByName(site);
  pond.sizeSqFt = numberFromField(size);

  savePonds();
  closeModal('editPondModal');
  editPondId = null;

  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  showToast('OK', 'Pond Updated', `${name} details saved`);
}

function openArchivePondModal(pondId) {
  const activeBatch = getActiveBatchForPond(pondId);
  if (activeBatch) {
    showToast('⚠️', 'Cannot Archive', 'Complete the active batch before archiving this pond.');
    return;
  }
  archivePondId = pondId;
  const pond = ponds.find(p => p.id === pondId);
  $('archivePondDesc').textContent = `"${pond ? pond.name : 'This pond'}" will be moved to inactive. Historical data is preserved.`;
  $('archivePondModal').classList.remove('hidden');
}

function doArchivePond() {
  if (!archivePondId) return;
  const pond = ponds.find(p => p.id === archivePondId);
  if (!pond) return;
  pond.active = false;
  savePonds();
  archivePondId = null;
  closeModal('archivePondModal');
  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  showToast('📦', 'Pond Archived', `${pond.name} moved to inactive ponds`);
}

function doRestorePond(pondId) {
  const pond = ponds.find(p => p.id === pondId);
  if (!pond) return;
  pond.active = true;
  savePonds();
  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  showToast('✅', 'Pond Restored', `${pond.name} is active again`);
}

function openDeletePondModal(pondId) {
  const hasBatches = batches.some(b => b.pondId === pondId);
  const hasFeedLogs = records.some(r => r.PondId === pondId);
  if (hasBatches || hasFeedLogs) {
    showToast('⚠️', 'Cannot Delete', 'This pond contains historical batches or feed logs and cannot be deleted. Archive it instead.');
    return;
  }
  deletePondId = pondId;
  $('deletePondModal').classList.remove('hidden');
}

function doDeletePond() {
  if (!deletePondId) return;
  // Final safety: re-check
  const hasBatches = batches.some(b => b.pondId === deletePondId);
  const hasFeedLogs = records.some(r => r.PondId === deletePondId);
  if (hasBatches || hasFeedLogs) {
    showToast('⚠️', 'Cannot Delete', 'This pond contains historical data and cannot be deleted.');
    closeModal('deletePondModal');
    deletePondId = null;
    return;
  }
  const pond = ponds.find(p => p.id === deletePondId);
  state.setPonds(state.ponds.filter(p => p.id !== deletePondId));
  savePonds();
  deletePondId = null;
  closeModal('deletePondModal');
  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  flashElement($('feedGrid') || $('farmOverviewContent'));
  showToast('🗑', 'Pond Deleted', pond ? `${pond.name} has been removed` : 'Pond removed');
}

function savePonds() {
  AppStorage.savePonds(ponds);
}

function hasDuplicatePond(name, site, ignoreId = null) {
  const nameLower = String(name || '').trim().toLowerCase();
  const siteLower = String(site || '').trim().toLowerCase();
  return ponds.some(p =>
    p.id !== ignoreId &&
    String(p.name || '').trim().toLowerCase() === nameLower &&
    String(p.site || '').trim().toLowerCase() === siteLower
  );
}

function validatePondData(name, site, size, ignoreId = null) {
  const errors = {};
  if (!name) errors.name = 'Pond name is required';
  if (!site) errors.site = 'Site is required';
  if (!isPositiveNumberField(size)) errors.size = 'Enter a valid size (positive number)';
  // L18 fix: add upper bound check (was accepting absurd values like 999999999)
  else if (Number(size) > 1000000) errors.size = 'Pond size seems too large (max 1,000,000 sq ft)';
  if (!errors.name && !errors.site && hasDuplicatePond(name, site, ignoreId)) {
    errors.name = 'A pond with this name already exists at this site.';
  }
  return { ok: Object.keys(errors).length === 0, errors };
}

function openCreatePondModal() {
  $('newPondName').value = '';
  populateSiteSelect('newPondSite', '');
  // Sync the custom AlSelect trigger so it shows the placeholder (not stale overlapping text)
  if (window.alSelects && alSelects.newPondSite) {
    alSelects.newPondSite.sync();
  }
  $('newPondSize').value = '';
  clearFieldError('errNewPondName', 'newPondName', 'Pond name is required');
  clearFieldError('errNewPondSite', 'newPondSite', 'Site is required');
  clearFieldError('errNewPondSize', 'newPondSize', 'Enter a valid size (positive number)');
  $('createPondModal').classList.remove('hidden');
  setTimeout(() => $('newPondName').focus(), 100);
}

function doCreatePond() {
  const name = $('newPondName').value.trim();
  const site = $('newPondSite').value.trim();
  const size = $('newPondSize').value;

  const validation = validatePondData(name, site, size);
  clearFieldError('errNewPondName', 'newPondName', 'Pond name is required');
  clearFieldError('errNewPondSite', 'newPondSite', 'Site is required');
  clearFieldError('errNewPondSize', 'newPondSize', 'Enter a valid size (positive number)');
  if (validation.errors.name) showFieldError('errNewPondName', 'newPondName', validation.errors.name);
  if (validation.errors.site) showFieldError('errNewPondSite', 'newPondSite', validation.errors.site);
  if (validation.errors.size) showFieldError('errNewPondSize', 'newPondSize', validation.errors.size);
  if (!validation.ok) return;

  const pond = {
    id: `pond_${Date.now()}_${Math.random().toString(36).slice(2,7)}`,
    name,
    site,
    siteId: lookupSiteIdByName(site),
    sizeSqFt: numberFromField(size),
    active: true,
  };

  ponds.push(pond);
  savePonds();
  closeModal('createPondModal');

  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  showToast('✅', 'Pond Created!', `${name} is ready for batches`);
}

function renderLogPondSelect() {
  const sel = $('pondSelect');
  const cur = sel.value;
  sel.innerHTML = '<option value="">— Select pond —</option>';

  // CHANGE 2: Only show ACTIVE (non-archived) ponds in feed logging
  const activePonds = ponds.filter(p => p.active);
  if (!activePonds.length) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = 'No ponds — go to Manage to create one';
    opt.disabled = true;
    sel.appendChild(opt);
    return;
  }

  const feedDate = $('feedDate').value;
  activePonds.forEach(p => {
    const o = document.createElement('option');
    o.value = p.id;
    // CHANGE 4: Show batch availability based on selected date
    if (feedDate) {
      const matched = findBatchForDate(p.id, feedDate);
      if (matched) {
        o.textContent = `${p.name} (Batch #${matched.batchNumber}${matched.status === 'active' ? ' Active' : ' Historical'})`;
      } else {
        const activeBatch = getActiveBatchForPond(p.id);
        if (activeBatch) {
          o.textContent = `${p.name} — no batch on this date`;
          o.disabled = true;
        } else {
          o.textContent = `${p.name} — no active batch`;
          o.disabled = true;
        }
      }
    } else {
      const activeBatch = getActiveBatchForPond(p.id);
      if (activeBatch) {
        o.textContent = `${p.name} (Batch #${activeBatch.batchNumber} Active)`;
      } else {
        o.textContent = `${p.name} — no active batch`;
        o.disabled = true;
      }
    }
    sel.appendChild(o);
  });

  if (cur) {
    const opt = sel.querySelector(`option[value="${cur}"]`);
    if (opt && !opt.disabled) sel.value = cur;
  }

  updateNoBatchWarning();
  alSelects.pondSelect?.refresh(); // Sync custom dropdown after options rebuild
}

  function getActivePondSiteId() {
    try {
      const pondId = document.getElementById('pondSelect')?.value;
      // Use AppStorage as the authoritative source — ponds is a module-scoped let, not on window
      const allPonds = window.AppStorage ? window.AppStorage.getPonds() : [];
      const pond = allPonds.find(p => p.id === pondId);
      return pond?.siteId || null;
    } catch { return null; }
  }

// Window bindings for backward compatibility
window.renderManagePage = renderManagePage;
window.renderPondCard = renderPondCard;
window.openEditPondModal = openEditPondModal;
window.doEditPond = doEditPond;
window.openArchivePondModal = openArchivePondModal;
window.doArchivePond = doArchivePond;
window.doRestorePond = doRestorePond;
window.openDeletePondModal = openDeletePondModal;
window.doDeletePond = doDeletePond;
window.savePonds = savePonds;
window.hasDuplicatePond = hasDuplicatePond;
window.validatePondData = validatePondData;
window.openCreatePondModal = openCreatePondModal;
window.doCreatePond = doCreatePond;
window.renderLogPondSelect = renderLogPondSelect;
window.getActivePondSiteId = getActivePondSiteId;

// MODAL_STATE_CLEANUP Registrations
window.MODAL_STATE_CLEANUP = window.MODAL_STATE_CLEANUP || {};
window.MODAL_STATE_CLEANUP.editPondModal = () => { editPondId = null; };
window.MODAL_STATE_CLEANUP.archivePondModal = () => { archivePondId = null; };
window.MODAL_STATE_CLEANUP.deletePondModal = () => { deletePondId = null; };
})();

// --- Module: batch.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

// C5 fix: _analyticsBatchId and _analyticsChartData declared here (were previously in the
// charts IIFE, causing a ReferenceError when toggleAnalyticsPanel and renderAnalyticsTabHeader
// assigned to them). _analyticsChartData is also assigned in renderAnalyticsGrowthChart.
let _analyticsBatchId = null;
let _analyticsChartData = null;

function getBatchCycleLength(batch) {
  if (batch.status === 'active') {
    return calcDOC(batch.stockingDate);
  } else {
    const stock = startOfDay(batch.stockingDate);
    const harvest = startOfDay(batch.harvestDate || (batch.completedAt ? batch.completedAt.split('T')[0] : batch.stockingDate));
    const diff = Math.floor((harvest - stock) / MS_PER_DAY);
    return diff >= 0 ? diff + 1 : 1;
  }
}

function getBatchFeedDataForDOC(batch) {
  const cycleLength = Math.max(1, getBatchCycleLength(batch));
  const data = [];
  
  for (let d = 1; d <= cycleLength; d++) {
    const dateStr = getDateForDOC(batch.stockingDate, d);
    const dayRecs = records.filter(r => r.BatchId === batch.id && r.Date === dateStr);
    const totalGrams = sumGrams(dayRecs);
    const feedDist   = feedSizeDistribution(dayRecs);
    const dateLabel  = dateStr ? startOfDay(dateStr).toLocaleDateString('en-IN',{day:'numeric',month:'short',year:'numeric'}) : '';
    
    data.push({
      label: `DOC ${d}`,
      value: totalGrams,
      _meta: { type: 'batch-doc', docNumber: d, dateStr, dateLabel, sessions: dayRecs.length, feedDist, batchId: batch.id, batchNumber: batch.batchNumber }
    });
  }
  return data;
}

function getBatchTotalFeed(batch) {
  const batchRecs = records.filter(r => r.BatchId === batch.id);
  return sumGrams(batchRecs);
}

function formatTotalFeed(grams) {
  const kg = grams / 1000;
  if (kg >= 1) {
    return kg.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 }) + ' kg';
  }
  return grams.toLocaleString() + ' g';
}

function renderBatchDashboard(batch) {
  const pond     = ponds.find(p => p.id === batch.pondId);
  const pondName = pond ? pond.name : (batch.pond || 'Unknown');
  const siteName = pond ? pond.site : 'Site Name';

  $('batchPondName').textContent   = pondName;
  $('batchSiteName').textContent   = siteName;
  $('batchNumberLabel').textContent = `Batch #${batch.batchNumber}`;

  const doc = getBatchCycleLength(batch);
  $('batchDocValue').textContent = batch.status === 'completed' ? `Final DOC ${doc}` : `DOC ${doc}`;

  const statusBadge = $('batchStatusBadge');
  if (statusBadge) {
    statusBadge.textContent        = batch.status.toUpperCase();
    statusBadge.className          = 'batch-status-badge';
    statusBadge.style.background   = batch.status === 'active'
      ? 'rgba(0, 212, 170, 0.15)' : 'rgba(56, 189, 248, 0.15)';
    statusBadge.style.color        = batch.status === 'active'
      ? 'var(--teal)' : 'var(--cyan)';
    statusBadge.style.borderColor  = batch.status === 'active'
      ? 'rgba(0, 212, 170, 0.35)' : 'rgba(56, 189, 248, 0.35)';
  }

  const stockedShrimp = Number(batch.shrimpCount || 0).toLocaleString();
  $('batchStockedShrimp').textContent = stockedShrimp;

  const totalFeedGrams = getBatchTotalFeed(batch);
  $('batchTotalFeed').textContent = formatTotalFeed(totalFeedGrams);

  const batchRecs = records.filter(r => r.BatchId === batch.id);
  const hasData   = batchRecs.length > 0 && totalFeedGrams > 0;

  // Show/hide feed analytics sections based on whether any feed has been logged
  const donutSection = document.querySelector('.section-header-row:not(#docChartHeader):last-of-type') ||
    $('chartDonut')?.closest('.chart-card')?.previousElementSibling;
  const donutCard    = $('chartDonut')?.closest('.chart-card');

  if (!hasData) {
    // Empty state — no feed logged yet
    drawDonutChart('chartDonut', []);
    
    // Hide DOC chart too
    $('docChartHeader').classList.add('hidden');
    $('docChartSection').classList.add('hidden');
    const summaryBox = $('batchDocProgressSummary');
    if (summaryBox) summaryBox.classList.add('hidden');
    // Populate consolidated summary card (shows batch age + growth even without feed data)
    renderBatchSummaryCard(batch);
    hideAllBatchAnalytics();
    // Still show sampling card even if no feed data
    renderBatchSamplingCard(batch);
    updateExportCount();
    return;
  }

  // Has data — show charts
  $('docChartHeader').classList.remove('hidden');
  $('docChartSection').classList.remove('hidden');

  requestAnimationFrame(() => {
    drawDonutChart('chartDonut', feedSizeDistribution(batchRecs));
    const docData = getBatchFeedDataForDOC(batch);
    const nonZeroDoc = docData.filter(d => d.value > 0);
    const startDocVal = nonZeroDoc.length ? nonZeroDoc[0].value : 0;
    const endDocVal = nonZeroDoc.length ? nonZeroDoc[nonZeroDoc.length - 1].value : 0;
    const maxDocVal = docData.reduce((max, d) => d.value > max ? d.value : max, 0);
    const maxDocObj = docData.reduce((max, d) => d.value > max.value ? d : max, { label: '', value: 0 });
    const docDesc = `Feed Progress by DOC: Starts at ${fmtGrams(startDocVal)}g, ends at ${fmtGrams(endDocVal)}g, with a maximum of ${fmtGrams(maxDocVal)}g.`;
    const docCanvas = $('chartDoc');
    if (docCanvas) {
      docCanvas.setAttribute('role', 'img');
      docCanvas.setAttribute('aria-label', docDesc);
      docCanvas._onBarClick = (bar) => showBarDetailModal({ ...bar._meta, batchName: `Batch #${batch.batchNumber}`, pond: ponds.find(p=>p.id===batch.pondId)?.name || batch.pond || 'Unknown' }, '#00d4aa');
    }
    const summaryBox = $('batchDocProgressSummary');
    if (summaryBox) {
      if (nonZeroDoc.length) {
        summaryBox.innerHTML = `DOC Summary: Feed logged across ${nonZeroDoc.length} days. Starts at ${fmtGrams(startDocVal)}g on ${docData[0].label}, ending at ${fmtGrams(endDocVal)}g on ${docData[docData.length-1].label}. Peak DOC feeding is <strong class="summary-highlight">${fmtGrams(maxDocVal)}g</strong> on <strong class="summary-highlight">${maxDocObj.label}</strong>.`;
        summaryBox.classList.remove('hidden');
      } else {
        summaryBox.classList.add('hidden');
      }
    }
    drawHorizontalBarChart('chartDoc', docData, { color: '#00d4aa' });
  });

  // ── Batch Analytics ─────────────────────────────────────
  renderBatchSummaryCard(batch);          // consolidated: doc age + feed + growth status + quick actions
  // ── Growth Tracking (embedded in batch dashboard) ────────
  renderBatchGrowthCard(batch);
  renderGrowthFeedTrendChart(batch);
  // ── Sampling (embedded in batch dashboard) ───────────────
  renderBatchSamplingCard(batch);
  // ────────────────────────────────────────────────────────

  updateExportCount();
}

function openViewBatchModal(batchId) {
  const batch = batches.find(b => b.id === batchId);
  if (!batch) return;
  viewBatchId = batchId;

  const pond     = ponds.find(p => p.id === batch.pondId);
  const doc      = calcDOC(batch.stockingDate);
  const feedCount = records.filter(r => r.BatchId === batch.id).length;

  $('viewBatchContent').innerHTML = `
    <div class="modal-title">Batch #${batch.batchNumber}</div>
    <div class="modal-pond-context">${escapeHTML(pond ? pond.name : (batch.pond || '—'))}</div>
    <div class="view-batch-stats">
      <div class="vbs-row"><span class="vbs-label">Shrimp Stocked</span><span class="vbs-val">${fmtShrimpCount(batch.shrimpCount)}</span></div>
      <div class="vbs-row"><span class="vbs-label">DOC</span><span class="vbs-val teal">${doc} days</span></div>
      <div class="vbs-row"><span class="vbs-label">Stocking Date</span><span class="vbs-val">${fmtDateDisplay(batch.stockingDate)}</span></div>
      <div class="vbs-row"><span class="vbs-label">Stocking Time</span><span class="vbs-val">${batch.stockingTime || '—'}</span></div>
      <div class="vbs-row"><span class="vbs-label">Feed Logs</span><span class="vbs-val">${feedCount}</span></div>
      ${batch.notes ? `<div class="vbs-row"><span class="vbs-label">Notes</span><span class="vbs-val" style="font-style:italic">${escapeHTML(batch.notes)}</span></div>` : ''}
      ${getBiomassVbsRowsHTML(batch)}
    </div>
    <div id="batchDfsWrap"></div>
  `;

  // Initialise the DFS date: default to the most recent valid date
  const today        = fmt(new Date());
  const maxDate      = batch.status === 'active' ? today : (batch.harvestDate || today);
  const minDate      = batch.stockingDate;
  // Default to last date with records in this batch, or maxDate
  const batchDates   = [...new Set(
    records.filter(r => r.BatchId === batch.id).map(r => r.Date)
  )].sort();
  const defaultDate  = batchDates.length ? batchDates[batchDates.length - 1] : maxDate;
  // Clamp to valid range
  const clamp = d => d < minDate ? minDate : d > maxDate ? maxDate : d;
  viewBatchDfsDate = clamp(defaultDate);

  renderBatchDailyFeedSummary(batch, minDate, maxDate);

  // Show/hide Complete button
  const completeBtn = $('viewBatchComplete');
  if (completeBtn) completeBtn.style.display = batch.status === 'active' ? '' : 'none';

  $('viewBatchModal').classList.remove('hidden');
}

function renderBatchDailyFeedSummary(batch, minDate, maxDate) {
  const wrap = $('batchDfsWrap');
  if (!wrap) return;

  const selDate = viewBatchDfsDate;

  // ── DOC for the selected date ──────────────────────────
  function calcDOCForDate(stockingDate, targetDate) {
    const stock  = startOfDay(stockingDate);
    const target = startOfDay(targetDate);
    const diff   = Math.floor((target - stock) / MS_PER_DAY);
    return diff >= 0 ? diff + 1 : 1;
  }
  const docForDate = calcDOCForDate(batch.stockingDate, selDate);

  // ── Feed records for this batch on the selected date ───
  const dateRecs   = records.filter(r => r.BatchId === batch.id && r.Date === selDate);

  // ── Issue #8: Build a responsive Feed Session Timeline ──
  // Standard feed times (matches the Log page dropdown) + any "Other" sessions.
  const STANDARD_TIMES = [
    { time: '7:00 AM',  icon: '🌅', label: 'Morning'   },
    { time: '11:00 AM', icon: '🌞', label: 'Late Morn' },
    { time: '4:00 PM',  icon: '🌇', label: 'Afternoon' },
    { time: '7:00 PM',  icon: '🌙', label: 'Evening'   }
  ];

  // Convert a time string like "7:00 AM" → minutes since midnight for sorting
  function timeToMinutes(t) {
    if (!t) return 9999;
    if (t === 'Other') return 9990;
    const pm = t.includes('PM');
    const [h, m] = (t.split(' ')[0]).split(':').map(Number);
    let h24 = h;
    if (pm && h !== 12) h24 += 12;
    if (!pm && h === 12) h24 = 0;
    return h24 * 60 + (m || 0);
  }

  // Group records by time slot — show every standard time, plus any "Other"
  const slots = STANDARD_TIMES.map(st => {
    const recs = dateRecs.filter(r => r.Time === st.time);
    const g    = sumGrams(recs);
    return { ...st, grams: g, hasData: recs.length > 0, records: recs };
  });
  // Add "Other" sessions if any exist
  const otherRecs = dateRecs.filter(r => !STANDARD_TIMES.some(st => st.time === r.Time));
  if (otherRecs.length) {
    // Group Other records by their actual time string
    const otherGroups = {};
    otherRecs.forEach(r => {
      const k = r.Time || 'Other';
      if (!otherGroups[k]) otherGroups[k] = [];
      otherGroups[k].push(r);
    });
    Object.entries(otherGroups).forEach(([time, recs]) => {
      const g = sumGrams(recs);
      slots.push({ time, icon: '🍤', label: time === 'Other' ? 'Custom' : time, grams: g, hasData: true, records: recs });
    });
  }

  const totalG = dateRecs.length ? sumGrams(dateRecs) : 0;

  // ── Navigation bounds ──────────────────────────────────
  const canPrev = selDate > minDate;
  const canNext = selDate < maxDate;

  // ── Human-readable date display ────────────────────────
  const dateObj     = startOfDay(selDate);
  const displayDate = dateObj.toLocaleDateString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric'
  });

  // ── Session history rows (sorted by time) ──────────────
  function sessionRows() {
    if (!dateRecs.length) return '';
    return dateRecs.slice().sort((a, b) => timeToMinutes(a.Time) - timeToMinutes(b.Time)).map(r => {
      const g     = sumGrams([r]);
      const feeds = feedSummaryStr(r);
      return `<div class="bdfs-session">
        <div class="bdfs-session-time">${r.Time || '—'}</div>
        <div class="bdfs-session-right">
          <div class="bdfs-session-total">${fmtGrams(g)} g</div>
          <div class="bdfs-session-feeds">${feeds}</div>
        </div>
      </div>`;
    }).join('');
  }

  // ── Timeline slot card (replaces Morning/Evening cards) ─
  function timelineSlot(slot) {
    const has  = slot.grams > 0;
    const val  = has ? fmtGrams(slot.grams) : '—';
    const unit = has ? 'g' : '';
    return `<div class="bdfs-slot${has ? ' has-data' : ''}">
      <span class="bdfs-slot-icon">${slot.icon}</span>
      <span class="bdfs-slot-lbl">${escapeHTML(slot.label)}</span>
      <span class="bdfs-slot-time">${escapeHTML(slot.time)}</span>
      <span class="bdfs-slot-val">${val}<span class="bdfs-slot-unit">${unit}</span></span>
    </div>`;
  }

  wrap.innerHTML = `
    <!-- Section divider -->
    <div class="bdfs-divider"></div>

    <!-- Section header -->
    <div class="bdfs-header">
      <span class="bdfs-header-title">Daily Feed Summary</span>
      <span class="bdfs-doc-badge">DOC ${docForDate}</span>
    </div>

    <!-- Date navigator -->
    <div class="bdfs-nav">
      <button class="bdfs-arrow" id="bdfsPrev" aria-label="Previous day"${canPrev ? '' : ' disabled'}>&#9664;</button>
      <div class="bdfs-date-display" id="bdfsDateDisplay">
        <span class="bdfs-date-text">${displayDate}</span>
        <input type="date" class="bdfs-date-input" id="bdfsDateInput"
               value="${selDate}" min="${minDate}" max="${maxDate}"
               aria-label="Pick a date">
      </div>
      <button class="bdfs-arrow" id="bdfsNext" aria-label="Next day"${canNext ? '' : ' disabled'}>&#9654;</button>
    </div>

    <!-- Daily Summary stats (Total Feed + Sessions + Breakdown) -->
    <div class="bdfs-stats-grid">
      <div class="bdfs-stat-card bdfs-stat-total">
        <div class="bdfs-stat-lbl">Total Feed</div>
        <div class="bdfs-stat-val">${totalG > 0 ? fmtGrams(totalG) : '—'}<span class="bdfs-stat-unit">${totalG > 0 ? 'g' : ''}</span></div>
      </div>
      <div class="bdfs-stat-card">
        <div class="bdfs-stat-lbl">Sessions</div>
        <div class="bdfs-stat-val">${dateRecs.length}</div>
      </div>
      <div class="bdfs-stat-card">
        <div class="bdfs-stat-lbl">Avg / Session</div>
        <div class="bdfs-stat-val">${dateRecs.length ? fmtGrams(Math.round(totalG / dateRecs.length)) : '—'}<span class="bdfs-stat-unit">${dateRecs.length ? 'g' : ''}</span></div>
      </div>
    </div>

    <!-- Feed Session Timeline (all feed times, not just Morning/Evening) -->
    <div class="bdfs-timeline-section">
      <div class="bdfs-timeline-label">Feed Session Timeline</div>
      <div class="bdfs-timeline">
        ${slots.map(timelineSlot).join('')}
      </div>
    </div>

    <!-- Session history -->
    <div class="bdfs-sessions-section">
      <div class="bdfs-sessions-label">
        Feed Sessions
        <span class="bdfs-sessions-count">${dateRecs.length} session${dateRecs.length !== 1 ? 's' : ''}</span>
      </div>
      ${dateRecs.length
        ? `<div class="bdfs-session-list">${sessionRows()}</div>`
        : `<div class="bdfs-empty">
             <span class="bdfs-empty-icon">📋</span>
             <span class="bdfs-empty-text">No Records Available</span>
             <span class="bdfs-empty-sub">${displayDate}</span>
           </div>`
      }
    </div>
  `;

  // ── Wire navigation ────────────────────────────────────
  function goTo(dateStr) {
    viewBatchDfsDate = dateStr;
    renderBatchDailyFeedSummary(batch, minDate, maxDate);
  }

  $('bdfsPrev')?.addEventListener('click', () => {
    if (!canPrev) return;
    const d = startOfDay(selDate);
    d.setDate(d.getDate() - 1);
    goTo(fmt(d));
  });
  $('bdfsNext')?.addEventListener('click', () => {
    if (!canNext) return;
    const d = startOfDay(selDate);
    d.setDate(d.getDate() + 1);
    goTo(fmt(d));
  });
  $('bdfsDateInput')?.addEventListener('change', function () {
    if (this.value) goTo(this.value);
  });
  $('bdfsDateDisplay')?.addEventListener('click', e => {
    if (!e.isTrusted) return;
    const inp = $('bdfsDateInput');
    if (inp) { try { inp.showPicker(); } catch { inp.click(); } }
  });
}

function getActiveBatchForPond(pondId) {
  return batches.find(b => b.pondId === pondId && b.status === 'active') || null;
}

function getNextBatchNumber(pondId) {
  const pondBatches = batches.filter(b => b.pondId === pondId);
  if (!pondBatches.length) return 1;
  return Math.max(...pondBatches.map(b => b.batchNumber)) + 1;
}

function saveBatches() {
  AppStorage.saveBatches(batches);
}

function saveHapaEntries() {
  AppStorage.saveHapa(hapaEntries);
}

function getHapaForBatch(batchId) {
  return hapaEntries.find(h => h.batchId === batchId) || null;
}

function batchNeedsHapa(batch) {
  if (batch.status !== 'active') return false;
  const doc = calcDOC(batch.stockingDate);
  return doc >= 10 && !getHapaForBatch(batch.id);
}

function hapaReminderCount() {
  return batches.filter(batchNeedsHapa).length;
}

function openHapaEntryModal(batchId) {
  const batch = batches.find(b => b.id === batchId);
  if (!batch) return;
  hapaEntryBatchId = batchId;

  const pond = ponds.find(p => p.id === batch.pondId);
  const pondName = pond ? pond.name : (batch.pond || 'Pond');

  $('hapaModalTitle').textContent = 'Hapa Check';
  $('hapaModalContext').textContent = `${pondName} · Batch #${batch.batchNumber}`;

  // Date default today
  $('hapaDate').value = fmt(new Date());
  // Hapa Stocked from batch (read-only display)
  $('hapaStockedDisplay').textContent = Number(batch.hapaStocked || 100).toLocaleString();
  // Clear alive input
  $('hapaAliveInput').value = '';
  $('hapaSurvivalPreview').classList.add('hidden');
  $('hapaSurvivalValue').textContent = '—';
  $('hapaNotesInput').value = '';

  // Clear errors
  clearFieldError('errHapaDate', 'hapaDate', 'Required');
  clearFieldError('errHapaAlive', 'hapaAliveInput', 'Enter a valid count');

  $('hapaEntryModal').classList.remove('hidden');
  setTimeout(() => $('hapaAliveInput').focus(), 100);
}

function doSaveHapa() {
  if (!hapaEntryBatchId) return;
  const batch = batches.find(b => b.id === hapaEntryBatchId);
  if (!batch) return;

  const dateVal  = $('hapaDate').value;
  const aliveVal = $('hapaAliveInput').value;

  clearFieldError('errHapaDate',  'hapaDate',        'Required');
  clearFieldError('errHapaAlive', 'hapaAliveInput',   'Enter a valid count');

  let ok = true;
  if (!dateVal) {
    showFieldError('errHapaDate', 'hapaDate', 'Required');
    ok = false;
  }
  const aliveNum = numberFromField(aliveVal);
  const stocked = Number(batch.hapaStocked || 100);
  if (aliveNum === null || aliveNum < 0) {
    showFieldError('errHapaAlive', 'hapaAliveInput', 'Enter a valid count (0 or more)');
    ok = false;
  } else if (aliveNum > stocked) {
    showFieldError('errHapaAlive', 'hapaAliveInput', `Cannot exceed stocked count (${stocked})`);
    ok = false;
  }
  if (!ok) return;

  const survivalPct = stocked > 0 ? Math.round((aliveNum / stocked) * 1000) / 10 : null;

  const entry = {
    id: `hapa_${Date.now()}`,
    batchId: hapaEntryBatchId,
    hapaDate: dateVal,
    hapaStocked: stocked,
    hapaAlive: aliveNum,
    survivalPercent: survivalPct,
    notes: $('hapaNotesInput').value.trim(),
    recordedAt: new Date().toISOString(),
  };

  // Remove any existing entry for this batch (only one allowed)
  state.setHapaEntries(state.hapaEntries.filter(h => h.batchId !== hapaEntryBatchId));
  hapaEntries.push(entry);
  saveHapaEntries();

  closeModal('hapaEntryModal');
  hapaEntryBatchId = null;

  renderDashboard();
  renderManagePage();
  const survMsg = survivalPct !== null ? ` · Survival: ${survivalPct}%` : '';
  showToast('✅', 'Hapa Recorded', `${batch.pond || 'Batch'} #${batch.batchNumber}${survMsg}`);
}

function getHapaBadgeHTML(batchId, doc) {
  const hapa = getHapaForBatch(batchId);
  if (hapa) {
    return `<span class="hapa-badge hapa-badge--done">🟢 Hapa Completed</span>`;
  }
  if (doc >= 10) {
    return `<span class="hapa-badge hapa-badge--pending">🟡 Hapa Pending</span>`;
  }
  return ''; // DOC < 10, no badge shown yet
}

function validateBatchCreateData(shrimpCount, stockingDate, stockingTime) {
  const errors = {};
  if (!isPositiveNumberField(shrimpCount)) errors.shrimpCount = 'Enter a valid shrimp count';
  if (!stockingDate) errors.stockingDate = 'Required';
  else if (isFutureDateStr(stockingDate)) errors.stockingDate = 'Stocking date cannot be in the future.';
  if (!stockingTime) errors.stockingTime = 'Required';
  return { ok: Object.keys(errors).length === 0, errors };
}

function validateBatchCompletionData(batch, harvestDate, harvestTime, finalShrimpCount, harvestWeightKg) {
  const errors = {};
  const finalCountNum = numberFromField(finalShrimpCount);
  const harvestWeightNum = numberFromField(harvestWeightKg);
  const stockedCount = Number(batch?.shrimpCount);

  if (!harvestDate) {
    errors.harvestDate = 'Required';
  }
  if (!harvestTime) {
    errors.harvestTime = 'Required';
  }

  if (harvestDate && harvestTime && batch?.stockingDate && batch?.stockingTime) {
    const stockingDateTime = new Date(`${batch.stockingDate}T${batch.stockingTime}`);
    const harvestDateTime = new Date(`${harvestDate}T${harvestTime}`);
    if (harvestDateTime < stockingDateTime) {
      errors.harvestDate = 'Harvest date and time cannot be earlier than stocking date and time.';
    }
  } else if (harvestDate && batch?.stockingDate && isBeforeDateStr(harvestDate, batch.stockingDate)) {
    errors.harvestDate = 'Harvest date cannot be earlier than stocking date.';
  }

  if (finalCountNum === null || finalCountNum < 0) {
    errors.finalShrimpCount = 'Enter a valid count';
  } else if (Number.isFinite(stockedCount) && finalCountNum > stockedCount) {
    errors.finalShrimpCount = 'Final shrimp count cannot exceed stocked shrimp count.';
  }

  if (harvestWeightNum === null || harvestWeightNum < 0) {
    errors.harvestWeightKg = 'Enter a valid weight';
  }

  return { ok: Object.keys(errors).length === 0, errors };
}

function findBatchForDate(pondId, feedDateStr) {
  if (!pondId || !feedDateStr) return null;
  if (!isIsoDateStr(feedDateStr)) return null;

  const today = todayStr();
  const pondBatches = batches
    .filter(b => b.pondId === pondId && isIsoDateStr(b.stockingDate))
    .slice()
    // L3 fix: add secondary sort key (createdAt) and prefer active over completed for equal stocking dates
    .sort((a, b) => {
      const dateCmp = a.stockingDate.localeCompare(b.stockingDate);
      if (dateCmp !== 0) return dateCmp;
      // Prefer active batches over completed ones when stocking dates are equal
      if (a.status === 'active' && b.status !== 'active') return 1;
      if (b.status === 'active' && a.status !== 'active') return -1;
      // Final tiebreaker: createdAt
      return (a.createdAt || '').localeCompare(b.createdAt || '');
    });

  const matches = [];
  for (const b of pondBatches) {
    if (feedDateStr < b.stockingDate) continue;

    if (b.status === 'active') {
      // Active batch: feed date must be from stocking date through today.
      if (feedDateStr <= today) matches.push(b);
    } else if (b.status === 'completed') {
      // Completed batch: feed date must be between stocking date and harvest date (inclusive).
      // Keep completedAt fallback for legacy completed batches that predate harvestDate.
      const completionDateStr = b.harvestDate || (b.completedAt ? b.completedAt.split('T')[0] : null);
      if (isIsoDateStr(completionDateStr) && feedDateStr <= completionDateStr) matches.push(b);
    }
  }

  return matches.length ? matches[matches.length - 1] : null;
}

function openCreateBatchModal(pondId) {
  createBatchForPondId = pondId;
  const pond = ponds.find(p => p.id === pondId);

  $('createBatchModalTitle').textContent = 'Create Batch';
  $('createBatchPondContext').textContent = pond ? `${pond.name} · ${pond.site}` : '';

  // Set defaults
  const now = new Date();
  const today = fmt(now);
  $('modalBatchStockDate').value = today;
  $('modalBatchStockDate').max = today;
  const hh = String(now.getHours()).padStart(2,'0');
  const mi = String(now.getMinutes()).padStart(2,'0');
  $('modalBatchStockTime').value = `${hh}:${mi}`;
  $('modalBatchShrimpCount').value = '';
  $('modalBatchNotes').value = '';
  $('modalHapaStocked').value = '100';

  // Clear errors
  clearFieldError('errModalBatchShrimp', 'modalBatchShrimpCount', 'Enter a valid shrimp count');
  clearFieldError('errModalBatchDate', 'modalBatchStockDate', 'Required');
  clearFieldError('errModalBatchTime', 'modalBatchStockTime', 'Required');

  $('createBatchModal').classList.remove('hidden');
  setTimeout(() => $('modalBatchShrimpCount').focus(), 100);
}

function doCreateBatch() {
  const count = $('modalBatchShrimpCount').value;
  const date  = $('modalBatchStockDate').value;
  const time  = $('modalBatchStockTime').value;

  const validation = validateBatchCreateData(count, date, time);
  clearFieldError('errModalBatchShrimp', 'modalBatchShrimpCount', 'Enter a valid shrimp count');
  clearFieldError('errModalBatchDate', 'modalBatchStockDate', 'Required');
  clearFieldError('errModalBatchTime', 'modalBatchStockTime', 'Required');
  if (validation.errors.shrimpCount) showFieldError('errModalBatchShrimp', 'modalBatchShrimpCount', validation.errors.shrimpCount);
  if (validation.errors.stockingDate) showFieldError('errModalBatchDate', 'modalBatchStockDate', validation.errors.stockingDate);
  if (validation.errors.stockingTime) showFieldError('errModalBatchTime', 'modalBatchStockTime', validation.errors.stockingTime);
  if (!validation.ok) return;

  const pondId = createBatchForPondId;
  if (!pondId) return;

  const existing = getActiveBatchForPond(pondId);
  if (existing) {
    showToast('⚠️', 'Active Batch Exists', 'Complete the current batch first.');
    return;
  }

  const pond = ponds.find(p => p.id === pondId);
  const batchNum = getNextBatchNumber(pondId);
  const id = `batch_${Date.now()}`;

  const batch = {
    id,
    pondId,
    pond: pond ? pond.name : pondId,  // kept for legacy display fallback
    batchNumber: batchNum,
    shrimpCount: numberFromField(count),
    stockingDate: date,
    stockingTime: time,
    notes: $('modalBatchNotes').value.trim(),
    hapaStocked: numberFromField($('modalHapaStocked').value) || 100,
    status: 'active',
    createdAt: new Date().toISOString(),
    completedAt: null,
  };

  batches.push(batch);
  saveBatches();

  closeModal('createBatchModal');
  createBatchForPondId = null;

  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  showToast('✅', 'Batch Created!', `${pond ? pond.name : ''} Batch #${batchNum} is now active`);
}

function openCompleteBatchModal(batchId) {
  const batch = batches.find(b => b.id === batchId);
  if (!batch) return;
  batchToComplete = batchId;

  const pond = ponds.find(p => p.id === batch.pondId);
  const pondName = pond ? pond.name : (batch.pond || 'Pond');
  const siteName = pond ? (pond.site || 'No site') : 'No site';

  $('completeBatchTitle').textContent = `Complete Batch #${batch.batchNumber}`;
  $('completeBatchDesc').textContent  = `${pondName} · Stocked: ${fmtShrimpCount(batch.shrimpCount)} shrimp`;

  // ── 1. Pond & Batch Summary Card ──
  const doc = calcDOC(batch.stockingDate);
  const batchRecs = records.filter(r => r.BatchId === batch.id);
  const totalFeedG = sumGrams(batchRecs);
  const totalFeedKg = totalFeedG / 1000;
  const stockedCount = Number(batch.shrimpCount) || 0;

  // Latest ABW from sampling
  let latestABW = null;
  if (window.sampling && Array.isArray(window.sampling)) {
    const s = window.sampling.filter(x => x.batchId === batch.id).slice(-1)[0];
    if (s && s.abw) latestABW = Number(s.abw);
  } else if (batch.latestABW) {
    latestABW = Number(batch.latestABW);
  }
  const abwStr = latestABW ? latestABW.toFixed(1) + ' g' : '—';

  // Estimated biomass (current population × ABW)
  let estBiomassKg = '—';
  if (latestABW && stockedCount) {
    // Use sampling-derived survival if available, else assume 100%
    const survivalSoFar = (batch.survivalRate != null) ? Number(batch.survivalRate) / 100 : 1;
    const estPop = Math.round(stockedCount * survivalSoFar);
    const est = (estPop * latestABW) / 1000;
    estBiomassKg = est.toFixed(1) + ' kg';
  }

  // FCR (estimated, based on biomass)
  let fcrStr = '—';
  if (totalFeedKg > 0 && latestABW && stockedCount) {
    const survivalSoFar = (batch.survivalRate != null) ? Number(batch.survivalRate) / 100 : 1;
    const estBiomassNum = (stockedCount * survivalSoFar * latestABW) / 1000;
    if (estBiomassNum > 0) fcrStr = (totalFeedKg / estBiomassNum).toFixed(2);
  }

  // Latest water quality status
  let wqStatus = '—';
  if (window.al_water_quality && Array.isArray(window.al_water_quality)) {
    const wq = window.al_water_quality.filter(x => x.pondId === batch.pondId).slice(-1)[0];
    if (wq) {
      // Crude check — if any param is out of range, mark as Warning/Critical
      const ph = parseFloat(wq.pH);
      const doxy = parseFloat(wq.dissolvedOxygen || wq.do);
      if (!isNaN(ph) && (ph < 6.5 || ph > 9.5)) wqStatus = '⚠️ Warning';
      else if (!isNaN(doxy) && doxy < 3) wqStatus = '🚨 Critical';
      else wqStatus = '✅ Good';
    }
  }

  const summaryGrid = $('cbSummaryGrid');
  if (summaryGrid) {
    summaryGrid.innerHTML = `
      <div class="cb-sum-item"><div class="cb-sum-lbl">Pond</div><div class="cb-sum-val">${escapeHTML(pondName)}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Site</div><div class="cb-sum-val">${escapeHTML(siteName)}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Batch #</div><div class="cb-sum-val teal">${batch.batchNumber}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">DOC</div><div class="cb-sum-val">${doc} days</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Stocking Date</div><div class="cb-sum-val">${fmtDateDisplay(batch.stockingDate)}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Stocked Count</div><div class="cb-sum-val">${fmtShrimpCount(batch.shrimpCount)}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Current Survival</div><div class="cb-sum-val">${batch.survivalRate != null ? Number(batch.survivalRate).toFixed(0) + '%' : '—'}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Latest ABW</div><div class="cb-sum-val teal">${abwStr}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Est. Biomass</div><div class="cb-sum-val">${estBiomassKg}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Total Feed</div><div class="cb-sum-val">${totalFeedKg.toFixed(2)} kg</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">FCR (est.)</div><div class="cb-sum-val">${fcrStr}</div></div>
      <div class="cb-sum-item"><div class="cb-sum-lbl">Water Quality</div><div class="cb-sum-val">${wqStatus}</div></div>
    `;
  }

  // ── 2. Harvest Summary (calculated values displayed before completion) ──
  const harvestSummaryGrid = $('cbHarvestSummaryGrid');
  if (harvestSummaryGrid) {
    const estPop = (batch.survivalRate != null && stockedCount)
      ? Math.round(stockedCount * (Number(batch.survivalRate) / 100))
      : stockedCount;
    const estHarvestWt = latestABW
      ? ((estPop * latestABW) / 1000).toFixed(1) + ' kg'
      : '—';
    const estFCR = (totalFeedKg > 0 && latestABW && estPop)
      ? (totalFeedKg / ((estPop * latestABW) / 1000)).toFixed(2)
      : '—';

    harvestSummaryGrid.innerHTML = `
      <div class="cb-hs-item"><div class="cb-hs-lbl">Days Cultured</div><div class="cb-hs-val">${doc}</div></div>
      <div class="cb-hs-item"><div class="cb-hs-lbl">Initial Stock</div><div class="cb-hs-val">${fmtShrimpCount(batch.shrimpCount)}</div></div>
      <div class="cb-hs-item"><div class="cb-hs-lbl">Est. Population</div><div class="cb-hs-val">${estPop.toLocaleString()}</div></div>
      <div class="cb-hs-item"><div class="cb-hs-lbl">Total Feed Used</div><div class="cb-hs-val">${totalFeedKg.toFixed(2)} kg</div></div>
      <div class="cb-hs-item"><div class="cb-hs-lbl">Latest Sample Wt</div><div class="cb-hs-val">${abwStr}</div></div>
      <div class="cb-hs-item"><div class="cb-hs-lbl">Est. Harvest Wt</div><div class="cb-hs-val teal">${estHarvestWt}</div></div>
      <div class="cb-hs-item"><div class="cb-hs-lbl">Est. FCR</div><div class="cb-hs-val">${estFCR}</div></div>
    `;
  }

  // ── 3. Pre-fill input fields ──
  const now = new Date();
  $('harvestDate').value = fmt(now);
  $('harvestDate').min = batch.stockingDate || '';
  const hh = String(now.getHours()).padStart(2,'0');
  const mi = String(now.getMinutes()).padStart(2,'0');
  $('harvestTime').value = `${hh}:${mi}`;
  $('finalShrimpCount').value = '';
  $('finalShrimpCount').max = String(batch.shrimpCount);
  $('harvestWeightKg').value = '';
  $('completionNotes').value = '';
  // New optional fields
  if ($('harvestPricePerKg')) $('harvestPricePerKg').value = '';
  if ($('harvestBuyer'))      $('harvestBuyer').value = '';
  if ($('harvestMethod'))     $('harvestMethod').value = '';
  if ($('harvestGrade'))      $('harvestGrade').value = '';

  // Clear errors
  clearFieldError('errHarvestDate', 'harvestDate', 'Required');
  clearFieldError('errHarvestTime', 'harvestTime', 'Required');
  clearFieldError('errFinalShrimpCount', 'finalShrimpCount', 'Enter a valid count');
  clearFieldError('errHarvestWeight', 'harvestWeightKg', 'Enter a valid weight');

  // ── 4. Auto Calculations: live update on input ──
  const calcLive = () => {
    const countStr = $('finalShrimpCount').value;
    const wtStr = $('harvestWeightKg').value;
    const priceStr = $('harvestPricePerKg') ? $('harvestPricePerKg').value : '';
    const countNum = countStr ? parseInt(countStr, 10) : null;
    const wtNum = wtStr ? parseFloat(wtStr) : null;
    const priceNum = priceStr ? parseFloat(priceStr) : null;

    // Final Survival %
    const survivalPct = (countNum && stockedCount > 0)
      ? ((countNum / stockedCount) * 100).toFixed(1) + '%'
      : '—';

    // Final Biomass (kg)
    const biomass = (wtNum != null && !isNaN(wtNum)) ? wtNum.toFixed(2) + ' kg' : '—';

    // Harvest Yield: kg per area
    let yieldStr = '—';
    if (wtNum != null && pond && pond.sizeSqFt > 0) {
      const acres = pond.sizeSqFt / 43560; // 1 acre = 43,560 sqft
      if (acres > 0) yieldStr = (wtNum / acres).toFixed(1) + ' kg/acre';
    }

    // Actual FCR
    let actualFCR = '—';
    if (wtNum != null && wtNum > 0 && totalFeedKg > 0) {
      actualFCR = (totalFeedKg / wtNum).toFixed(2);
    }

    // Revenue
    let revenue = '—';
    if (wtNum != null && priceNum != null) {
      revenue = '₹' + (wtNum * priceNum).toLocaleString(undefined, { maximumFractionDigits: 0 });
    }

    // Profit/Loss (basic — only if revenue and a feed cost estimate exist)
    let pl = '—';
    if (wtNum != null && priceNum != null) {
      const revenueNum = wtNum * priceNum;
      // Feed cost: assume ₹60/kg feed as default if no finance data
      const feedCostNum = totalFeedKg * 60;
      const profitNum = revenueNum - feedCostNum;
      const sign = profitNum >= 0 ? '+' : '-';
      const absVal = Math.abs(profitNum).toLocaleString(undefined, { maximumFractionDigits: 0 });
      pl = `${sign} ₹${absVal}`;
    }

    const calcGrid = $('cbCalcGrid');
    if (calcGrid) {
      calcGrid.innerHTML = `
        <div class="cb-calc-item"><div class="cb-calc-lbl">Final Survival</div><div class="cb-calc-val teal">${survivalPct}</div></div>
        <div class="cb-calc-item"><div class="cb-calc-lbl">Final Biomass</div><div class="cb-calc-val">${biomass}</div></div>
        <div class="cb-calc-item"><div class="cb-calc-lbl">Harvest Yield</div><div class="cb-calc-val">${yieldStr}</div></div>
        <div class="cb-calc-item"><div class="cb-calc-lbl">Actual FCR</div><div class="cb-calc-val">${actualFCR}</div></div>
        <div class="cb-calc-item"><div class="cb-calc-lbl">Revenue</div><div class="cb-calc-val teal">${revenue}</div></div>
        <div class="cb-calc-item"><div class="cb-calc-lbl">Est. P/L</div><div class="cb-calc-val">${pl}</div></div>
      `;
    }
  };

  $('finalShrimpCount').oninput = calcLive;
  $('harvestWeightKg').oninput = calcLive;
  if ($('harvestPricePerKg')) $('harvestPricePerKg').oninput = calcLive;
  calcLive(); // initial render

  // ── Optional section toggle ──
  const optToggle = $('cbOptionalToggle');
  const optSection = $('cbOptionalSection');
  if (optToggle && optSection) {
    optToggle.onclick = () => {
      const isOpen = optSection.classList.toggle('open');
      optSection.classList.toggle('hidden', !isOpen);
      optToggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
      const arrow = optToggle.querySelector('.cb-ot-arrow');
      if (arrow) arrow.style.transform = isOpen ? 'rotate(180deg)' : '';
      const txt = optToggle.querySelector('.cb-ot-text');
      if (txt) txt.textContent = isOpen ? '－ Hide Optional Details' : '＋ Optional Details';
    };
  }

  $('completeBatchModal').classList.remove('hidden');

  // Close view modal if open
  closeModal('viewBatchModal');
}

function doCompleteBatch() {
  if (!batchToComplete) return;
  const batch = batches.find(b => b.id === batchToComplete);
  if (!batch) return;

  const harvestDate = $('harvestDate').value;
  const harvestTime = $('harvestTime').value;
  const finalCount = $('finalShrimpCount').value;   // may be empty (Unknown)
  const harvestWt = $('harvestWeightKg').value;

  // Validate — finalCount is optional in the new design (user can mark Unknown)
  // We'll temporarily relax the validator by passing a 0 if blank,
  // then re-check after validation that at least the weight is present.
  const isCountUnknown = !finalCount || finalCount.trim() === '';
  const finalCountForValidation = isCountUnknown ? '0' : finalCount;

  const validation = validateBatchCompletionData(batch, harvestDate, harvestTime, finalCountForValidation, harvestWt);
  clearFieldError('errHarvestDate', 'harvestDate', 'Required');
  clearFieldError('errHarvestTime', 'harvestTime', 'Required');
  clearFieldError('errFinalShrimpCount', 'finalShrimpCount', 'Enter a valid count');
  clearFieldError('errHarvestWeight', 'harvestWeightKg', 'Enter a valid weight');
  if (validation.errors.harvestDate) showFieldError('errHarvestDate', 'harvestDate', validation.errors.harvestDate);
  if (validation.errors.harvestTime) showFieldError('errHarvestTime', 'harvestTime', validation.errors.harvestTime);
  if (!isCountUnknown && validation.errors.finalShrimpCount) showFieldError('errFinalShrimpCount', 'finalShrimpCount', validation.errors.finalShrimpCount);
  if (validation.errors.harvestWeightKg) showFieldError('errHarvestWeight', 'harvestWeightKg', validation.errors.harvestWeightKg);
  if (!validation.ok && (!isCountUnknown || validation.errors.harvestDate || validation.errors.harvestTime || validation.errors.harvestWeightKg)) {
    if (!validation.ok) return;
  }

  const finalCountNum = isCountUnknown ? null : numberFromField(finalCount);
  const harvestWeightNum = numberFromField(harvestWt);
  const stockedCount = Number(batch.shrimpCount);
  const survivalPct = (finalCountNum !== null && stockedCount > 0)
    ? Math.round((finalCountNum / stockedCount) * 1000) / 10
    : null;

  // ── Persist all harvest details ──
  batch.status            = 'completed';
  batch.completedAt       = new Date().toISOString();
  batch.harvestDate       = harvestDate;
  batch.harvestTime       = harvestTime;
  batch.finalShrimpCount  = finalCountNum;   // null if Unknown
  batch.harvestWeightKg   = harvestWeightNum;
  batch.completionNotes   = $('completionNotes').value.trim();
  batch.survivalPercent   = survivalPct;
  // New optional fields
  const pricePerKg = $('harvestPricePerKg') ? $('harvestPricePerKg').value : '';
  batch.harvestPricePerKg = pricePerKg ? parseFloat(pricePerKg) : null;
  batch.harvestBuyer      = $('harvestBuyer') ? $('harvestBuyer').value.trim() : '';
  batch.harvestMethod     = $('harvestMethod') ? $('harvestMethod').value : '';
  batch.harvestGrade      = $('harvestGrade') ? $('harvestGrade').value : '';
  // Auto-calculated
  batch.actualFCR = (harvestWeightNum && harvestWeightNum > 0)
    ? (sumGrams(records.filter(r => r.BatchId === batch.id)) / 1000 / harvestWeightNum)
    : null;
  batch.harvestRevenue = (pricePerKg && harvestWeightNum)
    ? parseFloat(pricePerKg) * harvestWeightNum
    : null;

  saveBatches();

  const pond = ponds.find(p => p.id === batch.pondId);
  const pondName = pond ? pond.name : (batch.pond || 'Pond');

  batchToComplete = null;
  closeModal('completeBatchModal');

  renderManagePage();
  renderDashboard();
  renderLogPondSelect();
  const survMsg = survivalPct !== null ? ` · Survival: ${survivalPct}%` : '';
  showToast('✅', 'Harvest Recorded', `${pondName} Batch #${batch.batchNumber} completed${survMsg}`);
}

function renderCompletedBatches() {
  const container = $('completedBatchesList');
  if (!container) return;
  const completed = batches.filter(b => b.status === 'completed').slice().reverse();

  if (!completed.length) {
    container.innerHTML = `<div class="batch-empty">
      <div class="batch-empty-icon">📋</div>
      <div class="batch-empty-text">No Records Available</div>
      <div class="batch-empty-sub">Completed batches will appear here</div>
    </div>`;
    return;
  }

  container.innerHTML = '';
  completed.forEach(batch => {
    const feedCount = records.filter(r => r.BatchId === batch.id).length;
    const pond = ponds.find(p => p.id === batch.pondId);
    const pondName = pond ? pond.name : (batch.pond || '—');

    const harvestDateDisplay = batch.harvestDate ? fmtDateDisplay(batch.harvestDate) : '—';
    const finalCountDisplay  = (batch.finalShrimpCount !== undefined && batch.finalShrimpCount !== null)
      ? fmtShrimpCount(batch.finalShrimpCount) : '—';
    const survivalDisplay    = (batch.survivalPercent !== undefined && batch.survivalPercent !== null)
      ? `${batch.survivalPercent}%` : '—';
    const weightDisplay      = (batch.harvestWeightKg !== undefined && batch.harvestWeightKg !== null)
      ? `${batch.harvestWeightKg} kg` : '—';

    // Calculate final DOC and total feed
    const finalDoc = getBatchCycleLength(batch);
    const totalFeedGrams = getBatchTotalFeed(batch);
    const totalFeedDisplay = formatTotalFeed(totalFeedGrams);

    // Final recorded growth weight for this completed batch
    const batchGrowthEntries = growthEntries
      .filter(e => e.batchId === batch.id)
      .slice()
      .sort((a, b) => a.doc - b.doc);
    const lastGrowth = batchGrowthEntries.length ? batchGrowthEntries[batchGrowthEntries.length - 1] : null;
    const finalWeightVal = lastGrowth ? fmtWeightG(lastGrowth.weightGrams) : '—';

    // Session state restoration
    const isExpanded = sessionStorage.getItem(`aqualog_completed_expanded_${batch.id}`) === 'true';

    const card = document.createElement('div');
    card.className = 'completed-batch-card';
    card.style.cursor = 'pointer';
    card.style.userSelect = 'none';
    card.setAttribute('tabindex', '0');
    card.setAttribute('role', 'button');
    card.setAttribute('aria-expanded', isExpanded ? 'true' : 'false');
    card.setAttribute('aria-label', `Completed Batch for ${pondName}`);
    card.innerHTML = `
      <div class="cbc-header-row" style="display:flex; justify-content:space-between; align-items:center;">
        <div class="cbc-pond">${escapeHTML(pondName)} <span style="font-size:0.75rem;opacity:0.7;font-weight:normal;">Batch #${batch.batchNumber}</span></div>
        <div style="display:flex; align-items:center; gap:8px;">
          <div class="cbc-status-badge">COMPLETED</div>
          <div class="cbc-details-indicator">${isExpanded ? '⌃' : '⌄'}</div>
        </div>
      </div>
      <div class="cbc-primary-stats">
        <div class="cbc-stat-item">
          <div class="cbc-stat-lbl">Final DOC</div>
          <div class="cbc-stat-val">${finalDoc}</div>
        </div>
        <div class="cbc-stat-item">
          <div class="cbc-stat-lbl">Total Feed</div>
          <div class="cbc-stat-val">${totalFeedDisplay}</div>
        </div>
        <div class="cbc-stat-item">
          <div class="cbc-stat-lbl">Final Weight</div>
          <div class="cbc-stat-val">${finalWeightVal}</div>
        </div>
      </div>

      <!-- Expandable Details Content -->
      <div class="cbc-details-content ${isExpanded ? '' : 'collapsed'}" id="cbcDetailsContent_${batch.id}">
        <div class="cbc-details-inner">
          <div class="cbc-details-grid">
            <div class="cbc-detail-item">
              <span class="cbc-detail-lbl">Stock Date</span>
              <span class="cbc-detail-val">${fmtDateDisplay(batch.stockingDate)}</span>
            </div>
            <div class="cbc-detail-item">
              <span class="cbc-detail-lbl">Stocked Shrimp</span>
              <span class="cbc-detail-val">${fmtShrimpCount(batch.shrimpCount)}</span>
            </div>
            <div class="cbc-detail-item">
              <span class="cbc-detail-lbl">Harvest Date</span>
              <span class="cbc-detail-val">${harvestDateDisplay}</span>
            </div>
            <div class="cbc-detail-item">
              <span class="cbc-detail-lbl">Harvest Count</span>
              <span class="cbc-detail-val">${finalCountDisplay}</span>
            </div>
            <div class="cbc-detail-item">
              <span class="cbc-detail-lbl">Survival Rate</span>
              <span class="cbc-detail-val">${survivalDisplay}</span>
            </div>
            <div class="cbc-detail-item">
              <span class="cbc-detail-lbl">Harvest Weight</span>
              <span class="cbc-detail-val">${weightDisplay}</span>
            </div>
            <div class="cbc-detail-item" style="grid-column: span 2;">
              <span class="cbc-detail-lbl">Data Summary</span>
              <span class="cbc-detail-val">${feedCount} feed log${feedCount !== 1 ? 's' : ''} logged</span>
            </div>
            ${batch.completionNotes ? `
            <div class="cbc-detail-item" style="grid-column: span 2;">
              <span class="cbc-detail-lbl">Notes</span>
              <span class="cbc-detail-val" style="font-style:italic;font-size:0.75rem;color:var(--t3);">${batch.completionNotes}</span>
            </div>` : ''}
          </div>
        </div>
      </div>

      <div style="margin-top:10px;">
        <button class="pond-action-btn view-batch-btn cbc-view-btn" data-batchid="${batch.id}" style="width:100%;text-align:center;">View / Edit Batch</button>
      </div>
    `;
    container.appendChild(card);

    // Tap to Expand Completed Card Body
    card.addEventListener('click', (e) => {
      // Don't expand if click is on buttons
      if (e.target.closest('.cbc-view-btn') || e.target.closest('.pond-action-btn')) {
        return;
      }
      const contentEl = card.querySelector('.cbc-details-content');
      const indicator = card.querySelector('.cbc-details-indicator');
      if (contentEl) {
        const isCollapsed = contentEl.classList.contains('collapsed');
        if (isCollapsed) {
          contentEl.classList.remove('collapsed');
          if (indicator) indicator.textContent = '⌃';
          sessionStorage.setItem(`aqualog_completed_expanded_${batch.id}`, 'true');
          card.setAttribute('aria-expanded', 'true');
        } else {
          contentEl.classList.add('collapsed');
          if (indicator) indicator.textContent = '⌄';
          sessionStorage.setItem(`aqualog_completed_expanded_${batch.id}`, 'false');
          card.setAttribute('aria-expanded', 'false');
        }
      }
    });

    card.addEventListener('keydown', (e) => {
      if (e.target.closest('.cbc-view-btn') || e.target.closest('.pond-action-btn')) {
        return;
      }
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        card.click();
      }
    });

    const cbcViewBtn = card.querySelector('.cbc-view-btn');
    if (cbcViewBtn) cbcViewBtn.addEventListener('click', () => openViewBatchModal(cbcViewBtn.dataset.batchid));
  });
}

function getSamplingForBatch(batchId) {
  return samplingEntries
    .filter(s => s.batchId === batchId)
    .slice()
    .sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
}

function getLatestSamplingForBatch(batchId) {
  const entries = getSamplingForBatch(batchId);
  return entries.length ? entries[0] : null;
}

function getPrimaryBatchWeight(batch) {
  const samplings = getSamplingForBatch(batch.id);
  if (samplings.length) {
    const latest = samplings[0]; // sorted newest first
    return {
      weightGrams: latest.abw,
      doc: latest.doc,
      date: latest.date,
      source: 'sampling',
      lastUpdatedDisplay: getDaysAgoDisplay(latest.date)
    };
  }
  const growth = getGrowthEntriesForBatch(batch.id);
  if (growth.length) {
    const latest = growth[growth.length - 1]; // sorted doc asc
    return {
      weightGrams: latest.weightGrams,
      doc: latest.doc,
      date: latest.date,
      source: 'visual_estimation',
      lastUpdatedDisplay: getDaysAgoDisplay(latest.date)
    };
  }
  return null;
}

function getDaysAgoDisplay(dateStr) {
  if (!dateStr) return '';
  const today0 = startOfDay();
  const upd0   = startOfDay(dateStr + 'T00:00:00');
  const days = Math.floor((today0 - upd0) / MS_PER_DAY);
  if (days === 0)      return 'Today';
  if (days === 1) return '1 Day Ago';
  return `${days} Days Ago`;
}

function updateBatchBiomassEstimation(batch) {
  const stockedQty = Number(batch.shrimpCount || 0);
  const hapa = getHapaForBatch(batch.id);
  const survivalPct = hapa ? hapa.survivalPercent : null;

  // 1. Check Hapa missing
  if (!hapa || survivalPct === null) {
    return {
      success: false,
      status: 'HAPA_MISSING',
      message: 'Hapa details missing, please fill Hapa first',
      estimatedPopulation: null,
      biomassKg: null
    };
  }

  // 2. Reject inputs <= 0
  if (stockedQty <= 0) {
    return {
      success: false,
      status: 'INVALID_INPUTS',
      message: 'Stocked quantity must be greater than zero.',
      estimatedPopulation: null,
      biomassKg: null
    };
  }
  if (survivalPct <= 0) {
    return {
      success: false,
      status: 'INVALID_INPUTS',
      message: 'Hapa survival must be greater than zero.',
      estimatedPopulation: null,
      biomassKg: null
    };
  }

  // 3. ABW sourcing (Sampling ABW with Visual Estimation fallback)
  const latestSampling = getLatestSamplingForBatch(batch.id);
  let abw = null;
  let abwSource = null;
  let warning = null;

  if (latestSampling && latestSampling.abw > 0) {
    abw = latestSampling.abw;
    abwSource = 'sampling';
  } else {
    // Fallback to Visual Estimation
    const growthEntriesForBatch = getGrowthEntriesForBatch(batch.id);
    const latestGrowth = growthEntriesForBatch.length ? growthEntriesForBatch[growthEntriesForBatch.length - 1] : null;
    if (latestGrowth && latestGrowth.weightGrams > 0) {
      abw = latestGrowth.weightGrams;
      abwSource = 'visual_estimation';
      warning = 'Sampling ABW missing, using Visual Estimation';
    }
  }

  // Check ABW missing
  if (abw === null || abw <= 0) {
    return {
      success: false,
      status: 'ABW_MISSING',
      message: 'Sampling ABW and Weight details missing, please fill them first',
      estimatedPopulation: null,
      biomassKg: null
    };
  }

  // 4. Calculations
  const estimatedPopulation = Math.round(stockedQty * (survivalPct / 100));
  // H6 fix: use calcBiomassKg (0.1 kg precision) for consistency with analytics KPI cards.
  // Was Math.round(...) (whole kg), causing mismatch between batch modal and dashboard.
  const biomassKg = calcBiomassKg(estimatedPopulation, abw) !== null
    ? calcBiomassKg(estimatedPopulation, abw)
    : Math.round((estimatedPopulation * abw) / 1000);

  // 5. Audit History Persistence
  const batchEntries = biomassEntries.filter(b => b.batchId === batch.id);
  const latestEntry = batchEntries.length ? batchEntries[batchEntries.length - 1] : null;

  const shouldSave = !latestEntry ||
    latestEntry.biomassKg !== biomassKg ||
    latestEntry.estimatedPopulation !== estimatedPopulation ||
    latestEntry.stockedQuantity !== stockedQty ||
    latestEntry.hapaSurvivalPercent !== survivalPct ||
    latestEntry.abw !== abw ||
    latestEntry.abwSource !== abwSource;

  if (shouldSave) {
    const newEntry = {
      id: `bio_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      batchId: batch.id,
      biomassKg,
      estimatedPopulation,
      stockedQuantity: stockedQty,
      hapaSurvivalPercent: survivalPct,
      abw,
      abwSource,
      timestamp: new Date().toISOString()
    };
    biomassEntries.push(newEntry);
    saveBiomassEntries();
  }

  return {
    success: true,
    estimatedPopulation,
    biomassKg,
    abw,
    abwSource,
    warning,
    stockedQuantity: stockedQty,
    hapaSurvivalPercent: survivalPct
  };
}

const SAMPLING_INTERVAL = 10; // days — standard shrimp sampling interval (10-day cycle)

function batchNeedsSampling(batch) {
  if (batch.status !== 'active') return false;
  const doc = calcDOC(batch.stockingDate);
  if (doc < 50) return false;
  const latest = getLatestSamplingForBatch(batch.id);
  if (!latest) return true;
  const today0 = startOfDay();
  const last0  = startOfDay(latest.date + 'T00:00:00');
  const daysSince = Math.floor((today0 - last0) / MS_PER_DAY);
  return daysSince >= SAMPLING_INTERVAL;
}

function samplingReminderCount() {
  return batches.filter(batchNeedsSampling).length;
}

function getSamplingStatusText(batch) {
  if (batch.status !== 'active') return null;
  const doc    = calcDOC(batch.stockingDate);
  if (doc < 50) return null;
  const latest = getLatestSamplingForBatch(batch.id);
  if (!latest) return 'Sampling Due';
  const today0   = startOfDay();
  const last0    = startOfDay(latest.date + 'T00:00:00');
  const daysSince = Math.floor((today0 - last0) / MS_PER_DAY);
  if (daysSince >= SAMPLING_INTERVAL) return 'Sampling Due';
  return null; // up to date
}

function getSamplingBadgeHTML(batch) {
  if (batch.status !== 'active') return '';
  const doc = calcDOC(batch.stockingDate);
  if (doc < 50) return '';
  const latest = getLatestSamplingForBatch(batch.id);
  if (!latest) {
    return `<span class="sampling-badge sampling-badge--due">🟡 Sampling Due</span>`;
  }
  const today0   = startOfDay();
  const last0    = startOfDay(latest.date + 'T00:00:00');
  const daysSince = Math.floor((today0 - last0) / MS_PER_DAY);
  if (daysSince >= SAMPLING_INTERVAL) {
    return `<span class="sampling-badge sampling-badge--due">🟡 Sampling Due</span>`;
  }
  return `<span class="sampling-badge sampling-badge--ok">🟢 Sampling Up To Date</span>`;
}

function openSamplingModal(batchId) {
  const batch = batches.find(b => b.id === batchId);
  if (!batch) return;
  samplingBatchId = batchId;

  const pond = ponds.find(p => p.id === batch.pondId);
  const pondName = pond ? pond.name : (batch.pond || 'Pond');
  const doc = calcDOC(batch.stockingDate);

  $('samplingModalTitle').textContent = 'Add Sampling';
  $('samplingModalContext').textContent = `${pondName} · Batch #${batch.batchNumber}`;
  $('samplingDocDisplay').textContent = `DOC ${doc}`;

  // Default date to today
  $('samplingDate').value = fmt(new Date());
  $('samplingTotalWeight').value = '';
  $('samplingShrimpCount').value = '';
  $('samplingAbwValue').textContent = '—';
  $('samplingNotes').value = '';

  // Show previous sampling preview if one exists
  const latest = getLatestSamplingForBatch(batchId);
  if (latest) {
    $('samplingPrevValue').textContent = `${latest.abw}g`;
    $('samplingPrevPreview').classList.remove('hidden');
  } else {
    $('samplingPrevPreview').classList.add('hidden');
  }

  // Clear errors
  clearFieldError('errSamplingDate',        'samplingDate',        'Required');
  clearFieldError('errSamplingTotalWeight', 'samplingTotalWeight', 'Required');
  clearFieldError('errSamplingShrimpCount', 'samplingShrimpCount', 'Required');

  // Reset save button
  $('samplingEntryConfirm').disabled = false;

  $('samplingEntryModal').classList.remove('hidden');
  setTimeout(() => $('samplingTotalWeight').focus(), 100);
}

function launchSampling(batchId) {
  if (!batchId) return;
  const batch = batches.find(b => b.id === batchId);
  if (!batch) { console.warn('[AquaLog] launchSampling: batch not found', batchId); return; }
  openSamplingModal(batchId);
}

function updateSamplingDocDisplay() {
  const batch = batches.find(b => b.id === samplingBatchId);
  if (!batch) return;
  const dateVal = $('samplingDate').value;
  if (!dateVal) { $('samplingDocDisplay').textContent = '—'; return; }
  const stock = startOfDay(batch.stockingDate);
  const sel   = startOfDay(dateVal);
  const diff  = Math.floor((sel - stock) / MS_PER_DAY);
  const doc   = diff >= 0 ? diff + 1 : 1;
  $('samplingDocDisplay').textContent = `DOC ${doc}`;
}

function updateSamplingLiveAbw() {
  const weightVal = $('samplingTotalWeight').value;
  const countVal  = $('samplingShrimpCount').value;

  const weightNum = parseFloat(weightVal);
  const countNum  = parseFloat(countVal);

  const isWeightValid = weightVal !== '' && !isNaN(weightNum) && weightNum > 0;
  const isCountValid  = countVal !== '' && !isNaN(countNum) && countNum > 0 && Number.isInteger(countNum) && countVal.indexOf('.') === -1;

  if (isWeightValid && isCountValid) {
    const abw = weightNum / countNum;
    const roundedAbw = Math.round(abw * 1000) / 1000;
    const countPerKg = Math.round(1000 / abw);
    $('samplingAbwValue').textContent = parseFloat(roundedAbw.toFixed(3)) + 'g (' + countPerKg + ' shrimp/kg)';
  } else {
    $('samplingAbwValue').textContent = '—';
  }
}

function doSaveSampling() {
  if (!samplingBatchId) return;
  const batch = batches.find(b => b.id === samplingBatchId);
  if (!batch) return;

  const dateVal        = $('samplingDate').value;
  const totalWeightVal = $('samplingTotalWeight').value;
  const shrimpCountVal = $('samplingShrimpCount').value;
  const notesVal       = $('samplingNotes').value.trim();

  // Clear errors
  clearFieldError('errSamplingDate',        'samplingDate',        'Required');
  clearFieldError('errSamplingTotalWeight', 'samplingTotalWeight', 'Required');
  clearFieldError('errSamplingShrimpCount', 'samplingShrimpCount', 'Required');

  let ok = true;

  // Date required
  if (!dateVal) {
    showFieldError('errSamplingDate', 'samplingDate', 'Required');
    ok = false;
  } else {
    const today0 = startOfDay();
    const selDate0 = startOfDay(dateVal);
    const stockDate0 = startOfDay(batch.stockingDate);

    if (selDate0 > today0) {
      showFieldError('errSamplingDate', 'samplingDate', 'Sampling date cannot be in the future.');
      ok = false;
    } else if (selDate0 < stockDate0) {
      showFieldError('errSamplingDate', 'samplingDate', 'Sampling date cannot be before the stocking date.');
      ok = false;
    }
  }

  // Total Cast Weight validation
  const totalWeightNum = parseFloat(totalWeightVal);
  if (totalWeightVal === '') {
    showFieldError('errSamplingTotalWeight', 'samplingTotalWeight', 'Required');
    ok = false;
  } else if (isNaN(totalWeightNum) || totalWeightNum <= 0) {
    showFieldError('errSamplingTotalWeight', 'samplingTotalWeight', 'Total cast weight must be greater than zero.');
    ok = false;
  }

  // Shrimp Count validation
  const shrimpCountNum = Number(shrimpCountVal);
  const isCountInteger = Number.isInteger(shrimpCountNum) && shrimpCountVal.indexOf('.') === -1;
  if (shrimpCountVal === '') {
    showFieldError('errSamplingShrimpCount', 'samplingShrimpCount', 'Required');
    ok = false;
  } else if (isNaN(shrimpCountNum) || shrimpCountNum <= 0 || !isCountInteger) {
    showFieldError('errSamplingShrimpCount', 'samplingShrimpCount', 'Shrimp count must be greater than zero.');
    ok = false;
  }

  if (!ok) return;

  // Calculate ABW
  const abwNum = Math.round((totalWeightNum / shrimpCountNum) * 1000) / 1000;

  // Calculate DOC
  const stock = startOfDay(batch.stockingDate);
  const sel   = startOfDay(dateVal);
  const diff  = Math.floor((sel - stock) / MS_PER_DAY);
  const docAtSampling = diff >= 0 ? diff + 1 : 1;

  // Calculate growth since previous sampling
  // Sort existing entries ascending by date to find the one before this new entry
  const existingSorted = samplingEntries
    .filter(s => s.batchId === samplingBatchId)
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date));

  // Find the most recent entry before or equal to dateVal (excluding same date if same id doesn't exist)
  const prevEntries = existingSorted.filter(s => s.date < dateVal);
  const prevEntry   = prevEntries.length ? prevEntries[prevEntries.length - 1] : null;

  let growthSincePrev = null;
  let daysSincePrev   = null;
  let dailyGrowth     = null;

  if (prevEntry) {
    growthSincePrev = Math.round((abwNum - prevEntry.abw) * 1000) / 1000;
    const prevDate0 = startOfDay(prevEntry.date);
    const curDate0  = startOfDay(dateVal);
    daysSincePrev   = Math.floor((curDate0 - prevDate0) / MS_PER_DAY);
    if (daysSincePrev > 0) {
      dailyGrowth = Math.round((growthSincePrev / daysSincePrev) * 1000) / 1000;
    }
  }

  const entry = {
    id:              `smp_${Date.now()}_${Math.random().toString(36).slice(2,7)}`,
    batchId:         samplingBatchId,
    batchNumber:     batch.batchNumber,
    pondId:          batch.pondId,
    date:            dateVal,
    doc:             docAtSampling,
    totalCastWeight: totalWeightNum,
    shrimpCount:     shrimpCountNum,
    sampleCount:     shrimpCountNum, // kept for backward compatibility with display references
    abw:             abwNum,
    countPerKg:      Math.round(1000 / abwNum),
    notes:           notesVal,
    growthSincePrev,
    daysSincePrev,
    dailyGrowth,
    createdAt:       new Date().toISOString(),
  };

  samplingEntries.push(entry);
  saveSamplingEntries();

  // Recalculate growth for any entries that come AFTER this new one (they now have a new prev)
  recalcSamplingGrowthForBatch(samplingBatchId);

  closeModal('samplingEntryModal');
  samplingBatchId = null;

  // Refresh
  const updatedBatch = batches.find(b => b.id === entry.batchId);
  if (updatedBatch) renderBatchDashboard(updatedBatch);
  renderActiveBatchSummaryCards();
  renderDashboard();

  showToast('✅', 'Sampling Saved', `ABW ${abwNum}g · DOC ${docAtSampling}`);
}

function recalcSamplingGrowthForBatch(batchId) {
  const entries = samplingEntries
    .filter(s => s.batchId === batchId)
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date));

  entries.forEach((entry, i) => {
    if (i === 0) {
      entry.growthSincePrev = null;
      entry.daysSincePrev   = null;
      entry.dailyGrowth     = null;
    } else {
      const prev = entries[i - 1];
      entry.growthSincePrev = Math.round((entry.abw - prev.abw) * 1000) / 1000;
      const prevD = startOfDay(prev.date);
      const curD  = startOfDay(entry.date);
      entry.daysSincePrev = Math.floor((curD - prevD) / MS_PER_DAY);
      if (entry.daysSincePrev > 0) {
        entry.dailyGrowth = Math.round((entry.growthSincePrev / entry.daysSincePrev) * 1000) / 1000;
      } else {
        entry.dailyGrowth = null;
      }
    }
  });
  saveSamplingEntries();
}

function deleteSamplingEntry(samplingId) {
  const entry = samplingEntries.find(s => s.id === samplingId);
  if (!entry) return;
  showConfirm(
    'Delete Sampling?',
    `Remove ABW ${entry.abw}g recorded on ${fmtDateDisplay(entry.date)}?`,
    () => {
      const batchId = entry.batchId;
      state.setSamplingEntries(state.samplingEntries.filter(s => s.id !== samplingId));
      saveSamplingEntries();
      recalcSamplingGrowthForBatch(batchId);
      const batch = batches.find(b => b.id === batchId);
      if (batch) renderBatchDashboard(batch);
      renderActiveBatchSummaryCards();
      showToast('🗑', 'Sampling Deleted', 'Entry removed');
    },
    { danger: true, icon: '🗑', confirmLabel: 'Delete' }
  );
}

function renderBatchSamplingCard(batch) {
  const header = $('samplingHeader');
  const card   = $('samplingCard');
  if (!header || !card) return;

  const entries  = getSamplingForBatch(batch.id);
  const isActive = batch.status === 'active';

  // ── Empty state ──────────────────────────────────────────
  if (!entries.length) {
    const doc = calcDOC(batch.stockingDate);
    const dueMsg = doc < 50
      ? `Sampling begins around DOC 50. Currently DOC ${doc}.`
      : `Record your first ABW measurement to start sampling.`;
    card.innerHTML = `
      <div class="gt-card-empty">
        <div class="gt-card-empty-icon">🔬</div>
        <div class="gt-card-empty-title">No Samples Recorded</div>
        <div class="gt-card-empty-sub">${dueMsg}</div>
        ${isActive ? `<button class="gt-add-weight-btn" data-action="openSamplingModal" data-batch-id="${batch.id}">＋ Add Sampling</button>` : ''}
      </div>`;
    return;
  }

  // ── Has entries ──────────────────────────────────────────
  const SHOW_MAX  = 5;
  const toShow    = entries.slice(0, SHOW_MAX);
  const hasMore   = entries.length > SHOW_MAX;

  const growthChip = (entry) => {
    if (entry.growthSincePrev === null || entry.growthSincePrev === undefined) return '';
    const sign  = entry.growthSincePrev >= 0 ? '+' : '';
    const color = entry.growthSincePrev >= 0 ? 'var(--teal)' : 'var(--amber)';
    return `<span class="smp-growth-chip" style="color:${color}">${sign}${entry.growthSincePrev}g</span>`;
  };

  const dailyChip = (entry) => {
    if (entry.dailyGrowth === null || entry.dailyGrowth === undefined) return '';
    const sign  = entry.dailyGrowth >= 0 ? '+' : '';
    return `<span class="smp-daily-chip">${sign}${entry.dailyGrowth}g/day</span>`;
  };

  const countChip = (entry) => {
    const c = entry.countPerKg || (entry.abw > 0 ? Math.round(1000 / entry.abw) : null);
    if (!c) return '';
    return `<span class="smp-count-chip" style="color:var(--t2);font-size:0.75rem">${c} pcs/kg</span>`;
  };

  const delBtn = (e) => isActive ? `<button class="gt-history-del" data-action="deleteSamplingEntry" data-sampling-id="${e.id}" title="Delete" aria-label="Delete Sampling">🗑</button>` : '';

  const historyRow = (e) => `
    <div class="smp-history-row">
      <div class="smp-history-left">
        <div class="smp-history-date">${fmtDateDisplay(e.date)}</div>
        <div class="smp-history-meta">DOC ${e.doc}${e.notes ? ` · ${escapeHTML(e.notes)}` : ''}</div>
      </div>
      <div class="smp-history-right">
        <span class="smp-abw-val">${e.abw}g</span>
        ${countChip(e)}
        ${growthChip(e)}
        ${dailyChip(e)}
        ${delBtn(e)}
      </div>
    </div>`;

  card.innerHTML = `
    ${isActive ? `<button class="gt-add-weight-btn" data-action="openSamplingModal" data-batch-id="${batch.id}" style="margin-bottom: 12px;">＋ Add Sampling</button>` : ''}
    <div class="smp-history-list" id="smpHistoryList">
      ${toShow.map(historyRow).join('')}
    </div>
    ${hasMore ? `
    <button class="gt-view-all-btn" id="smpViewAllBtn" data-action="toggleSamplingHistory" data-batch-id="${batch.id}">
      View All ${entries.length} Records ▾
    </button>
    <div class="smp-history-expanded hidden" id="smpHistoryExpanded">
      ${entries.slice(SHOW_MAX).map(historyRow).join('')}
    </div>` : ''}`;
}

function toggleSamplingHistory(batchId, btn) {
  const expanded = $('smpHistoryExpanded');
  if (!expanded) return;
  const isHidden = expanded.classList.contains('hidden');
  expanded.classList.toggle('hidden', !isHidden);
  if (btn) btn.textContent = isHidden
    ? 'Collapse ▴'
    : `View All ${getSamplingForBatch(batchId).length} Records ▾`;
}

function renderSamplingDashboardWarning() {
  const wrap = $('samplingWarningWrap');
  if (!wrap) return;
  wrap.innerHTML = '';

  const activeBatches = batches.filter(b => b.status === 'active');
  const dueBatches = activeBatches.filter(batchNeedsSampling);

  if (dueBatches.length === 0) {
    wrap.classList.add('hidden');
    return;
  }

  wrap.classList.remove('hidden');
  dueBatches.forEach(batch => {
    const pond = ponds.find(p => p.id === batch.pondId);
    const pondName = pond ? pond.name : (batch.pond || 'Pond');
    const banner = document.createElement('div');
    banner.className = 'sampling-warn-banner';
    banner.innerHTML = `
      <span class="swb-icon">🔬</span>
      <span class="swb-text">Sampling Due: ${escapeHTML(pondName)} · Batch #${batch.batchNumber}</span>
      <span class="swb-arrow">→</span>
    `;
    banner.addEventListener('click', () => {
      launchSampling(batch.id);
    });
    wrap.appendChild(banner);
  });
}

function jumpToBatchDashboard(batchId) {
  const select = $('dashboardContextSelect');
  if (!select) return;
  select.value = `batch_${batchId}`;
  select.dispatchEvent(new Event('change', { bubbles: true }));
  alSelects.dashCtx?.sync();
}

function renderBatchSamplingOverview(batch) {
  // Inject latest sampling info into the batch summary card expanded details
  const el = $('batchCardSamplingInfo');
  if (!el) return;
  const latest = getLatestSamplingForBatch(batch.id);
  if (!latest) {
    el.innerHTML = `<div class="bsc-info-lbl">Latest Sampling</div><div class="bsc-info-val">—</div>`;
  } else {
    const countKg = latest.countPerKg || (latest.abw > 0 ? Math.round(1000 / latest.abw) : null);
    const countStr = countKg ? ` · ${countKg} pcs/kg` : '';
    el.innerHTML = `
      <div class="bsc-info-lbl">Latest Sampling</div>
      <div class="bsc-info-val" style="color:var(--teal)">${latest.abw}g${countStr} <span style="color:var(--t2);font-weight:400;font-size:.78rem">· ${fmtDateDisplay(latest.date)}</span></div>`;
  }
}

function saveBiomassEntries() {
  AppStorage.saveBiomass(biomassEntries);
}

function getGrowthEntriesForBatch(batchId) {
  return growthEntries
    .filter(e => e.batchId === batchId)
    .slice()
    .sort((a, b) => a.doc - b.doc || a.date.localeCompare(b.date));
}

function reRenderCurrentBatch() {
  const batchId = growthModalBatchId;
  // Always refresh farm dashboard active batch cards (they show weight data)
  renderActiveBatchSummaryCards();
  if (!batchId) return;
  const batch = batches.find(b => b.id === batchId);
  if (batch) renderBatchDashboard(batch);
}

function renderBatchGrowthCard(batch) {
  const header = $('growthTrackingHeader');
  const card   = $('growthTrackingCard');
  if (!header || !card) return;

  header.classList.remove('hidden');
  card.classList.remove('hidden');

  const visualEntries = getGrowthEntriesForBatch(batch.id);
  const samplingEntries = getSamplingForBatch(batch.id);
  const isActive = batch.status === 'active';
  const hasSampling = samplingEntries.length > 0;

  // Store batchId so the modals know which batch they belong to
  growthModalBatchId = batch.id;
  samplingBatchId = batch.id;

  // Combine both entries by date
  const dateMap = {};
  visualEntries.forEach(g => {
    if (!dateMap[g.date]) dateMap[g.date] = { date: g.date, doc: g.doc, visual: null, sampling: null };
    dateMap[g.date].visual = g;
  });
  samplingEntries.forEach(s => {
    if (!dateMap[s.date]) dateMap[s.date] = { date: s.date, doc: s.doc, visual: null, sampling: null };
    dateMap[s.date].sampling = s;
  });

  const combinedRows = Object.values(dateMap).sort((a, b) => b.date.localeCompare(a.date));

  // ── Fix #9: Collapsed-by-default Visual Weight card ──
  // Preserve the user's expand/collapse state during the session.
  if (card.dataset.gtUserToggled === undefined) {
    card.dataset.gtUserToggled = 'false';
    card.classList.add('gt-collapsed');
  }

  // ── Empty state (still rendered as a collapsed-style header) ──
  if (!combinedRows.length) {
    card.innerHTML = `
      <div class="gt-collapse-header" data-action="toggleGrowthCard">
        <span class="gt-collapse-header-icon">📏</span>
        <span class="gt-collapse-header-title">Visual Weight History</span>
        <span class="gt-collapse-header-meta">No entries yet</span>
        <span class="gt-collapse-header-chevron">▾</span>
      </div>
      <div class="gt-collapse-body">
        <div class="gt-card-empty">
          <div class="gt-card-empty-icon">📏</div>
          <div class="gt-card-empty-title">No Records Available</div>
          <div class="gt-card-empty-sub">Add a visual weight or sampling entry to start tracking growth.</div>
          <div class="wh-btn-add-row" style="margin-top: 15px; justify-content: center; width: 100%;">
            ${isActive ? `
              <button class="wh-add-btn" data-action="openLogWeightModal" data-batch-id="${batch.id}">＋ Add Visual Weight</button>
              <button class="wh-add-btn" data-action="openSamplingModal" data-batch-id="${batch.id}" style="border-color:var(--teal);color:var(--teal);">🔬 Add Sampling</button>
            ` : ''}
          </div>
        </div>
      </div>`;
    wireGrowthCardToggle(card);
    return;
  }

  // Helper to render each grid row
  const buildWeightHistoryRow = (row) => {
    const dateText = fmtDateDisplay(row.date);
    const docText = `DOC ${row.doc}`;

    // Weight column (merged)
    let weightText = '—';
    let weightClass = 'wh-col-weight';
    if (row.sampling) {
      weightText = `${row.sampling.abw.toFixed(2)} g`;
      weightClass += ' wh-col-sampling';
    } else if (row.visual) {
      weightText = `${row.visual.weightGrams.toFixed(2)} g`;
      weightClass += ' wh-col-visual';
    }

    // Notes column
    let notesText = '';
    if (row.sampling && row.sampling.notes) {
      notesText = escapeHTML(row.sampling.notes);
    } else if (row.visual && row.visual.notes) {
      notesText = escapeHTML(row.visual.notes);
    }

    // Action buttons
    let actionHTML = '';
    if (isActive) {
      if (row.sampling) {
        actionHTML += `<button class="gt-history-del" data-action="deleteSamplingEntry" data-sampling-id="${row.sampling.id}" title="Delete Sampling" aria-label="Delete Sampling">🗑</button>`;
      }
      if (row.visual) {
        actionHTML += `<button class="gt-history-edit" data-action="openEditGrowthEntry" data-growth-id="${row.visual.id}" title="${hasSampling ? 'View details (read-only)' : 'Edit Visual Weight'}" aria-label="Edit Visual Weight">✏</button>`;
        if (!hasSampling) {
          actionHTML += `<button class="gt-history-del" data-action="deleteGrowthEntry" data-growth-id="${row.visual.id}" title="Delete Visual Weight" aria-label="Delete Visual Weight">🗑</button>`;
        }
      }
    }

    return `
      <div class="weight-history-row-container">
        <div class="weight-history-row">
          <span class="wh-col-date">${dateText}</span>
          <span class="wh-col-doc">${docText}</span>
          <span class="${weightClass}">${weightText}</span>
          <span class="wh-col-actions">${actionHTML}</span>
        </div>
        ${notesText ? `
          <div class="weight-history-notes-row">
            <span class="wh-notes-icon">📝</span>
            <span class="wh-notes-text">${notesText}</span>
          </div>
        ` : ''}
      </div>
    `;
  };

  const SHOW_MAX = 5;
  const toShow = combinedRows.slice(0, SHOW_MAX);
  const hasMore = combinedRows.length > SHOW_MAX;

  // Latest entry summary for the collapsed header
  const latestRow = combinedRows[0];
  let latestSummary = '';
  if (latestRow) {
    const w = latestRow.sampling ? latestRow.sampling.abw : (latestRow.visual ? latestRow.visual.weightGrams : null);
    if (w !== null) {
      latestSummary = `Latest: ${w.toFixed(2)}g · DOC ${latestRow.doc} · ${combinedRows.length} record${combinedRows.length !== 1 ? 's' : ''}`;
    } else {
      latestSummary = `${combinedRows.length} record${combinedRows.length !== 1 ? 's' : ''}`;
    }
  }

  card.innerHTML = `
    <div class="gt-collapse-header" data-action="toggleGrowthCard">
      <span class="gt-collapse-header-icon">📏</span>
      <span class="gt-collapse-header-title">Visual Weight History</span>
      <span class="gt-collapse-header-meta">${escapeHTML(latestSummary)}</span>
      <span class="gt-collapse-header-chevron">▾</span>
    </div>
    <div class="gt-collapse-body">
      ${isActive ? `
        <div class="wh-btn-add-row">
          <button class="wh-add-btn" ${hasSampling ? 'disabled title="Visual Weight disabled after first sampling entry."' : `data-action="openLogWeightModal" data-batch-id="${batch.id}"`}>＋ Add Visual Weight</button>
          <button class="wh-add-btn" data-action="openSamplingModal" data-batch-id="${batch.id}" style="border-color:var(--teal);color:var(--teal);">🔬 Add Sampling</button>
        </div>
      ` : ''}
      <div class="weight-history-scroll-wrap">
        <div class="weight-history-header">
          <span class="wh-col-date">Date</span>
          <span class="wh-col-doc">DOC</span>
          <span class="wh-col-weight">Weight</span>
          <span class="wh-col-actions"></span>
        </div>
        <div class="wh-history-list" id="whHistoryList">
          ${toShow.map(buildWeightHistoryRow).join('')}
        </div>
        ${hasMore ? `
          <div class="wh-history-expanded hidden" id="whHistoryExpanded">
            ${combinedRows.slice(SHOW_MAX).map(buildWeightHistoryRow).join('')}
          </div>
        ` : ''}
      </div>
      ${hasMore ? `
        <button class="gt-view-all-btn" id="whViewAllBtn" data-total="${combinedRows.length}" data-action="toggleWeightHistory" data-batch-id="${batch.id}">
          View All ${combinedRows.length} Records ▾
        </button>
      ` : ''}
    </div>`;

  wireGrowthCardToggle(card);
}

// ── Fix #9: Wire the collapse-header click handler ──
function wireGrowthCardToggle(card) {
  if (!card || card._gtToggleWired) return;
  card._gtToggleWired = true;
  card.addEventListener('click', function (e) {
    const hdr = e.target.closest('.gt-collapse-header');
    if (!hdr) return;
    e.preventDefault();
    e.stopPropagation();
    card.classList.toggle('gt-collapsed');
    card.dataset.gtUserToggled = card.classList.contains('gt-collapsed') ? 'false' : 'true';
  });
}

function toggleWeightHistory(batchId, btn) {
  const expanded = $('whHistoryExpanded');
  if (!expanded) return;
  const isHidden = expanded.classList.contains('hidden');
  expanded.classList.toggle('hidden', !isHidden);
  if (btn) {
    const total = Number(btn.dataset.total || 0);
    btn.textContent = isHidden ? 'Collapse ▴' : `View All ${total} Records ▾`;
  }
}

function renderGrowthFeedTrendChart(batch) {
  const header = $('growthFeedTrendHeader');
  const card   = $('growthFeedTrendCard');
  const empty  = $('growthFeedEmpty');
  const canvas = $('growthFeedChart');
  if (!header || !card || !canvas) return;

  const visualEntries = getGrowthEntriesForBatch(batch.id);
  const samplingEntries = getSamplingForBatch(batch.id);
  const feedDocRaw = getBatchFeedDataForDOC(batch); // [{label:'D1', value: grams}]
  const hasFeed    = feedDocRaw.some(d => d.value > 0);

  // Group by DOC, prioritizing sampling
  const mergedMap = {};
  visualEntries.forEach(e => {
    mergedMap[e.doc] = { doc: e.doc, value: e.weightGrams, source: 'visual' };
  });
  samplingEntries.forEach(e => {
    mergedMap[e.doc] = { doc: e.doc, value: e.abw, source: 'sampling' };
  });

  const growthData = Object.values(mergedMap).sort((a, b) => a.doc - b.doc);
  const hasGrowth  = growthData.length >= 1;

  // Nothing to show at all
  if (!hasFeed && !hasGrowth) {
    header.classList.add('hidden');
    card.classList.add('hidden');
    const summaryBox = $('growthFeedTrendSummary');
    if (summaryBox) summaryBox.classList.add('hidden');
    return;
  }

  header.classList.remove('hidden');
  card.classList.remove('hidden');

  if (!hasGrowth) {
    canvas.style.display = 'none';
    if (empty) {
      empty.textContent = 'No Records Available';
      empty.classList.remove('hidden');
    }
    const summaryBox = $('growthFeedTrendSummary');
    if (summaryBox) summaryBox.classList.add('hidden');
    return;
  }

  canvas.style.display = '';
  if (empty) empty.classList.add('hidden');

  // feedData: each entry is {doc: N, value: grams}
  const feedData   = feedDocRaw.map((d, i) => ({ doc: i + 1, value: d.value }));

  const latestWeight = growthData.length ? growthData[growthData.length - 1].value : 0;
  const totalFeed = feedData.reduce((sum, d) => sum + d.value, 0);
  const desc = `Growth vs Feed Trend: Shows shrimp weight increasing to a final recorded weight of ${latestWeight}g, with a total feed consumption of ${fmtGrams(totalFeed)}g.`;
  canvas.setAttribute('role', 'img');
  canvas.setAttribute('aria-label', desc);

  // Generate Growth vs Feed Summary
  const summaryBox = $('growthFeedTrendSummary');
  if (summaryBox) {
    const firstWeight = growthData.length ? growthData[0].value : 0;
    let adgText = "";
    if (growthData.length >= 2) {
      const firstEntry = growthData[0];
      const lastEntry = growthData[growthData.length - 1];
      const docDiff = lastEntry.doc - firstEntry.doc;
      if (docDiff > 0) {
        const adg = (lastEntry.value - firstEntry.value) / docDiff;
        adgText = ` Average Daily Gain (ADG) is <strong class="summary-highlight">${adg.toFixed(2)}g</strong>/day.`;
      }
    }
    summaryBox.innerHTML = `Growth vs Feed: Shrimp weight increased from ${firstWeight}g to a final recorded weight of <strong class="summary-highlight">${latestWeight}g</strong>. Total batch feed consumption is <strong class="summary-highlight">${fmtGrams(totalFeed)}g</strong>.${adgText}`;
    summaryBox.classList.remove('hidden');
  }

  requestAnimationFrame(() => drawDualAxisLineChart('growthFeedChart', feedData, growthData));
}

function openEditGrowthEntry(id) {
  const entry = growthEntries.find(e => e.id === id);
  if (!entry) return;

  editGrowthEntryId  = id;
  growthModalBatchId = entry.batchId;

  const modal = $('logWeightModal');
  if (!modal) return;

  const samplings = getSamplingForBatch(entry.batchId);
  const hasSampling = samplings.length > 0;

  // Toggle warning element and set text/deviation warning
  const warnEl = $('errVisualDisabled');
  if (warnEl) {
    if (hasSampling) {
      const latestSampling = samplings[0];
      let devText = '';
      if (latestSampling) {
        const diff = entry.weightGrams - latestSampling.abw;
        const sign = diff >= 0 ? '+' : '';
        devText = `<br/><span style="font-weight:normal;opacity:0.85">Visual estimation differs from last sampling by ${sign}${diff.toFixed(2)}g</span>`;
      }
      warnEl.innerHTML = `⚠ Visual Weight disabled after first sampling entry.${devText}`;
      warnEl.classList.remove('hidden');
    } else {
      warnEl.textContent = '⚠ Visual Weight disabled after first sampling entry.';
      warnEl.classList.add('hidden');
    }
  }

  // Update modal title for "Edit" mode
  const titleEl = modal.querySelector('.modal-title');
  // M8 fix: when sampling exists, the form is read-only — reflect that in the title
  if (titleEl) titleEl.textContent = hasSampling ? 'View Weight (read-only)' : 'Edit Weight';
  const subEl = modal.querySelector('.modal-pond-context');
  if (subEl) subEl.textContent = `DOC ${entry.doc} · ${fmtDateDisplay(entry.date)}`;

  // Confirm button locking
  const confirmBtn = $('logWeightConfirm');
  if (confirmBtn) confirmBtn.disabled = hasSampling;

  // Batch select — show entry's batch, lock it in edit mode
  const sel = $('growthBatchSelect');
  if (sel) {
    const pond = ponds.find(p => p.id === entry.pondId);
    const name = pond ? pond.name : (entry.pondName || 'Pond');
    sel.innerHTML = `<option value="${entry.batchId}" selected>${name} · Batch #${entry.batchNumber}</option>`;
    sel.disabled  = true;
  }

  // Date — lock; DOC auto-shown
  const dateInput = $('growthDate');
  if (dateInput) {
    dateInput.value    = entry.date;
    dateInput.disabled = true;
  }

  // Show DOC badge
  const badge = $('growthDocBadge');
  if (badge) {
    badge.textContent = `DOC ${entry.doc}`;
    badge.style.color = '';
    badge.classList.remove('hidden');
  }

  // Pre-fill weight and notes
  const wInput = $('growthWeightInput');
  if (wInput) {
    wInput.value = entry.weightGrams;
    wInput.disabled = hasSampling;
  }
  const nInput = $('growthNotes');
  if (nInput) {
    nInput.value = entry.notes || '';
    nInput.disabled = hasSampling;
  }

  ['errGrowthBatch','errGrowthDate','errGrowthWeight'].forEach(id => $(id)?.classList.remove('show'));

  modal.classList.remove('hidden');
}

function updateGrowthDocBadge() {
  const badge     = $('growthDocBadge');
  const dateInput = $('growthDate');
  const batchSel  = $('growthBatchSelect');
  if (!badge || !dateInput || !batchSel) return;

  const batchId = batchSel.value;
  const dateStr = dateInput.value;
  const batch   = batches.find(b => b.id === batchId);

  if (!batch || !dateStr) { badge.classList.add('hidden'); return; }

  dateInput.min = batch.stockingDate;
  const diff    = Math.floor((startOfDay(dateStr) - startOfDay(batch.stockingDate)) / MS_PER_DAY);

  if (diff >= 0) {
    badge.textContent = `DOC ${diff + 1}`;
    badge.style.color = '';
    badge.classList.remove('hidden');
  } else {
    badge.textContent = '⚠ Date is before stocking date';
    badge.style.color = 'var(--red)';
    badge.classList.remove('hidden');
  }
}

function doLogWeight() {
  const isEdit    = !!editGrowthEntryId;
  const batchId   = $('growthBatchSelect').value || growthModalBatchId;
  const dateStr   = $('growthDate').value;
  const weightStr = $('growthWeightInput').value.trim();
  const notes     = $('growthNotes').value.trim();
  let   valid     = true;

  const errBatch = $('errGrowthBatch');
  if (!batchId) { errBatch?.classList.add('show'); valid = false; }
  else            errBatch?.classList.remove('show');

  const errDate = $('errGrowthDate');
  const batch   = batches.find(b => b.id === batchId);
  const today   = fmt(new Date());
  if (!isEdit) {
    // Only validate date in Add mode (locked in Edit mode)
    if (!dateStr) {
      if (errDate) { errDate.textContent = 'Date is required'; errDate.classList.add('show'); }
      valid = false;
    } else if (batch && dateStr < batch.stockingDate) {
      if (errDate) { errDate.textContent = 'Date cannot be before stocking date'; errDate.classList.add('show'); }
      valid = false;
    } else if (dateStr > today) {
      if (errDate) { errDate.textContent = 'Date cannot be in the future'; errDate.classList.add('show'); }
      valid = false;
    } else errDate?.classList.remove('show');
  } else errDate?.classList.remove('show');

  const errWeight = $('errGrowthWeight');
  const weight    = parseFloat(weightStr);
  if (!weightStr || isNaN(weight) || weight <= 0 || weight > 1000) {
    errWeight?.classList.add('show'); valid = false;
  } else errWeight?.classList.remove('show');

  if (!valid) return;

  // Use the entry's stored date for edits (locked)
  const useDateStr = isEdit ? growthEntries.find(e => e.id === editGrowthEntryId)?.date || dateStr : dateStr;
  const stock  = startOfDay((batch?.stockingDate || useDateStr));
  const tgt    = startOfDay(useDateStr);
  const doc    = batch ? Math.max(1, Math.floor((tgt - stock) / MS_PER_DAY) + 1) : 1;
  const pond   = ponds.find(p => p.id === batch?.pondId);

  const entry = {
    id:          isEdit ? editGrowthEntryId : ('gt_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7)),
    batchId:     batchId,
    batchNumber: batch?.batchNumber,
    pondId:      batch?.pondId,
    pondName:    pond ? pond.name : (batch?.pond || ''),
    date:        useDateStr,
    doc:         doc,
    weightGrams: weight,
    notes:       notes,
    createdAt:   isEdit ? (growthEntries.find(e => e.id === editGrowthEntryId)?.createdAt || new Date().toISOString()) : new Date().toISOString(),
    updatedAt:   isEdit ? new Date().toISOString() : undefined,
  };

  if (isEdit) {
    const idx = growthEntries.findIndex(e => e.id === editGrowthEntryId);
    if (idx >= 0) growthEntries[idx] = entry;
    showToast('✅', 'Weight Updated', `DOC ${doc} · ${fmtWeightG(weight)}/shrimp`);
  } else {
    // Upsert: replace if same batch + date exists
    const dupIdx = growthEntries.findIndex(e => e.batchId === batchId && e.date === useDateStr);
    if (dupIdx >= 0) {
      growthEntries[dupIdx] = entry;
      showToast('✅', 'Weight Updated', `DOC ${doc} · ${fmtWeightG(weight)}/shrimp`);
    } else {
      growthEntries.push(entry);
      showToast('✅', 'Weight Logged', `DOC ${doc} · ${fmtWeightG(weight)}/shrimp`);
    }
  }

  saveGrowthEntries();
  editGrowthEntryId = null;

  // Re-enable fields for next use
  const sel = $('growthBatchSelect');
  if (sel) sel.disabled = false;
  const di  = $('growthDate');
  if (di)  di.disabled  = false;

  $('logWeightModal').classList.add('hidden');  // direct hide: editGrowthEntryId already reset above; growthModalBatchId must NOT be nulled here (used by re-render)
  growthModalBatchId = batchId;
  reRenderCurrentBatch();
}

function deleteGrowthEntry(id) {
  const entry = growthEntries.find(e => e.id === id);
  if (!entry) return;
  const batchId = entry.batchId;
  showConfirm(
    'Delete Weight Entry?',
    `DOC ${entry.doc} · ${fmtWeightG(entry.weightGrams)}/shrimp · ${fmtDateDisplay(entry.date)}`,
    () => {
      state.setGrowthEntries(state.growthEntries.filter(e => e.id !== id));
      saveGrowthEntries();
      showToast('🗑', 'Entry Deleted', '');
      growthModalBatchId = batchId;
      reRenderCurrentBatch();
    },
    { danger: true, icon: '🗑', confirmLabel: 'Delete', cancelLabel: 'Cancel' }
  );
}

function saveGrowthEntries() {
  AppStorage.saveGrowth(growthEntries);
}

function getBiomassVbsRowsHTML(batch) {
  const result = updateBatchBiomassEstimation(batch);
  if (!result.success) {
    if (result.status === 'HAPA_MISSING') {
      return `<div class="vbs-row"><span class="vbs-label">Biomass</span><span class="vbs-val" style="color:var(--red);font-size:.78rem;">⚠️ Hapa details missing</span></div>`;
    }
    return `<div class="vbs-row"><span class="vbs-label">Biomass</span><span class="vbs-val" style="color:var(--t3);font-size:.78rem;">—</span></div>`;
  }

  const popDisplay = Number(result.estimatedPopulation).toLocaleString();
  const biomassDisplay = `${Number(result.biomassKg).toLocaleString()} kg`;
  const abwDisplay = fmtWeightG(result.abw).replace('g', ' g');
  const sourceLabel = result.abwSource === 'visual_estimation' ? 'Visual Est.' : 'Sampling';
  const color = result.abwSource === 'visual_estimation' ? 'var(--amber)' : 'var(--teal)';

  return `
    <div class="vbs-row"><span class="vbs-label">Latest ABW</span><span class="vbs-val" style="color:${color};">${abwDisplay} <span style="font-size:.7rem;font-weight:normal;color:var(--t3)">(${sourceLabel})</span></span></div>
    <div class="vbs-row"><span class="vbs-label">Est. Population</span><span class="vbs-val">${popDisplay}</span></div>
    <div class="vbs-row"><span class="vbs-label">Current Biomass</span><span class="vbs-val" style="color:var(--teal);">${biomassDisplay}</span></div>
  `;
}

function openLogWeightModal(batchId) {
  // Resolve batchId — fall back to current dashboard batch
  const resolvedId = batchId || growthModalBatchId;
  
  const samplings = getSamplingForBatch(resolvedId);
  const hasSampling = samplings.length > 0;
  if (hasSampling) {
    showToast('⚠️', 'Visual Weight Disabled', 'Visual weight entries are disabled after first sampling.');
    return;
  }

  growthModalBatchId = resolvedId;
  editGrowthEntryId  = null; // Add mode

  const modal = $('logWeightModal');
  if (!modal) return;

  // Toggle warning element inside modal
  const warnEl = $('errVisualDisabled');
  if (warnEl) {
    warnEl.textContent = '⚠ Visual Weight disabled after first sampling entry.';
    warnEl.classList.toggle('hidden', !hasSampling);
  }

  // Update modal title for "Add" mode
  const titleEl = modal.querySelector('.modal-title');
  if (titleEl) titleEl.textContent = 'Log Weight';
  const subEl = modal.querySelector('.modal-pond-context');
  if (subEl) subEl.textContent = 'Record estimated average shrimp weight';

  // Confirm button
  const confirmBtn = $('logWeightConfirm');
  if (confirmBtn) confirmBtn.disabled = hasSampling;

  // Populate batch select with active batches
  const sel = $('growthBatchSelect');
  if (sel) {
    const activeBatches = batches.filter(b => b.status === 'active');
    sel.innerHTML = '<option value="">— Select batch —</option>' +
      activeBatches.map(b => {
        const pond     = ponds.find(p => p.id === b.pondId);
        const name     = pond ? pond.name : (b.pond || 'Pond');
        const selected = b.id === resolvedId ? ' selected' : '';
        return `<option value="${b.id}"${selected}>${name} · Batch #${b.batchNumber}</option>`;
      }).join('');
    sel.disabled = hasSampling;
  }

  // Default date = today; clamp by stocking date
  const dateInput = $('growthDate');
  if (dateInput) {
    const today     = fmt(new Date());
    dateInput.value = today;
    dateInput.max   = today;
    dateInput.disabled = hasSampling;
    const batch = batches.find(b => b.id === resolvedId);
    if (batch) dateInput.min = batch.stockingDate;
  }

  // Clear weight and notes
  const wInput = $('growthWeightInput');
  if (wInput) {
    wInput.value = '';
    wInput.disabled = hasSampling;
  }
  const nInput = $('growthNotes');
  if (nInput) {
    nInput.value = '';
    nInput.disabled = hasSampling;
  }

  ['errGrowthBatch','errGrowthDate','errGrowthWeight'].forEach(id => $(id)?.classList.remove('show'));

  updateGrowthDocBadge();
  modal.classList.remove('hidden');
}

function openEditBatchModal(batchId) {
  const batch = batches.find(b => b.id === batchId);
  if (!batch) return;
  editBatchId = batchId;

  const pond = ponds.find(p => p.id === batch.pondId);
  $('editBatchModalTitle').textContent = `Edit Batch #${batch.batchNumber}`;
  $('editBatchPondCtx').textContent = pond ? `${pond.name} · ${pond.site}` : (batch.pond || '');

  $('editBatchShrimpCount').value = batch.shrimpCount || '';
  $('editBatchStockDate').value   = batch.stockingDate || '';
  $('editBatchStockDate').max     = fmt(new Date());
  $('editBatchStockTime').value   = batch.stockingTime || '';
  $('editBatchNotes').value       = batch.notes || '';

  clearFieldError('errEditBatchShrimp', 'editBatchShrimpCount', 'Enter a valid shrimp count');
  clearFieldError('errEditBatchDate', 'editBatchStockDate', 'Required');
  clearFieldError('errEditBatchTime', 'editBatchStockTime', 'Required');

  $('editBatchModal').classList.remove('hidden');
}

function doSaveEditBatch() {
  if (!editBatchId) return;
  const batch = batches.find(b => b.id === editBatchId);
  if (!batch) return;

  const newCount    = $('editBatchShrimpCount').value;
  const newDate     = $('editBatchStockDate').value;
  const newTime     = $('editBatchStockTime').value;
  const newNotes    = $('editBatchNotes').value.trim();

  // Validate
  const validation = validateBatchCreateData(newCount, newDate, newTime);
  clearFieldError('errEditBatchShrimp', 'editBatchShrimpCount', 'Enter a valid shrimp count');
  clearFieldError('errEditBatchDate', 'editBatchStockDate', 'Required');
  clearFieldError('errEditBatchTime', 'editBatchStockTime', 'Required');
  if (validation.errors.shrimpCount) showFieldError('errEditBatchShrimp', 'editBatchShrimpCount', validation.errors.shrimpCount);
  if (validation.errors.stockingDate) showFieldError('errEditBatchDate', 'editBatchStockDate', validation.errors.stockingDate);
  if (validation.errors.stockingTime) showFieldError('errEditBatchTime', 'editBatchStockTime', validation.errors.stockingTime);
  if (!validation.ok) return;

  const dateChanged = newDate !== batch.stockingDate;

  // If stocking date changed: integrity check first
  if (dateChanged) {
    // Check all feed records assigned to this batch still fit
    const batchFeeds = records.filter(r => r.BatchId === batch.id);
    const harvestDate = batch.harvestDate || (batch.completedAt ? batch.completedAt.split('T')[0] : null);
    for (const rec of batchFeeds) {
      if (!isIsoDateStr(rec.Date)) continue;
      if (rec.Date < newDate) {
        showToast('⚠️', 'Cannot Save', 'Some feed records would fall outside this batch after the date change.');
        return;
      }
      if (isIsoDateStr(harvestDate) && rec.Date > harvestDate) {
        showToast('⚠️', 'Cannot Save', 'Some feed records would fall outside this batch after the date change.');
        return;
      }
    }

    // Store pending data and show warning
    editBatchPendingData = { newCount, newDate, newTime, newNotes };
    // Hide editBatchModal without resetting editBatchId (needed by batchDateWarnConfirm)
    $('editBatchModal').classList.add('hidden');
    $('batchDateWarnModal').classList.remove('hidden');
    return;
  }

  applyBatchEdit(batch, newCount, newDate, newTime, newNotes);
}

function applyBatchEdit(batch, newCount, newDate, newTime, newNotes) {
  batch.shrimpCount   = numberFromField(newCount);
  batch.stockingDate  = newDate;
  batch.stockingTime  = newTime;
  batch.notes         = newNotes;
  AppStorage.saveBatches(batches);

  editBatchId = null;
  editBatchPendingData = null;
  closeModal('editBatchModal');
  closeModal('batchDateWarnModal');
  closeModal('viewBatchModal');

  renderManagePage();
  renderDashboard();
  showToast('✅', 'Batch Updated', `Batch #${batch.batchNumber} saved`);
}

function saveSamplingEntries() {
  AppStorage.saveSampling(samplingEntries);
}

function toggleAnalyticsPanel() {
  const panel = $('analyticsPanel');
  const btn   = $('toggleAnalyticsBtn');
  if (!panel || !btn) return;
  const isHidden = panel.classList.contains('hidden');
  panel.classList.toggle('hidden', !isHidden);
  btn.textContent = isHidden ? 'Hide ▴' : 'Show ▾';
  if (isHidden && _analyticsBatchId) {
    const batch = batches.find(b => b.id === _analyticsBatchId);
    if (batch) renderAnalyticsModule(batch);
  }
}

function renderAnalyticsTabHeader(batch) {
  const header = $('analyticsTabHeader');
  const btn    = $('toggleAnalyticsBtn');
  if (!header) return;
  header.classList.remove('hidden');
  _analyticsBatchId = batch.id;
  // Keep open state across renders
  const panel = $('analyticsPanel');
  if (panel && !panel.classList.contains('hidden')) {
    renderAnalyticsModule(batch);
  }
}

function renderAnalyticsModule(batch) {
  try { renderAnalyticsKPIs(batch); } catch (e) { console.error('KPIs failed:', e); }
  try { renderAnalyticsGrowthChart(batch); } catch (e) { console.error('Growth chart failed:', e); }
  try { renderAnalyticsBiomassChart(batch); } catch (e) { console.error('Biomass chart failed:', e); }
  try { renderAnalyticsFCRList(batch); } catch (e) { console.error('FCR list failed:', e); }
  try { renderBatchFinance(batch); } catch (e) { console.error('Batch finance failed:', e); }
}

/* ── Per-batch Finance Summary (rendered inside the analytics panel) ── */
function renderBatchFinance(batch) {
  const container = $('batchFinanceSummary');
  if (!container || !batch) return;

  // Use the global finance functions (exposed by the Finance module IIFE)
  const profit = (typeof getBatchProfit === 'function') ? getBatchProfit(batch) : null;
  const proj = (typeof getProjectedRevenue === 'function') ? getProjectedRevenue(batch) : null;
  const fmtC = (typeof fmtCurrency === 'function') ? fmtCurrency : (n) => '₹' + (Number(n) || 0).toFixed(0);
  const fmtCF = (typeof fmtCurrencyFull === 'function') ? fmtCurrencyFull : (n) => '₹' + (Number(n) || 0).toLocaleString('en-IN');

  if (!profit) {
    container.innerHTML = '<div class="bf-empty">Finance data unavailable</div>';
    return;
  }

  const isCompleted = batch.status === 'completed';
  const isActive = batch.status === 'active';

  // Build cost breakdown rows
  const costRows = Object.entries(profit.costs.breakdown)
    .filter(([k, v]) => v > 0)
    .sort((a, b) => b[1] - a[1])
    .map(([cat, amt]) => {
      const labels = { feed: 'Feed', medicine: 'Medicine', fuel: 'Fuel', seed: 'Seed', labor: 'Labor',
        electricity: 'Electricity', maintenance: 'Maintenance', rent: 'Rent', equipment: 'Equipment', other: 'Other' };
      const icons = { feed: '🌾', medicine: '💊', fuel: '⛽', seed: '🦐', labor: '👷',
        electricity: '⚡', maintenance: '🔧', rent: '🏠', equipment: '🛠️', other: '📦' };
      const pct = profit.costs.total > 0 ? (amt / profit.costs.total) * 100 : 0;
      return `
        <div class="bf-cost-row">
          <span class="bf-cost-icon">${icons[cat] || '📦'}</span>
          <span class="bf-cost-name">${labels[cat] || cat}</span>
          <div class="bf-cost-bar-wrap"><div class="bf-cost-bar" style="width:${pct.toFixed(0)}%"></div></div>
          <span class="bf-cost-amt">${fmtC(amt)}</span>
        </div>`;
    }).join('');

  container.innerHTML = `
    <div class="bf-kpi-row">
      <div class="bf-kpi-card ${profit.profit >= 0 ? 'pos' : 'neg'}">
        <div class="bf-kpi-lbl">${isCompleted ? 'Net Profit' : 'Est. Profit'}</div>
        <div class="bf-kpi-val">${fmtCF(isCompleted ? profit.profit : (proj ? proj.projectedRevenue - profit.costs.total : 0))}</div>
      </div>
      <div class="bf-kpi-card">
        <div class="bf-kpi-lbl">Total Cost</div>
        <div class="bf-kpi-val">${fmtCF(profit.costs.total)}</div>
      </div>
      <div class="bf-kpi-card">
        <div class="bf-kpi-lbl">${isCompleted ? 'Revenue' : 'Projected'}</div>
        <div class="bf-kpi-val">${fmtCF(isCompleted ? profit.revenue.total : (proj ? proj.projectedRevenue : 0))}</div>
      </div>
      <div class="bf-kpi-card">
        <div class="bf-kpi-lbl">Break-even</div>
        <div class="bf-kpi-val">${profit.breakEvenPrice > 0 ? '₹' + profit.breakEvenPrice.toFixed(0) + '/kg' : '—'}</div>
      </div>
    </div>

    ${isActive && proj ? `
    <div class="bf-proj-banner">
      <span class="bf-proj-icon">🔮</span>
      <span class="bf-proj-text">Current biomass <b>${proj.biomassKg.toFixed(1)} kg</b> × latest price <b>₹${proj.pricePerKg.toFixed(0)}/kg</b> = <b>${fmtCF(proj.projectedRevenue)}</b></span>
    </div>` : ''}

    ${costRows ? `
    <div class="bf-cost-breakdown">
      <div class="bf-cost-title">Cost Breakdown</div>
      ${costRows}
    </div>` : '<div class="bf-empty">No costs recorded for this batch yet</div>'}

    ${profit.revenue.entries.length ? `
    <div class="bf-sales-title">Sales Recorded</div>
    <div class="bf-sales-list">
      ${profit.revenue.entries.map(r => `
        <div class="bf-sale-row">
          <span class="bf-sale-date">${AppUtils.fmtDateDisplay(r.date)}</span>
          <span class="bf-sale-wt">${Number(r.weightKg).toFixed(1)} kg</span>
          <span class="bf-sale-price">₹${Number(r.pricePerKg).toFixed(0)}/kg</span>
          <span class="bf-sale-tot">${fmtCF(r.totalAmount)}</span>
        </div>
      `).join('')}
    </div>` : (isCompleted ? '' : '<div class="bf-empty" style="margin-top:8px">No sales recorded yet — record a sale from the Finance page when you harvest</div>')}
  `;
}

function getEstimatedPopulation(batch) {
  const hapa = getHapaForBatch(batch.id);
  if (!hapa || hapa.survivalPercent === null || isNaN(hapa.survivalPercent)) return null;
  // L10 fix: clamp survivalPercent to [0, 100] (was accepting negative or >100 values)
  const survivalPct = Math.max(0, Math.min(100, hapa.survivalPercent));
  return Math.round(Number(batch.shrimpCount || 0) * (survivalPct / 100));
}

function calcBiomassKg(population, abwGrams) {
  if (!population || !abwGrams || population <= 0 || abwGrams <= 0) return null;
  return Math.round((population * abwGrams) / 1000 * 10) / 10;
}

function buildGrowthTimeline(batch) {
  const samplings = getSamplingForBatch(batch.id)
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date));

  const growthVis = getGrowthEntriesForBatch(batch.id); // already DOC-sorted asc

  const firstSamplingDate = samplings.length ? samplings[0].date : null;
  const timeline = [];

  // Visual Weight entries — only include those BEFORE first sampling
  growthVis.forEach(g => {
    if (firstSamplingDate && g.date >= firstSamplingDate) return;
    timeline.push({
      date:   g.date,
      doc:    g.doc,
      abw:    g.weightGrams,
      source: 'visual',
      entry:  g
    });
  });

  // Sampling ABW entries
  samplings.forEach(s => {
    timeline.push({
      date:   s.date,
      doc:    s.doc,
      abw:    s.abw,
      source: 'sampling',
      entry:  s
    });
  });

  // Sort by date
  timeline.sort((a, b) => a.date.localeCompare(b.date));
  return timeline;
}

function getFeedInRange(batchId, fromDate, toDate) {
  // Half-open interval (fromDate, toDate] — prevents double-counting
  // feed on shared sampling boundary dates between adjacent FCR periods.
  return records
    .filter(r => r.BatchId === batchId && r.Date > fromDate && r.Date <= toDate)
    .reduce((sum, r) => sum + sumGrams([r]), 0);
}

function getBatchTotalFeedGrams(batchId) {
  return records
    .filter(r => r.BatchId === batchId)
    .reduce((sum, r) => sum + sumGrams([r]), 0);
}

function calcFCRPeriods(batch) {
  const samplings = getSamplingForBatch(batch.id)
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date));

  if (samplings.length < 2) return [];

  const population = getEstimatedPopulation(batch);
  if (!population) return [];

  const periods = [];
  for (let i = 1; i < samplings.length; i++) {
    const prev = samplings[i - 1];
    const curr = samplings[i];

    const prevBiomass = calcBiomassKg(population, prev.abw);
    const currBiomass = calcBiomassKg(population, curr.abw);

    if (prevBiomass === null || currBiomass === null) continue;

    const biomassGainKg = currBiomass - prevBiomass;
    if (biomassGainKg <= 0) {
      // Biomass gain ≤ 0 → FCR undefined; record with warning
      periods.push({
        fromDate: prev.date,
        toDate:   curr.date,
        fromDoc:  prev.doc,
        toDoc:    curr.doc,
        fromAbw:  prev.abw,
        toAbw:    curr.abw,
        feedKg:   getFeedInRange(batch.id, prev.date, curr.date) / 1000,
        biomassGainKg,
        fcr: null,
        warning: 'Biomass gain ≤ 0'
      });
      continue;
    }

    const feedGrams = getFeedInRange(batch.id, prev.date, curr.date);
    const feedKg    = feedGrams / 1000;
    const fcr       = feedKg > 0 ? Math.round((feedKg / biomassGainKg) * 100) / 100 : null;

    periods.push({
      fromDate: prev.date,
      toDate:   curr.date,
      fromDoc:  prev.doc,
      toDoc:    curr.doc,
      fromAbw:  prev.abw,
      toAbw:    curr.abw,
      feedKg,
      biomassGainKg,
      fcr,
      warning: null
    });
  }
  return periods;
}

function getLatestFCR(batch) {
  const periods = calcFCRPeriods(batch);
  if (!periods.length) return null;
  const withFCR = periods.filter(p => p.fcr !== null);
  return withFCR.length ? withFCR[withFCR.length - 1].fcr : null;
}

function getLatestDailyGrowth(batch) {
  const samplings = getSamplingForBatch(batch.id)
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date));
  if (samplings.length >= 2) {
    const last = samplings[samplings.length - 1];
    return last.dailyGrowth !== null ? last.dailyGrowth : null;
  }
  // Fallback to visual growth entries
  const growth = getGrowthEntriesForBatch(batch.id);
  if (growth.length >= 2) {
    const last  = growth[growth.length - 1];
    const prev  = growth[growth.length - 2];
    const days  = last.doc - prev.doc;
    if (days > 0) return Math.round(((last.weightGrams - prev.weightGrams) / days) * 1000) / 1000;
  }
  return null;
}

function renderAnalyticsKPIs(batch) {
  const row = $('analyticsKpiRow');
  if (!row) return;

  const hapa         = getHapaForBatch(batch.id);
  const population   = getEstimatedPopulation(batch);
  const weight       = getPrimaryBatchWeight(batch);
  const abw          = weight ? weight.weightGrams : null;
  const biomassKg    = (population && abw) ? calcBiomassKg(population, abw) : null;
  const fcr          = getLatestFCR(batch);
  const dailyGrowth  = getLatestDailyGrowth(batch);
  const hapaWarn     = !hapa;
  const abwWarn      = !abw;

  const cards = [];

  // ABW card
  cards.push({
    cls:  'an-kpi-card--abw',
    icon: '⚖️',
    lbl:  'Latest ABW',
    val:  abw ? `<span id="anKpiAbwNum">0</span>` : '—',
    sub:  weight ? `${weight.source === 'sampling' ? '🔬 Sampling' : '👁 Visual'} · DOC ${weight.doc}` : '',
    warn: abwWarn ? 'No weight data' : ''
  });

  // Estimated Population
  cards.push({
    cls:  'an-kpi-card--pop',
    icon: '🦐',
    lbl:  'Est. Population',
    val:  population ? `<span id="anKpiPopNum">0</span>` : '—',
    sub:  hapa ? `Hapa: ${hapa.survivalPercent}%` : '',
    warn: hapaWarn ? 'Hapa data needed' : ''
  });

  // Biomass
  cards.push({
    cls:  'an-kpi-card--biomass',
    icon: '🏋️',
    lbl:  'Biomass',
    val:  biomassKg !== null ? `<span id="anKpiBiomassNum">0</span> kg` : '—',
    sub:  biomassKg !== null ? `Pop × ABW / 1000` : '',
    warn: (hapaWarn || abwWarn) && biomassKg === null ? 'Missing Hapa or ABW' : ''
  });

  // FCR
  cards.push({
    cls:  'an-kpi-card--fcr',
    icon: '📊',
    lbl:  'Latest FCR',
    val:  fcr !== null ? `<span id="anKpiFcrNum">0</span>` : '—',
    sub:  fcr !== null ? 'Feed ÷ Biomass Gain' : '',
    warn: fcr === null && getSamplingForBatch(batch.id).length >= 2 ? 'Check FCR periods below' : ''
  });

  // Daily Growth (only show if we have it)
  if (dailyGrowth !== null) {
    const sign = dailyGrowth >= 0 ? '+' : '';
    cards.push({
      cls:  'an-kpi-card--growth',
      icon: '📈',
      lbl:  'Daily Growth',
      val:  `${sign}<span id="anKpiGrowthNum">0</span>g/day`,
      sub:  'ABW growth per day',
      warn: dailyGrowth < 0 ? 'Negative growth observed' : ''
    });
  }

  row.innerHTML = cards.map(c => `
    <div class="an-kpi-card ${c.cls}">
      <span class="an-kpi-icon">${c.icon}</span>
      <div class="an-kpi-lbl">${c.lbl}</div>
      <div class="an-kpi-val">${c.val}</div>
      ${c.sub  ? `<div class="an-kpi-sub">${c.sub}</div>`  : ''}
      ${c.warn ? `<div class="an-kpi-warn">⚠ ${c.warn}</div>` : ''}
    </div>`).join('');

  if (abw) animateValue($('anKpiAbwNum'), abw, 'g');
  if (population) animateValue($('anKpiPopNum'), population, '');
  if (biomassKg !== null) animateValue($('anKpiBiomassNum'), biomassKg, '');
  if (fcr !== null) animateValue($('anKpiFcrNum'), fcr, '');
  if (dailyGrowth !== null) animateValue($('anKpiGrowthNum'), dailyGrowth, '');
}

function renderAnalyticsGrowthChart(batch) {
  const canvas = $('analyticsTrendChart');
  const empty  = $('growthTrendEmpty');
  if (!canvas) return;

  const timeline = buildGrowthTimeline(batch);

  if (timeline.length < 2) {
    canvas.style.display = 'none';
    if (empty) { empty.classList.remove('hidden'); }
    return;
  }

  canvas.style.display = '';
  if (empty) empty.classList.add('hidden');

  // Cache for click detection
  _analyticsChartData = timeline.map(t => ({
    ...t,
    batchId: batch.id
  }));

  requestAnimationFrame(() => drawAnalyticsGrowthCanvas(canvas, timeline, batch));

  // Click handler on canvas
  canvas.onclick = function(e) {
    const rect = canvas.getBoundingClientRect();
    const dpr  = window.devicePixelRatio || 1;
    const mx   = (e.clientX - rect.left);
    const my   = (e.clientY - rect.top);
    // Find nearest point
    if (!canvas._pts) return;
    let nearest = null, minDist = Infinity;
    canvas._pts.forEach((pt, i) => {
      const dx = mx - pt.x, dy = my - pt.y;
      const d  = Math.sqrt(dx * dx + dy * dy);
      if (d < minDist) { minDist = d; nearest = i; }
    });
    if (nearest !== null && minDist < 32) {
      showAnalyticsPointModal(batch, _analyticsChartData[nearest]);
    }
  };
}

function renderAnalyticsBiomassChart(batch) {
  const canvas = $('analyticsBiomassChart');
  const empty  = $('biomassForecastEmpty');
  if (!canvas) return;

  const population = getEstimatedPopulation(batch);
  if (!population) {
    canvas.style.display = 'none';
    if (empty) { empty.classList.remove('hidden'); }
    return;
  }

  const samplings = getSamplingForBatch(batch.id)
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date));

  if (!samplings.length) {
    canvas.style.display = 'none';
    if (empty) { empty.textContent = 'Biomass requires Sampling ABW data.'; empty.classList.remove('hidden'); }
    return;
  }

  canvas.style.display = '';
  if (empty) empty.classList.add('hidden');

  // Build biomass timeline from samplings
  const bioTimeline = samplings.map(s => ({
    doc:       s.doc,
    date:      s.date,
    biomassKg: calcBiomassKg(population, s.abw),
    abw:       s.abw
  })).filter(b => b.biomassKg !== null);

  if (!bioTimeline.length) {
    canvas.style.display = 'none';
    if (empty) { empty.classList.remove('hidden'); }
    return;
  }

  // Forecast projection
  let projected = [];
  if (batch.status === 'active' && bioTimeline.length >= 1) {
    const lastB    = bioTimeline[bioTimeline.length - 1];
    const dailyG   = getLatestDailyGrowth(batch) || 0;
    for (let d = 1; d <= 21; d++) {
      const futureAbw      = Math.max(0.001, lastB.abw + dailyG * d);
      const futureBiomass  = calcBiomassKg(population, futureAbw);
      projected.push({ doc: lastB.doc + d, biomassKg: futureBiomass });
    }
  }

  requestAnimationFrame(() => drawBiomassCanvas(canvas, bioTimeline, projected, { instant: true }));
}

function renderAnalyticsFCRList(batch) {
  const list = $('analyticsFcrList');
  if (!list) return;

  const periods = calcFCRPeriods(batch);

  if (!periods.length) {
    const hapa = getHapaForBatch(batch.id);
    const samplings = getSamplingForBatch(batch.id);
    let msg = 'FCR requires at least 2 sampling entries and Hapa data.';
    if (!hapa) msg = '⚠ Hapa data needed to calculate FCR.';
    else if (samplings.length < 2) msg = 'FCR requires at least 2 sampling entries.';
    list.innerHTML = `<div class="an-fcr-empty">${msg}</div>`;
    return;
  }

  list.innerHTML = periods.map(p => {
    const fcrDisplay = p.fcr !== null
      ? `<span class="an-fcr-val">${p.fcr.toFixed(2)}</span>`
      : `<span style="color:var(--amber);font-weight:700">N/A</span>`;
    const detail = p.fcr !== null
      ? `Feed: ${p.feedKg.toFixed(2)} kg · Gain: +${p.biomassGainKg.toFixed(1)} kg`
      : (p.warning || '');
    return `<div class="an-fcr-row">
      <div>
        <div class="an-fcr-period">DOC ${p.fromDoc} → ${p.toDoc}</div>
        <div class="an-fcr-detail">${detail}</div>
      </div>
      <div style="text-align:right">
        ${fcrDisplay}
        <div class="an-fcr-detail">${fmtDateDisplay(p.fromDate)} – ${fmtDateDisplay(p.toDate)}</div>
      </div>
    </div>`;
  }).join('');
}

function showAnalyticsPointModal(batch, point) {
  const modal   = $('analyticsPointModal');
  const title   = $('analyticsPointTitle');
  const content = $('analyticsPointContent');
  if (!modal || !content) return;

  const hapa       = getHapaForBatch(batch.id);
  const population = getEstimatedPopulation(batch);
  const biomassKg  = (population && point.abw) ? calcBiomassKg(population, point.abw) : null;
  const feedOnDay  = getFeedInRange(batch.id, point.date, point.date);

  // FCR for this point's period (if sampling)
  let fcrStr = '—';
  if (point.source === 'sampling' && hapa) {
    const periods = calcFCRPeriods(batch);
    const matchPeriod = periods.find(p => p.toDate === point.date);
    if (matchPeriod && matchPeriod.fcr !== null) {
      fcrStr = matchPeriod.fcr.toFixed(2);
    }
  }

  title.textContent = point.source === 'sampling' ? '🔬 Sampling Detail' : '👁 Visual Weight Detail';

  const rows = [
    { lbl: 'Date',         val: fmtDateDisplay(point.date),              cls: '' },
    { lbl: 'DOC',          val: `Day ${point.doc}`,                      cls: '' },
    { lbl: 'ABW',          val: fmtWeightG(point.abw),                   cls: 'an-point-val--teal' },
    { lbl: 'Source',       val: point.source === 'sampling' ? 'Sampling ABW' : 'Visual Estimate', cls: '' },
    { lbl: 'Est. Pop.',    val: population ? fmtShrimpCount(population) + ' shrimp' : '—', cls: '' },
    { lbl: 'Biomass',      val: biomassKg !== null ? biomassKg.toLocaleString() + ' kg' : '—', cls: 'an-point-val--purple' },
    { lbl: 'Feed (day)',   val: feedOnDay > 0 ? fmtGrams(feedOnDay) + 'g' : '—',          cls: '' },
    { lbl: 'FCR (period)', val: fcrStr,                                   cls: fcrStr !== '—' ? 'an-point-val--amber' : '' },
  ];

  if (point.source === 'sampling' && point.entry) {
    const s = point.entry;
    if (s.dailyGrowth !== null) {
      const sign = s.dailyGrowth >= 0 ? '+' : '';
      rows.push({ lbl: 'Daily Growth', val: `${sign}${s.dailyGrowth}g/day`, cls: s.dailyGrowth >= 0 ? 'an-point-val--teal' : 'an-point-val--amber' });
    }
    if (s.notes) rows.push({ lbl: 'Notes', val: escapeHTML(s.notes), cls: '' });
  }

  content.innerHTML = rows
    .filter(r => r.val !== undefined)
    .map(r => `<div class="an-point-row">
      <span class="an-point-lbl">${r.lbl}</span>
      <span class="an-point-val ${r.cls}">${r.val}</span>
    </div>`).join('');

  modal.classList.remove('hidden');

  // Overlay click — funnels through closeModal for Escape-key consistency.
  // 3-f fix: remove the PREVIOUS listener BEFORE assigning a new function
  // reference. Previously the assignment ran first, so removeEventListener
  // matched the NEW (not-yet-added) function and the OLD listener leaked —
  // one extra closeModal call per modal open.
  modal.removeEventListener('click', modal._analyticsCloseOnOutside);
  modal._analyticsCloseOnOutside = function(e) {
    if (e.target === modal) closeModal('analyticsPointModal');
  };
  modal.addEventListener('click', modal._analyticsCloseOnOutside);
}

function showBarDetailModal(meta, accentColor) {
  const modal   = $('barDetailModal');
  const title   = $('barDetailTitle');
  const content = $('barDetailContent');
  if (!modal || !content || !meta) return;

  const color = accentColor || '#00d4aa';

  // Build rows depending on chart type
  let rows = [];
  let titleText = '';

  if (meta.type === 'farm-day') {
    titleText = `📅 ${meta.dateLabel}`;
    const totalFeed = meta.feedDist ? meta.feedDist.reduce((s,f) => s + f.value, 0) : 0;
    rows = [
      { lbl: 'Date',     val: meta.dateLabel,                           cls: '' },
      { lbl: 'Total Feed', val: totalFeed > 0 ? fmtGrams(totalFeed) + 'g' : '—', cls: 'bd-val--accent', accent: color },
      { lbl: 'Sessions', val: meta.sessions > 0 ? meta.sessions : '—', cls: '' },
      { lbl: 'Ponds Fed', val: meta.ponds && meta.ponds.length ? meta.ponds.join(', ') : '—', cls: '' },
    ];
    if (meta.feedDist && meta.feedDist.length) {
      meta.feedDist.forEach(f => {
        rows.push({ lbl: f.label, val: fmtGrams(f.value) + 'g', cls: '', dot: f.color });
      });
    }
    if (totalFeed === 0) rows.push({ lbl: 'Note', val: 'No feed logged this day', cls: 'bd-val--dim' });

  } else if (meta.type === 'monthly-week') {
    titleText = `📆 ${meta.weekLabel}`;
    const totalFeed = meta.feedDist ? meta.feedDist.reduce((s,f) => s + f.value, 0) : 0;
    rows = [
      { lbl: 'Period',   val: meta.weekLabel || `Week ${meta.weekNum}`, cls: '' },
      { lbl: 'Total Feed', val: totalFeed > 0 ? fmtGrams(totalFeed) + 'g' : '—', cls: 'bd-val--accent', accent: color },
      { lbl: 'Sessions', val: meta.sessions > 0 ? meta.sessions : '—', cls: '' },
      { lbl: 'Ponds Fed', val: meta.ponds && meta.ponds.length ? meta.ponds.join(', ') : '—', cls: '' },
    ];
    if (meta.feedDist && meta.feedDist.length) {
      meta.feedDist.forEach(f => {
        rows.push({ lbl: f.label, val: fmtGrams(f.value) + 'g', cls: '', dot: f.color });
      });
    }
    if (totalFeed === 0) rows.push({ lbl: 'Note', val: 'No feed logged this week', cls: 'bd-val--dim' });

  } else if (meta.type === 'batch-doc') {
    titleText = `🦐 ${meta.batchName || 'Batch'} · DOC ${meta.docNumber}`;
    const totalFeed = meta.feedDist ? meta.feedDist.reduce((s,f) => s + f.value, 0) : 0;
    rows = [
      { lbl: 'Date',       val: meta.dateLabel || meta.dateStr || '—',  cls: '' },
      { lbl: 'Batch',      val: meta.batchName || '—',                   cls: '' },
      { lbl: 'Pond',       val: meta.pond || '—',                        cls: '' },
      { lbl: 'DOC',        val: `Day ${meta.docNumber}`,                 cls: '' },
      { lbl: 'Total Feed', val: totalFeed > 0 ? fmtGrams(totalFeed) + 'g' : '—', cls: 'bd-val--accent', accent: color },
      { lbl: 'Sessions',   val: meta.sessions > 0 ? meta.sessions : '—', cls: '' },
    ];
    if (meta.feedDist && meta.feedDist.length) {
      meta.feedDist.forEach(f => {
        rows.push({ lbl: f.label, val: fmtGrams(f.value) + 'g', cls: '', dot: f.color });
      });
    }
    if (totalFeed === 0) rows.push({ lbl: 'Note', val: 'No feed logged this DOC', cls: 'bd-val--dim' });
  }

  if (title) title.textContent = titleText;

  content.innerHTML = rows.map(r => {
    const dotHTML = r.dot ? `<span class="bd-dot" style="background:${r.dot}"></span>` : '';
    const valStyle = r.accent ? `style="color:${r.accent}"` : '';
    return `<div class="an-point-row">
      <span class="an-point-lbl">${dotHTML}${r.lbl}</span>
      <span class="an-point-val ${r.cls}" ${valStyle}>${r.val}</span>
    </div>`;
  }).join('');

  // Accent the modal header line
  const handle = modal.querySelector('.bd-accent-line');
  if (handle) handle.style.background = color;

  modal.classList.remove('hidden');

  // Overlay click — funnels through closeModal for Escape-key consistency.
  // 3-f fix: remove the PREVIOUS listener BEFORE assigning a new function
  // reference (see showAnalyticsPointModal for full explanation).
  modal.removeEventListener('click', modal._closeOnOutside);
  modal._closeOnOutside = function(e) {
    if (e.target === modal) closeModal('barDetailModal');
  };
  modal.addEventListener('click', modal._closeOnOutside);
}

// Window bindings for backward compatibility
window.getBatchCycleLength = getBatchCycleLength;
window.getBatchFeedDataForDOC = getBatchFeedDataForDOC;
window.getBatchTotalFeed = getBatchTotalFeed;
window.formatTotalFeed = formatTotalFeed;
window.renderBatchDashboard = renderBatchDashboard;
window.openViewBatchModal = openViewBatchModal;
window.renderBatchDailyFeedSummary = renderBatchDailyFeedSummary;
window.getActiveBatchForPond = getActiveBatchForPond;
window.getNextBatchNumber = getNextBatchNumber;
window.saveBatches = saveBatches;
window.saveHapaEntries = saveHapaEntries;
window.getHapaForBatch = getHapaForBatch;
window.batchNeedsHapa = batchNeedsHapa;
window.hapaReminderCount = hapaReminderCount;
window.openHapaEntryModal = openHapaEntryModal;
window.doSaveHapa = doSaveHapa;
window.getHapaBadgeHTML = getHapaBadgeHTML;
window.validateBatchCreateData = validateBatchCreateData;
window.validateBatchCompletionData = validateBatchCompletionData;
window.findBatchForDate = findBatchForDate;
window.openCreateBatchModal = openCreateBatchModal;
window.doCreateBatch = doCreateBatch;
window.openCompleteBatchModal = openCompleteBatchModal;
window.doCompleteBatch = doCompleteBatch;
window.renderCompletedBatches = renderCompletedBatches;
window.getSamplingForBatch = getSamplingForBatch;
window.getLatestSamplingForBatch = getLatestSamplingForBatch;
window.getPrimaryBatchWeight = getPrimaryBatchWeight;
window.getDaysAgoDisplay = getDaysAgoDisplay;
window.updateBatchBiomassEstimation = updateBatchBiomassEstimation;
window.batchNeedsSampling = batchNeedsSampling;
window.samplingReminderCount = samplingReminderCount;
window.getSamplingStatusText = getSamplingStatusText;
window.getSamplingBadgeHTML = getSamplingBadgeHTML;
window.openSamplingModal = openSamplingModal;
window.launchSampling = launchSampling;
window.updateSamplingDocDisplay = updateSamplingDocDisplay;
window.updateSamplingLiveAbw = updateSamplingLiveAbw;
window.doSaveSampling = doSaveSampling;
window.recalcSamplingGrowthForBatch = recalcSamplingGrowthForBatch;
window.deleteSamplingEntry = deleteSamplingEntry;
window.renderBatchSamplingCard = renderBatchSamplingCard;
window.toggleSamplingHistory = toggleSamplingHistory;
window.renderSamplingDashboardWarning = renderSamplingDashboardWarning;
window.jumpToBatchDashboard = jumpToBatchDashboard;
window.renderBatchSamplingOverview = renderBatchSamplingOverview;
window.saveBiomassEntries = saveBiomassEntries;
window.getGrowthEntriesForBatch = getGrowthEntriesForBatch;
window.reRenderCurrentBatch = reRenderCurrentBatch;
window.renderBatchGrowthCard = renderBatchGrowthCard;
window.toggleWeightHistory = toggleWeightHistory;
window.renderGrowthFeedTrendChart = renderGrowthFeedTrendChart;
window.openEditGrowthEntry = openEditGrowthEntry;
window.updateGrowthDocBadge = updateGrowthDocBadge;
window.doLogWeight = doLogWeight;
window.deleteGrowthEntry = deleteGrowthEntry;
window.saveGrowthEntries = saveGrowthEntries;
window.getBiomassVbsRowsHTML = getBiomassVbsRowsHTML;
window.openLogWeightModal = openLogWeightModal;
window.openEditBatchModal = openEditBatchModal;
window.doSaveEditBatch = doSaveEditBatch;
window.applyBatchEdit = applyBatchEdit;
window.saveSamplingEntries = saveSamplingEntries;
window.toggleAnalyticsPanel = toggleAnalyticsPanel;
window.renderAnalyticsTabHeader = renderAnalyticsTabHeader;
window.renderAnalyticsModule = renderAnalyticsModule;
window.getEstimatedPopulation = getEstimatedPopulation;
window.calcBiomassKg = calcBiomassKg;
window.buildGrowthTimeline = buildGrowthTimeline;
window.getFeedInRange = getFeedInRange;
window.getBatchTotalFeedGrams = getBatchTotalFeedGrams;
window.calcFCRPeriods = calcFCRPeriods;
window.getLatestFCR = getLatestFCR;
window.getLatestDailyGrowth = getLatestDailyGrowth;
window.renderAnalyticsKPIs = renderAnalyticsKPIs;
window.renderAnalyticsGrowthChart = renderAnalyticsGrowthChart;
window.renderAnalyticsBiomassChart = renderAnalyticsBiomassChart;
window.renderAnalyticsFCRList = renderAnalyticsFCRList;
window.showAnalyticsPointModal = showAnalyticsPointModal;
window.showBarDetailModal = showBarDetailModal;

// MODAL_STATE_CLEANUP Registrations
window.MODAL_STATE_CLEANUP = window.MODAL_STATE_CLEANUP || {};
window.MODAL_STATE_CLEANUP.createBatchModal = () => { createBatchForPondId = null; };
window.MODAL_STATE_CLEANUP.editBatchModal = () => { editBatchId = null; editBatchPendingData = null; };
window.MODAL_STATE_CLEANUP.batchDateWarnModal = () => { editBatchPendingData = null; };
window.MODAL_STATE_CLEANUP.completeBatchModal = () => { batchToComplete = null; };
})();

// --- Module: feed.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

function validateFeedQuantitiesForSave(checked) {
  if (!checked.length) return { ok: false, message: 'Select at least one feed type' };

  for (const id of checked.filter(id => id !== 'other')) {
    const inp = $(`qty_${id}`);
    if (!inp || !isPositiveNumberField(inp.value)) {
      return { ok: false, message: 'Feed quantities must be greater than zero.', fieldId: inp ? inp.id : null };
    }
  }

  if (checked.includes('other')) {
    if (!$('otherFeedName').value.trim()) {
      return { ok: false, message: 'Other feed name is required.', fieldId: 'otherFeedName' };
    }
    if (!isPositiveNumberField($('otherFeedQty').value)) {
      return { ok: false, message: 'Feed quantities must be greater than zero.', fieldId: 'otherFeedQty' };
    }
  }

  return { ok: true };
}

function renderFeedGrid() {
  const grid = $('feedGrid');
  grid.innerHTML = '';
  FEED_SIZES.forEach(f => {
    const lbl = document.createElement('label');
    lbl.className = 'fc-label';
    lbl.dataset.id = f.id;
    const displayText = f.label.replace('Feed ', '');
    lbl.innerHTML = `<input type="checkbox" value="${f.id}" id="cb_${f.id}"/><span class="fc-text">${displayText}</span>`;
    grid.appendChild(lbl);
    lbl.querySelector('input').addEventListener('change', onFeedChange);
  });
}

function onFeedChange() {
  $('feedGrid').querySelectorAll('.fc-label').forEach(l => {
    l.classList.toggle('checked', l.querySelector('input').checked);
  });
  renderQtyInputs();
  $('errFeed').classList.remove('show');
}

function renderQtyInputs() {
  const sec    = $('qtySection');
  
  // Cache current input values before clearing
  const savedVals = {};
  sec.querySelectorAll('.qty-input').forEach(inp => {
    savedVals[inp.id] = inp.value;
  });
  
  sec.innerHTML = '';
  const checked = getCheckedIds();

  const pondId = $('pondSelect').value;
  const feedDate = $('feedDate').value;
  const matchedBatch = (pondId && feedDate) ? findBatchForDate(pondId, feedDate) : null;
  const batchId = matchedBatch ? matchedBatch.id : null;

  checked.filter(id => id !== 'other').forEach(id => {
    const f   = FEED_SIZES.find(x => x.id === id);
    const row = document.createElement('div');
    row.className = 'qty-row';
    
    const sizeIdx = FEED_SIZES.findIndex(x => x.id === id) + 1;
    const prevQty = getPreviousFeedQuantity(batchId, sizeIdx);
    
    let inputVal = '';
    if (savedVals[`qty_${id}`] !== undefined) {
      inputVal = savedVals[`qty_${id}`];
    } else if (prevQty !== null) {
      inputVal = prevQty;
    }
    
    row.innerHTML = `
      <div class="qty-label-col" style="display:flex; flex-direction:column; gap:2px; min-width:88px; flex-shrink:0;">
        <label class="qty-label" for="qty_${id}" style="min-width:unset; padding:0;">${f.label}</label>
        <span class="qty-prev" id="prev_${id}" style="font-size:0.72rem; color:var(--t3); display:none; line-height:1.2;"></span>
      </div>
      <div class="qty-input-col" style="display:flex; flex-direction:column; flex:1;">
        <input class="qty-input" type="number" id="qty_${id}" value="${inputVal}" inputmode="numeric" min="1" max="99999" placeholder="e.g. 200"/>
        <span class="qty-adj" id="adj_${id}" style="font-size:0.72rem; font-weight:600; text-align:right; margin-top:2px; height:12px; display:block; line-height:1.2;"></span>
      </div>
      <span class="qty-unit" style="align-self:center; margin-bottom:12px;">g</span>`;
    sec.appendChild(row);
    row.querySelector(`#qty_${id}`).addEventListener('input', function(){
      this.classList.remove('err');
      const prevQty = this.dataset.prevQty ? +this.dataset.prevQty : null;
      updateAdjustmentIndicator(id, prevQty);
    });
  });

  const hasOther = checked.includes('other');
  showHide($('otherNameGroup'), hasOther);
  showHide($('otherQtyGroup'),  hasOther);
  
  if (hasOther) {
    const prevOther = getPreviousOtherFeed(batchId);
    if (prevOther) {
      if ($('otherFeedName').value === '') {
        $('otherFeedName').value = prevOther.name;
      }
      if ($('otherFeedQty').value === '') {
        $('otherFeedQty').value = prevOther.qty;
      }
    }
  }

  refreshPreviousFeedReferences();
}

function getCheckedIds() {
  return [...$('feedGrid').querySelectorAll('input:checked')].map(c => c.value);
}

function getSuggestedFeedingTime() {
  const now = new Date();
  const hours = now.getHours();
  if (hours < 9) {
    return '7:00 AM';
  } else if (hours < 14) {
    return '11:00 AM';
  } else if (hours < 18) {
    return '4:00 PM';
  } else {
    return '7:00 PM';
  }
}

function setSuggestedFeedTime() {
  isSettingSuggestedTime = true;
  const suggested = getSuggestedFeedingTime();
  $('feedTime').value = suggested;
  $('feedTime').dispatchEvent(new Event('change', { bubbles: true }));
  alSelects.feedTime?.sync();
  isSettingSuggestedTime = false;
}

function getRecordTimestamp(rec) {
  if (rec._ts) {
    return new Date(rec._ts).getTime();
  }
  if (rec.Date && rec.Time) {
    let timeStr = rec.Time;
    let hours = 0;
    let minutes = 0;
    const match = timeStr.match(/^(\d+):(\d+)\s*(AM|PM)$/i);
    if (match) {
      hours = +match[1];
      minutes = +match[2];
      const ampm = match[3].toUpperCase();
      if (ampm === 'PM' && hours < 12) hours += 12;
      if (ampm === 'AM' && hours === 12) hours = 0;
    }
    const d = new Date(rec.Date + 'T' + String(hours).padStart(2,'0') + ':' + String(minutes).padStart(2,'0') + ':00');
    return d.getTime();
  }
  return 0;
}

function getPreviousRecord(batchId) {
  if (!batchId) return null;
  const batchRecs = records.filter(r => r.BatchId === batchId);
  if (batchRecs.length === 0) return null;
  batchRecs.sort((a, b) => getRecordTimestamp(b) - getRecordTimestamp(a));
  return batchRecs[0];
}

function getPreviousFeedQuantity(batchId, sizeIndex) {
  const prevRec = getPreviousRecord(batchId);
  if (!prevRec) return null;
  const key = `Feed Size ${sizeIndex} Gram`;
  const val = prevRec[key];
  return (val !== undefined && val !== null && val !== '' && +val > 0) ? +val : null;
}

function updateAdjustmentIndicator(id, prevQty) {
  const inp = $(`qty_${id}`);
  const adj = $(`adj_${id}`);
  if (!inp || !adj) return;
  if (prevQty === null || prevQty === undefined) {
    adj.textContent = '';
    return;
  }
  const val = inp.value.trim();
  if (val === '') {
    adj.textContent = '';
    return;
  }
  const current = +val;
  if (isNaN(current) || current <= 0) {
    adj.textContent = '';
    return;
  }
  const diff = current - prevQty;
  if (diff === 0) {
    adj.textContent = '';
  } else if (diff > 0) {
    adj.textContent = `+${diff}g`;
    adj.style.color = 'var(--green)';
  } else {
    adj.textContent = `${diff}g`;
    adj.style.color = 'var(--red)';
  }
}

function refreshPreviousFeedReferences() {
  const pondId = $('pondSelect').value;
  const feedDate = $('feedDate').value;
  const matchedBatch = (pondId && feedDate) ? findBatchForDate(pondId, feedDate) : null;
  const batchId = matchedBatch ? matchedBatch.id : null;
  
  FEED_SIZES.filter(x => x.id !== 'other').forEach((f, i) => {
    const id = f.id;
    const prevLabel = $(`prev_${id}`);
    const adjLabel = $(`adj_${id}`);
    const inp = $(`qty_${id}`);
    if (!prevLabel || !adjLabel) return;
    
    const prevQty = getPreviousFeedQuantity(batchId, i + 1);
    if (prevQty !== null) {
      prevLabel.textContent = `Prev: ${prevQty}g`;
      prevLabel.style.display = 'block';
      if (inp) {
        inp.dataset.prevQty = prevQty;
        updateAdjustmentIndicator(id, prevQty);
      }
    } else {
      prevLabel.style.display = 'none';
      prevLabel.textContent = '';
      adjLabel.textContent = '';
      if (inp) {
        delete inp.dataset.prevQty;
      }
    }
  });
}

function getPreviousOtherFeed(batchId) {
  const prevRec = getPreviousRecord(batchId);
  if (!prevRec) return null;
  const name = prevRec['Other Feed Name'];
  const qty = prevRec['Other Feed Gram'];
  return (name && qty && +qty > 0) ? { name, qty: +qty } : null;
}

function autoSelectPreviousFeedSizes() {
  const pondId = $('pondSelect').value;
  const feedDate = $('feedDate').value;
  const matchedBatch = (pondId && feedDate) ? findBatchForDate(pondId, feedDate) : null;
  const batchId = matchedBatch ? matchedBatch.id : null;
  
  // Clear the qtySection innerHTML so savedVals will be empty when changing pond/date context
  const sec = $('qtySection');
  if (sec) sec.innerHTML = '';
  
  // Uncheck everything first
  FEED_SIZES.forEach(f => {
    const cb = $(`cb_${f.id}`);
    if (cb) cb.checked = false;
  });

  if (batchId) {
    const batchRecs = records.filter(r => r.BatchId === batchId);
    if (batchRecs.length > 0) {
      batchRecs.sort((a, b) => getRecordTimestamp(b) - getRecordTimestamp(a));
      const latestRec = batchRecs[0];
      
      FEED_SIZES.forEach((f, i) => {
        const cb = $(`cb_${f.id}`);
        if (!cb) return;
        
        if (f.id === 'other') {
          if (latestRec['Other Feed Gram'] && latestRec['Other Feed Gram'] > 0) {
            cb.checked = true;
          }
        } else {
          const key = `Feed Size ${i + 1} Gram`;
          if (latestRec[key] && latestRec[key] > 0) {
            cb.checked = true;
          }
        }
      });
    }
  }
  
  onFeedChange();
}

function setDefaultDate() {
  const t   = new Date();
  const yyyy = t.getFullYear();
  const mm   = String(t.getMonth()+1).padStart(2,'0');
  const dd   = String(t.getDate()).padStart(2,'0');
  const today = `${yyyy}-${mm}-${dd}`;
  $('feedDate').value = today;
  $('feedDate').max = today;
}

function bindFormEvents() {
  $('feedTime').addEventListener('change', function(){
    showHide($('customTimeGroup'), this.value === 'Other');
    $('errTime').classList.remove('show');
    if (!isSettingSuggestedTime) {
      isTimeManuallySelected = true;
    }
  });

  // CHANGE 4: Re-render pond select when date changes (historical batch matching)
  $('feedDate').addEventListener('change', () => {
    renderLogPondSelect();
    updateNoBatchWarning();
    autoSelectPreviousFeedSizes();
  });

  $('feedForm').addEventListener('submit', handleSubmit);

  $('pondSelect').addEventListener('change', () => {
    $('errPond').classList.remove('show');
    $('pondSelect').classList.remove('err');
    updateNoBatchWarning();
    autoSelectPreviousFeedSizes();
  });

  $('sheetsToggle').addEventListener('click', () => {
    const body = $('sheetsBody');
    const isOpen = body.classList.toggle('open');
    $('sheetsToggle').setAttribute('aria-expanded', isOpen);
    body.classList.remove('hidden');
  });
  $('sheetsToggle').addEventListener('keydown', e => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      $('sheetsToggle').click();
    }
  });
  
  const medToggle = $('medicineToggle');
  if (medToggle) {
    medToggle.addEventListener('click', () => {
      const body = $('medicineBody');
      if (body) {
        const isOpen = body.classList.toggle('open');
        medToggle.setAttribute('aria-expanded', isOpen);
        body.classList.remove('hidden');
      }
    });
    medToggle.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        medToggle.click();
      }
    });
  }
  $('sheetsSaveBtn').addEventListener('click', saveSheetsUrl);

  $('apiSyncToggle').addEventListener('click', () => {
    const body = $('apiSyncBody');
    const isOpen = body.classList.toggle('open');
    $('apiSyncToggle').setAttribute('aria-expanded', isOpen);
    body.classList.remove('hidden');
  });
  $('apiSyncToggle').addEventListener('keydown', e => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      $('apiSyncToggle').click();
    }
  });
  $('apiSaveBtn').addEventListener('click', saveApiSettings);

  window.addEventListener('beforeunload', e => {
    if (formHasData()) { e.preventDefault(); e.returnValue=''; }
  });
}

async function handleSubmit(e) {
  e.preventDefault();
  if (!validate()) {
    scrollToError();
    // 3-h fix: surface a clear ERROR toast on validation failure. Previously,
    // validate() only marked inline field errors and handleSubmit returned
    // silently — combined with the static "Saved!" default toast text in
    // body.html (#toastTitle), the user got no visible feedback and the empty
    // toast text could be mistaken for a silent success. Now we pick the most
    // relevant message based on what's actually missing.
    const _missingPond = !$('pondSelect')?.value;
    const _checkedIds  = getCheckedIds();
    const _feedCheck   = validateFeedQuantitiesForSave(_checkedIds);
    let _toastTitle, _toastMsg;
    if (_missingPond && _checkedIds.length === 0) {
      _toastTitle = 'Pond & feed required';
      _toastMsg   = 'Select a pond and check at least one feed size.';
    } else if (_missingPond) {
      _toastTitle = 'Pond required';
      _toastMsg   = 'Please select a pond before logging feed.';
    } else if (_checkedIds.length === 0) {
      _toastTitle = 'Feed required';
      _toastMsg   = 'Check at least one feed size and enter a quantity.';
    } else if (!_feedCheck.ok) {
      _toastTitle = 'Feed quantity required';
      _toastMsg   = _feedCheck.message;
    } else {
      _toastTitle = 'Check form';
      _toastMsg   = 'Please correct the highlighted errors and try again.';
    }
    showToast('❌', _toastTitle, _toastMsg);
    return;
  }

  const key = `${$('feedDate').value}_${getTime()}_${$('pondSelect').value}`;
  if (key === lastKey && !dupConfirm) {
    $('dupWarn').classList.remove('hidden');
    dupConfirm = true;
    return;
  }
  $('dupWarn').classList.add('hidden');
  dupConfirm = false;
  lastKey    = key;

  const rec = buildRecord();
  if (!rec) return; // buildRecord returns null if no active batch (extra safety)

  // --- FIX 1: Prevent Negative Stock ---
  const stockCheck = window.InventoryManager.checkFeedLogStockSufficiency(rec);
  if (!stockCheck.ok) {
    showToast('⚠️', 'Insufficient Inventory', stockCheck.message);
    setLoading(false);
    return;
  }

  /* ── Attach medicine/supplement entries (non-breaking addition) ── */
  rec.medicineLog = (typeof window.getMedicineEntries === 'function')
    ? window.getMedicineEntries()
    : [];

  if (isDuplicateRecord(rec)) {
    showToast('⚠️', 'This feed entry already exists.', '');
    return;
  }

  setLoading(true);

  const sheetsUrl = AppStorage.getSheetsUrl();
  const apiUrl    = AppStorage.getApiSettings().url;

  rec._syncedSheets = false;
  rec._syncedApi = false;

  let syncedSheets = false;
  let syncedApi = false;

  if (navigator.onLine) {
    if (sheetsUrl) {
      syncedSheets = await postToSheets(rec, sheetsUrl);
      rec._syncedSheets = syncedSheets;
    }
    if (apiUrl) {
      syncedApi = await postToCustomApi(rec);
      rec._syncedApi = syncedApi;
    }
  }

  const needsSheetsSync = sheetsUrl && !rec._syncedSheets;
  const needsApiSync = apiUrl && !rec._syncedApi;

  if (!navigator.onLine || needsSheetsSync || needsApiSync) {
    offlineQ.push(rec);
    AppStorage.saveQueue(offlineQ);
  }

  rec._ts = new Date().toISOString();
  records.push(rec);
  AppStorage.saveRecords(records);
  if (typeof window.InventoryManager === 'object') window.InventoryManager.syncFeedConsumption(rec);

  // C4 fix: commit deferred medicine/supplement consumption transactions now that
  // the record is saved. Previously these were created at add-time and orphaned
  // if the user abandoned the form. Now they're created here, linked via rec.id,
  // and their txIds are stored on rec.medicineLog for later reversal on delete.
  try {
    if (Array.isArray(rec.medicineLog) && rec.medicineLog.length > 0 && window.InventoryManager) {
      const _medPond = window.AppStorage.getPonds().find(p => p.id === rec.PondId);
      const _medSiteId = _medPond?.siteId || null;
      if (_medSiteId) {
        rec.medicineLog.forEach(entry => {
          if (entry.fromInventory && entry.name) {
            const _medResult = window.InventoryManager.createTransaction({
              siteId       : _medSiteId,
              type         : 'consumption',
              category     : 'medicine',
              itemName     : entry.name,
              purchaseDate : rec.Date || new Date().toISOString().slice(0, 10),
              supplier     : '',
              quantity     : entry.quantity,
              unit         : entry.unit || '',
              unitPrice    : 0,
              referenceNumber: 'med_' + rec.id,
              notes        : 'Deducted via Feed Log — Medicine/Supplement entry',
              details      : { source: 'feed_log_medicine', recordId: rec.id },
            });
            if (_medResult.success) {
              entry.txId = _medResult.transaction.id;
            }
          }
        });
        AppStorage.saveRecords(records); // re-save with committed txIds
      }
    }
  } catch (e) {
    console.error('[AquaLog] Medicine consumption commit failed (non-fatal):', e);
  }

  setLoading(false);
  updateQueueUI();

  const subParts = [];
  if (sheetsUrl && rec._syncedSheets) subParts.push('Sheets');
  if (apiUrl && rec._syncedApi) subParts.push('API');

  const sub = subParts.length > 0
    ? `Synced to ${subParts.join(' & ')}`
    : !navigator.onLine
      ? 'Saved locally · queued for sync'
      : (sheetsUrl || apiUrl)
        ? 'Saved locally · queued for sync'
        : 'Saved locally';
  celebrateSuccess();
  showToast('✅', 'Entry Logged!', sub);
  flashElement($('feedForm'));
  resetForm();
  updateExportCount();

  // C1 fix: moved from dead monkey-patch. Previously the bootstrapper reassigned
  // window.handleSubmit after bindFormEvents had already captured the IIFE-local
  // handleSubmit reference, so these two calls never ran. Now they run inline.
  try { checkFeedBrandExistence(rec); } catch(_) {}
  try { refreshActiveInventoryPage(); } catch(_) {}
}

function validate() {
  let ok = true;
  function check(cond, errId, fieldId) {
    if (!cond) { $(errId).classList.add('show'); if(fieldId) $(fieldId)?.classList.add('err'); ok=false; }
    else       { $(errId).classList.remove('show'); if(fieldId) $(fieldId)?.classList.remove('err'); }
  }
  const feedDateVal = $('feedDate').value;
  clearFieldError('errDate', 'feedDate', 'Required');
  if (!feedDateVal) {
    showFieldError('errDate', 'feedDate', 'Required');
    ok = false;
  } else if (isFutureDateStr(feedDateVal)) {
    showFieldError('errDate', 'feedDate', 'Feed date cannot be in the future.');
    ok = false;
  }
  check($('feedTime').value,    'errTime', 'feedTime');
  if ($('feedTime').value === 'Other')
    check($('customTime').value, 'errCustomTime', 'customTime');

  const pondId = $('pondSelect').value;
  check(pondId, 'errPond', 'pondSelect');

  // CHANGE 4: Validate that a batch existed on the SELECTED DATE
  if (pondId && $('feedDate').value) {
    const matched = findBatchForDate(pondId, $('feedDate').value);
    if (!matched) {
      $('errPond').textContent = 'No batch existed for this pond on the selected date.';
      $('errPond').classList.add('show');
      $('pondSelect').classList.add('err');
      ok = false;
    } else {
      $('errPond').textContent = 'Please select a pond';
    }
  } else if (pondId) {
    // No date yet — fall back to active batch check for UX
    const activeBatch = getActiveBatchForPond(pondId);
    if (!activeBatch) {
      $('errPond').textContent = 'No active batch found. Create a batch first.';
      $('errPond').classList.add('show');
      $('pondSelect').classList.add('err');
      ok = false;
    } else {
      $('errPond').textContent = 'Please select a pond';
    }
  }

  const checked = getCheckedIds();
  $('errFeed').textContent = 'Select at least one feed type';
  check(checked.length > 0, 'errFeed');

  let qtyError = false;
  checked.filter(id=>id!=='other').forEach(id => {
    const inp = $(`qty_${id}`);
    if (!inp) return;
    if (!isPositiveNumberField(inp.value)) { inp.classList.add('err'); qtyError = true; ok=false; }
    else inp.classList.remove('err');
  });
  if (qtyError) {
    $('errFeed').textContent = 'Feed quantities must be greater than zero.';
    $('errFeed').classList.add('show');
  }

  if (checked.includes('other')) {
    check($('otherFeedName').value.trim(), 'errOtherName', 'otherFeedName');
    const q = $('otherFeedQty').value.trim();
    $('errOtherQty').textContent = 'Feed quantities must be greater than zero.';
    check(isPositiveNumberField(q), 'errOtherQty', 'otherFeedQty');
  }
  if (!ok) {
    announceToScreenReader("Form validation failed. Please correct highlighted errors.");
  }
  return ok;
}

function buildRecord() {
  const checked = getCheckedIds();
  const pondId  = $('pondSelect').value;
  const feedDate = $('feedDate').value;

  if (!feedDate) {
    showToast('!', 'Invalid Feed Date', 'Feed date is required.');
    return null;
  }
  if (isFutureDateStr(feedDate)) {
    showToast('!', 'Invalid Feed Date', 'Feed date cannot be in the future.');
    return null;
  }

  const feedQuantityCheck = validateFeedQuantitiesForSave(checked);
  if (!feedQuantityCheck.ok) {
    showToast('!', 'Invalid Feed Log', feedQuantityCheck.message);
    return null;
  }

  // CHANGE 4: Determine batch by feed DATE, not current active batch
  const matchedBatch = findBatchForDate(pondId, feedDate);
  if (!matchedBatch) {
    showToast('⚠️', 'No Batch Found', 'No batch existed for this pond on the selected date.');
    return null;
  }

  const pond = ponds.find(p => p.id === pondId);

  const r = {
    id:          'rec_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7),
    Date:        feedDate,
    Time:        getTime(),
    PondId:      pondId,
    PondName:    pond ? pond.name : pondId,
    Pond:        pond ? pond.name : pondId,  // legacy compat for reports
    BatchId:     matchedBatch.id,
    BatchNumber: matchedBatch.batchNumber,
    'Feed Size 1 Gram': '',
    'Feed Size 2 Gram': '',
    'Feed Size 3 Gram': '',
    'Feed Size 4 Gram': '',
    'Feed Size 5 Gram': '',
    'Other Feed Name':  '',
    'Other Feed Gram':  '',
    Notes: $('notes').value.trim(),
  };
  ['fs1','fs2','fs3','fs4','fs5'].forEach((id,i) => {
    if (checked.includes(id)) {
      const inp = $(`qty_${id}`);
      r[`Feed Size ${i+1} Gram`] = inp ? +inp.value : 0;
    }
  });
  if (checked.includes('other')) {
    r['Other Feed Name'] = $('otherFeedName').value.trim();
    r['Other Feed Gram'] = +$('otherFeedQty').value;
  }
  return r;
}

function getTime() {
  if ($('feedTime').value !== 'Other') return $('feedTime').value;
  const t = $('customTime').value;
  // L12 fix: return null when custom time is empty (was returning 'Other' sentinel)
  if (!t) return null;
  const [hh,mm] = t.split(':');
  const h = +hh;
  return `${(h%12)||12}:${mm} ${h>=12?'PM':'AM'}`;
}

function resetForm() {
  setDefaultDate();
  isTimeManuallySelected = false;
  setSuggestedFeedTime();
  $('customTime').value = '';
  $('pondSelect').value = '';
  $('notes').value      = '';
  showHide($('customTimeGroup'), false);
  $('feedGrid').querySelectorAll('input').forEach(c => { c.checked=false; c.closest('.fc-label').classList.remove('checked'); });
  $('qtySection').innerHTML = '';
  showHide($('otherNameGroup'), false);
  showHide($('otherQtyGroup'),  false);
  $('otherFeedName').value = '';
  $('otherFeedQty').value  = '';
  document.querySelectorAll('.ferr').forEach(e => e.classList.remove('show'));
  document.querySelectorAll('.fi,.qty-input').forEach(e => e.classList.remove('err'));
  $('dupWarn').classList.add('hidden');
  $('noBatchWarning').classList.add('hidden');
  lastKey = null; dupConfirm = false;
  // Sync custom dropdowns to reflect cleared values
  alSelects.pondSelect?.sync();
  // Clear medicine/supplement entries on form reset
  resetMedicineLog();
}

function confirmDelete(idx) {
  deleteIdx = idx;
  const r = records[idx];
  if (r) {
    const pondDisplay = r.PondName || r.Pond || '—';
    const feeds = feedSummaryStr(r);
    $('deleteFeedDetails').innerHTML = `
      <div class="delete-feed-row"><span class="dfd-label">Date</span><span class="dfd-val">${r.Date}</span></div>
      <div class="delete-feed-row"><span class="dfd-label">Time</span><span class="dfd-val">${r.Time}</span></div>
      <div class="delete-feed-row"><span class="dfd-label">Pond</span><span class="dfd-val">${pondDisplay}</span></div>
      ${feeds ? `<div class="delete-feed-row"><span class="dfd-label">Feed</span><span class="dfd-val">${feeds}</span></div>` : ''}
    `;
  }
  $('deleteModal').classList.remove('hidden');
}

function doDelete() {
  if (deleteIdx === null) return;
  const removedRecord = records[deleteIdx];
  records.splice(deleteIdx, 1);
  AppStorage.saveRecords(records);
  if (typeof window.InventoryManager === 'object') {
    // C3 fix: reverse medicine/supplement consumption transactions linked to this record.
    // Previously these were orphaned because deleteFeedConsumptionForRecord only removes
    // feed-category txns (by referenceNumber === record.id), not medicine txns.
    if (Array.isArray(removedRecord.medicineLog)) {
      removedRecord.medicineLog.forEach(entry => {
        if (entry.txId && window.AppStorage) {
          window.AppStorage.deleteInventoryTransaction(entry.txId);
        }
      });
    }
    window.InventoryManager.deleteFeedConsumptionForRecord(removedRecord);
  }
  deleteIdx = null;
  closeModal('deleteModal');
  renderDashboard();
  renderReportsTab(reportTab);
  flashElement($('feedGrid') || $('feedForm'));
  showToast('🗑', 'Deleted', 'Entry removed');
}

function openEditFeedModal(idx) {
  const r = records[idx];
  if (!r) return;
  editFeedIdx = idx;

  const pond = ponds.find(p => p.id === r.PondId) || { name: r.PondName || r.Pond || '—' };
  $('editFeedPondCtx').textContent = `Pond: ${pond.name} (cannot be changed)`;

  // Pre-fill date & time
  const today = fmt(new Date());
  $('editFeedDate').value = r.Date || '';
  $('editFeedDate').max = today;

  // Time
  const stdTimes = ['7:00 AM','11:00 AM','4:00 PM','7:00 PM'];
  const isStd = stdTimes.includes(r.Time);
  $('editFeedTime').value = isStd ? r.Time : 'Other';
  $('editCustomTimeGroup').style.display = isStd ? 'none' : '';
  alSelects.editFeedTime?.sync(); // Sync custom dropdown to reflect pre-filled value
  if (!isStd && r.Time) {
    // Convert "H:MM AM/PM" to "HH:MM" for time input
    try {
      const [timePart, ampm] = r.Time.split(' ');
      let [hh, mm] = timePart.split(':').map(Number);
      if (ampm === 'PM' && hh !== 12) hh += 12;
      if (ampm === 'AM' && hh === 12) hh = 0;
      $('editCustomTime').value = `${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}`;
    } catch { $('editCustomTime').value = ''; }
  } else {
    $('editCustomTime').value = '';
  }

  // Build feed grid
  buildEditFeedGrid(r);

  // Notes
  $('editFeedNotes').value = r.Notes || '';

  // Clear errors
  ['errEditFeedDate','errEditFeedTime','errEditCustomTime','errEditFeed','errEditOtherName','errEditOtherQty'].forEach(id => {
    const el = $(id);
    if (el) { el.classList.remove('show'); }
  });
  ['editFeedDate','editFeedTime','editCustomTime','editOtherFeedName','editOtherFeedQty'].forEach(id => {
    $(id)?.classList.remove('err');
  });

  $('editFeedModal').classList.remove('hidden');
}

function buildEditFeedGrid(r) {
  const grid = $('editFeedGrid');
  grid.innerHTML = '';
  FEED_SIZES.forEach(f => {
    const lbl = document.createElement('label');
    lbl.className = 'fc-label';
    lbl.dataset.id = f.id;
    const displayText = f.label.replace('Feed ', '');
    lbl.innerHTML = `<input type="checkbox" value="${f.id}" id="ecb_${f.id}"/><span class="fc-text">${displayText}</span>`;
    grid.appendChild(lbl);
    lbl.querySelector('input').addEventListener('change', onEditFeedChange);
  });

  // Pre-check and pre-fill values
  let hasOther = false;
  ['fs1','fs2','fs3','fs4','fs5'].forEach((id, i) => {
    const val = +(r[`Feed Size ${i+1} Gram`] || 0);
    if (val > 0) {
      const cb = $(`ecb_${id}`);
      if (cb) { cb.checked = true; cb.closest('.fc-label').classList.add('checked'); }
    }
  });
  if (+(r['Other Feed Gram'] || 0) > 0 || r['Other Feed Name']) {
    const cb = $('ecb_other');
    if (cb) { cb.checked = true; cb.closest('.fc-label').classList.add('checked'); }
    hasOther = true;
  }
  renderEditQtyInputs(r);
  $('editOtherNameGroup').style.display = hasOther ? '' : 'none';
  $('editOtherQtyGroup').style.display  = hasOther ? '' : 'none';
  if (hasOther) {
    $('editOtherFeedName').value = r['Other Feed Name'] || '';
    $('editOtherFeedQty').value  = r['Other Feed Gram'] || '';
  }
}

function onEditFeedChange() {
  $('editFeedGrid').querySelectorAll('.fc-label').forEach(l => {
    l.classList.toggle('checked', l.querySelector('input').checked);
  });
  renderEditQtyInputs(null);
  $('errEditFeed').classList.remove('show');
}

function renderEditQtyInputs(prefillRecord) {
  const sec = $('editQtySection');
  sec.innerHTML = '';
  const checked = getEditCheckedIds();
  checked.filter(id => id !== 'other').forEach(id => {
    const f   = FEED_SIZES.find(x => x.id === id);
    const idx = FEED_SIZES.findIndex(x => x.id === id);
    const row = document.createElement('div');
    row.className = 'qty-row';
    row.innerHTML = `
      <label class="qty-label" for="eqty_${id}">${f.label}</label>
      <input class="qty-input" type="number" id="eqty_${id}" inputmode="numeric" min="1" max="99999" placeholder="e.g. 200"/>
      <span class="qty-unit">g</span>`;
    sec.appendChild(row);
    const inp = row.querySelector(`#eqty_${id}`);
    if (prefillRecord) {
      const key = id === 'other' ? 'Other Feed Gram' : `Feed Size ${idx+1} Gram`;
      const val = +(prefillRecord[key] || 0);
      if (val > 0) inp.value = val;
    }
    inp.addEventListener('input', function(){ this.classList.remove('err'); });
  });

  const hasOther = checked.includes('other');
  $('editOtherNameGroup').style.display = hasOther ? '' : 'none';
  $('editOtherQtyGroup').style.display  = hasOther ? '' : 'none';
}

function getEditCheckedIds() {
  return [...$('editFeedGrid').querySelectorAll('input:checked')].map(c => c.value);
}

function getEditTime() {
  const sel = $('editFeedTime').value;
  if (sel !== 'Other') return sel;
  const t = $('editCustomTime').value;
  if (!t) return 'Other';
  const [hh, mm] = t.split(':');
  const h = +hh;
  return `${(h % 12) || 12}:${mm} ${h >= 12 ? 'PM' : 'AM'}`;
}

function doSaveEditFeed() {
  if (editFeedIdx === null) return;
  const r = records[editFeedIdx];
  if (!r) return;

  let ok = true;

  // Date validation
  const newDate = $('editFeedDate').value;
  clearFieldError('errEditFeedDate', 'editFeedDate', 'Required');
  if (!newDate) {
    showFieldError('errEditFeedDate', 'editFeedDate', 'Required');
    ok = false;
  } else if (isFutureDateStr(newDate)) {
    showFieldError('errEditFeedDate', 'editFeedDate', 'Feed date cannot be in the future.');
    ok = false;
  }

  // Time validation
  const newTime = $('editFeedTime').value;
  clearFieldError('errEditFeedTime', 'editFeedTime', 'Required');
  if (!newTime) {
    showFieldError('errEditFeedTime', 'editFeedTime', 'Required');
    ok = false;
  }
  if (newTime === 'Other') {
    clearFieldError('errEditCustomTime', 'editCustomTime', 'Required');
    if (!$('editCustomTime').value) {
      showFieldError('errEditCustomTime', 'editCustomTime', 'Required');
      ok = false;
    }
  }

  // Feed types
  const checked = getEditCheckedIds();
  $('errEditFeed').classList.remove('show');
  if (!checked.length) {
    $('errEditFeed').textContent = 'Select at least one feed type';
    $('errEditFeed').classList.add('show');
    ok = false;
  }

  // Quantities
  let qtyError = false;
  checked.filter(id => id !== 'other').forEach(id => {
    const inp = $(`eqty_${id}`);
    if (!inp) return;
    if (!isPositiveNumberField(inp.value)) { inp.classList.add('err'); qtyError = true; ok = false; }
    else inp.classList.remove('err');
  });
  if (qtyError) {
    $('errEditFeed').textContent = 'Feed quantities must be greater than zero.';
    $('errEditFeed').classList.add('show');
  }

  if (checked.includes('other')) {
    clearFieldError('errEditOtherName', 'editOtherFeedName', 'Required');
    clearFieldError('errEditOtherQty', 'editOtherFeedQty', 'Enter valid quantity');
    if (!$('editOtherFeedName').value.trim()) {
      showFieldError('errEditOtherName', 'editOtherFeedName', 'Required');
      ok = false;
    }
    if (!isPositiveNumberField($('editOtherFeedQty').value)) {
      showFieldError('errEditOtherQty', 'editOtherFeedQty', 'Enter valid quantity');
      ok = false;
    }
  }

  if (!ok) return;

  // Batch reassignment if date changed
  const pondId = r.PondId;
  let matchedBatch = r.BatchId
    ? (batches.find(b => b.id === r.BatchId) || null)
    : null;

  if (newDate !== r.Date) {
    matchedBatch = findBatchForDate(pondId, newDate);
    if (!matchedBatch) {
      showFieldError('errEditFeedDate', 'editFeedDate', 'No batch existed for this pond on the selected date.');
      return;
    }
  }

  // Duplicate check (exclude current record)
  const newTimeStr = getEditTime();
  const builtRec = {
    PondId: pondId,
    PondName: r.PondName,
    Pond: r.Pond,
    Date: newDate,
    Time: newTimeStr,
    BatchId: matchedBatch ? matchedBatch.id : r.BatchId,
  };
  for (let i = 1; i <= 5; i++) builtRec[`Feed Size ${i} Gram`] = '';
  ['fs1','fs2','fs3','fs4','fs5'].forEach((id, i) => {
    if (checked.includes(id)) {
      const inp = $(`eqty_${id}`);
      builtRec[`Feed Size ${i+1} Gram`] = inp ? +inp.value : 0;
    }
  });
  if (checked.includes('other')) {
    builtRec['Other Feed Name'] = $('editOtherFeedName').value.trim();
    builtRec['Other Feed Gram'] = +$('editOtherFeedQty').value;
  } else {
    builtRec['Other Feed Name'] = '';
    builtRec['Other Feed Gram'] = '';
  }

  // Duplicate check excluding self
  const isDup = records.some((existing, idx) => {
    if (idx === editFeedIdx) return false;
    const samePond = (builtRec.PondId && builtRec.PondId === existing.PondId) ||
                     (builtRec.PondName === existing.PondName);
    if (!samePond) return false;
    if (builtRec.Date !== existing.Date) return false;
    if (builtRec.Time !== existing.Time) return false;
    if (builtRec.BatchId !== existing.BatchId) return false;
    for (let i = 1; i <= 5; i++) {
      if (Number(builtRec[`Feed Size ${i} Gram`] || 0) !== Number(existing[`Feed Size ${i} Gram`] || 0)) return false;
    }
    if ((builtRec['Other Feed Name'] || '').toLowerCase() !== (existing['Other Feed Name'] || '').toLowerCase()) return false;
    if (Number(builtRec['Other Feed Gram'] || 0) !== Number(existing['Other Feed Gram'] || 0)) return false;
    return true;
  });

  if (isDup) {
    showToast('⚠️', 'Duplicate Entry', 'A matching record already exists.');
    return;
  }

  // --- FIX 1: Prevent Negative Stock ---
  const stockCheck = window.InventoryManager.checkFeedLogStockSufficiency(builtRec, r.id);
  if (!stockCheck.ok) {
    showToast('⚠️', 'Insufficient Inventory', stockCheck.message);
    return;
  }

  // Apply changes to the record
  records[editFeedIdx] = Object.assign({}, r, builtRec, {
    Notes: $('editFeedNotes').value.trim(),
    BatchNumber: matchedBatch ? matchedBatch.batchNumber : r.BatchNumber,
  });

  // C2 fix: capture the saved record BEFORE editFeedIdx is nulled below.
  // Previously the monkey-patch wrapper checked editFeedIdx AFTER the original
  // had already set it to null, so checkFeedBrandExistence never fired on edit.
  const _savedEditRec = records[editFeedIdx];

  AppStorage.saveRecords(records);
  if (typeof window.InventoryManager === 'object') window.InventoryManager.syncFeedConsumption(records[editFeedIdx]);
  editFeedIdx = null;
  closeModal('editFeedModal');

  renderDashboard();
  renderReportsTab(reportTab);
  if (currentPage === 'pageManage') renderManagePage();
  showToast('✅', 'Entry Updated', 'Feed record saved successfully');

  // C2 fix: moved from broken monkey-patch — now fires correctly because we
  // captured _savedEditRec before editFeedIdx was nulled.
  try { checkFeedBrandExistence(_savedEditRec); } catch(_) {}
  try { refreshActiveInventoryPage(); } catch(_) {}
}

function feedSizeDistribution(recs) {
  const map = {};
  FEED_SIZES.forEach(f => { map[f.id] = { label: f.label, color: f.color, value: 0 }; });
  recs.forEach(r => {
    FEED_SIZES.forEach((f, i) => {
      if (f.id === 'other') {
        map['other'].value += +(r['Other Feed Gram']||0);
      } else {
        map[f.id].value += +(r[`Feed Size ${i+1} Gram`]||0);
      }
    });
  });
  return Object.values(map).filter(d => d.value > 0);
}

function pondFeedDistribution(recs) {
  const POND_PALETTE = ['#38bdf8','#a78bfa','#00d4aa','#f59e0b','#fb923c','#f472b6','#34d399','#60a5fa'];
  const map = {};
  recs.forEach(r => {
    const key  = r.PondId || r.PondName || r.Pond || 'Unknown';
    const name = (() => {
      if (r.PondId) {
        const p = ponds.find(x => x.id === r.PondId);
        return p ? p.name : (r.PondName || r.Pond || 'Pond');
      }
      return r.PondName || r.Pond || 'Unknown';
    })();
    if (!map[key]) map[key] = { label: name, value: 0 };
    map[key].value += sumGrams([r]);
  });
  return Object.values(map)
    .filter(d => d.value > 0)
    .sort((a, b) => b.value - a.value)
    .map((d, i) => ({ ...d, color: POND_PALETTE[i % POND_PALETTE.length] }));
}

function phaseFeedDistribution(recs, batch) {
  const PHASE_COLORS = ['#38bdf8','#00d4aa','#f59e0b'];
  const phases = [
    { label: 'DOC 1–10',  min: 1,  max: 10  },
    { label: 'DOC 11–20', min: 11, max: 20  },
    { label: 'DOC 21+',   min: 21, max: 9999 },
  ];
  const buckets = phases.map(p => ({ ...p, value: 0 }));

  if (!batch || !batch.stockingDate) {
    // fallback: can't compute DOC — nothing to show
    return [];
  }
  const stock = startOfDay(batch.stockingDate);

  recs.forEach(r => {
    if (!r.Date) return;
    const d   = startOfDay(r.Date);
    const doc = Math.floor((d - stock) / MS_PER_DAY) + 1;
    if (doc < 1) return;
    const bucket = buckets.find(b => doc >= b.min && doc <= b.max);
    if (bucket) bucket.value += sumGrams([r]);
  });

  return buckets
    .filter(b => b.value > 0)
    .map((b, i) => ({ label: b.label, value: b.value, color: PHASE_COLORS[i % PHASE_COLORS.length] }));
}

function isDuplicateRecord(rec) {
  return records.some(existing => {
    // 1. Same Pond
    const samePond = (rec.PondId && rec.PondId === existing.PondId) ||
                     (rec.PondName === existing.PondName) ||
                     (rec.Pond === existing.Pond);
    if (!samePond) return false;

    // 2. Same Feed Date
    if (rec.Date !== existing.Date) return false;

    // 3. Same Feed Time
    if (rec.Time !== existing.Time) return false;

    // 4. Same Batch
    if (rec.BatchId !== existing.BatchId) return false;

    // 5. Same Feed Composition (Standard sizes FS1-FS5)
    for (let i = 1; i <= 5; i++) {
      const recVal = Number(rec[`Feed Size ${i} Gram`] || 0);
      const extVal = Number(existing[`Feed Size ${i} Gram`] || 0);
      if (recVal !== extVal) return false;
    }

    // Other Feed Name and Quantity
    const recOtherName = (rec['Other Feed Name'] || '').trim().toLowerCase();
    const extOtherName = (existing['Other Feed Name'] || '').trim().toLowerCase();
    const recOtherGram = Number(rec['Other Feed Gram'] || 0);
    const extOtherGram = Number(existing['Other Feed Gram'] || 0);
    if (recOtherName !== extOtherName || recOtherGram !== extOtherGram) {
      return false;
    }

    return true;
  });
}

function updateNoBatchWarning() {
  const sel = $('pondSelect');
  const warn = $('noBatchWarning');
  if (!sel || !warn) return;
  const pondId = sel.value;
  if (pondId) {
    // CHANGE 4: Check against feed date for historical accuracy
    const feedDate = $('feedDate').value;
    const matched = feedDate ? findBatchForDate(pondId, feedDate) : getActiveBatchForPond(pondId);
    if (!matched) {
      warn.classList.remove('hidden');
      return;
    }
  }
  warn.classList.add('hidden');
}

(function initMedicineLog() {
  /* ── Element references ── */
  const itemSelect      = document.getElementById('medicineItemSelect');
  const customNameGroup = document.getElementById('medCustomNameGroup');
  const nameInput       = document.getElementById('medicineName');
  const qtyInput        = document.getElementById('medicineQty');
  const addBtn          = document.getElementById('addMedicineBtn');
  const tableWrap       = document.getElementById('medicineTableWrap');
  const tbody           = document.getElementById('medicineTableBody');
  const errEl           = document.getElementById('errMedicine');
  const emptyHint       = document.getElementById('medicineEmptyHint');
  const stockBadge      = document.getElementById('medStockBadge');
  const unitLabel       = document.getElementById('medUnitLabel');

  if (!itemSelect || !qtyInput || !addBtn || !tbody) return;

  /* ── Internal state ──
     Each entry: { name, qty, unit, inventoryItemName, txId, stockBefore }
     txId is the inventory consumption transaction id (null for custom entries) */
  let medicineEntries = [];

  /* ── Helpers ── */
  function getActivePondSiteId() {
    try {
      const pondId = document.getElementById('pondSelect')?.value;
      // Use AppStorage as the authoritative source — ponds is a module-scoped let, not on window
      const allPonds = window.AppStorage ? window.AppStorage.getPonds() : [];
      const pond = allPonds.find(p => p.id === pondId);
      return pond?.siteId || null;
    } catch { return null; }
  }

  function getInventoryMedicineItems(siteId) {
    if (!window.AppStorage) return [];

    // If we have a specific siteId use it; otherwise aggregate across all sites
    let txs;
    if (siteId) {
      txs = window.AppStorage.getInventoryByCategory(siteId, 'medicine');
    } else {
      // No pond selected yet — show items from every site so farmer can browse
      txs = window.AppStorage.getAllInventoryTransactions()
              .filter(t => t.category === 'medicine');
    }

    if (!txs.length) return [];

    // Collect distinct item names from any stock-adding transaction type
    const names = [...new Set(txs.map(t => t.itemName).filter(Boolean))];

    return names.map(name => {
      let stock;
      if (siteId) {
        stock = window.AppStorage.getStockBalance(siteId, 'medicine', name);
      } else {
        // Sum across all sites
        const allSites = window.SiteManager ? window.SiteManager.loadSites() : [];
        stock = allSites.reduce((sum, s) =>
          sum + (window.AppStorage.getStockBalance(s.id, 'medicine', name) || 0), 0);
      }
      // C4 fix: subtract pending medicine entries (not yet committed) so the dropdown
      // and stock badge reflect projected stock after the current form's deductions
      const pending = medicineEntries
        .filter(e => e.inventoryItemName === name && (!siteId || e.siteId === siteId))
        .reduce((sum, e) => sum + e.qty, 0);
      stock -= pending;
      const sample = txs.find(t => t.itemName === name);
      return { name, stock, unit: sample?.unit || '' };
    }).filter(i => i.name);
  }

  /* ── Populate the item dropdown ── */
  function populateSelector() {
    const siteId = getActivePondSiteId();
    const items  = getInventoryMedicineItems(siteId);
    const prevVal = itemSelect.value; // preserve selection if re-populating

    itemSelect.innerHTML = ''; // no blank placeholder — items appear directly

    if (items.length === 0) {
      // No inventory items — go straight to custom entry
      const opt = document.createElement('option');
      opt.value       = '__custom__';
      opt.textContent = '＋ Enter custom name (not in inventory)';
      itemSelect.appendChild(opt);
    } else {
      items.forEach(item => {
        const opt = document.createElement('option');
        opt.value          = item.name;
        opt.textContent    = `${item.name}  (${item.stock.toFixed(2)} ${item.unit})`;
        opt.dataset.unit   = item.unit;
        opt.dataset.stock  = item.stock;
        itemSelect.appendChild(opt);
      });
      const sep = document.createElement('option');
      sep.disabled    = true;
      sep.textContent = '─────────────────';
      itemSelect.appendChild(sep);
      const custom = document.createElement('option');
      custom.value       = '__custom__';
      custom.textContent = '＋ Enter custom name (not in inventory)';
      itemSelect.appendChild(custom);

      // Restore previous selection if still available, else keep first item selected
      if (prevVal && Array.from(itemSelect.options).some(o => o.value === prevVal)) {
        itemSelect.value = prevVal;
      } else {
        itemSelect.selectedIndex = 0; // auto-select first inventory item
      }
    }

    // Sync AlSelect wrapper
    if (window.alSelects?.medicineItemSelect) {
      window.alSelects.medicineItemSelect.sync();
    }

    onItemChange();
  }


  /* ── React to item selection change ── */
  function onItemChange() {
    const val = itemSelect.value;

    if (val === '__custom__') {
      // Show free-text name field
      customNameGroup.classList.remove('hidden');
      nameInput.focus();
      stockBadge.className = 'med-stock-badge hidden';
      stockBadge.textContent = '';
      unitLabel.textContent  = '(g / ml)';
      return;
    }

    customNameGroup.classList.add('hidden');
    nameInput.value = '';

    if (!val) {
      stockBadge.className   = 'med-stock-badge hidden';
      stockBadge.textContent = '';
      unitLabel.textContent  = '';
      return;
    }

    // Find selected option data
    const opt   = itemSelect.options[itemSelect.selectedIndex];
    const stock = parseFloat(opt.dataset.stock) || 0;
    const unit  = opt.dataset.unit || '';

    unitLabel.textContent = unit ? `(${unit})` : '';

    // Stock badge
    stockBadge.classList.remove('hidden', 'in-stock', 'low-stock', 'no-stock');
    if (stock <= 0) {
      stockBadge.classList.add('no-stock');
      stockBadge.textContent = '⚠ Out of stock';
    } else if (stock < 10) {
      stockBadge.classList.add('low-stock');
      stockBadge.textContent = `⚡ Low: ${stock.toFixed(2)} ${unit}`;
    } else {
      stockBadge.classList.add('in-stock');
      stockBadge.textContent = `✓ ${stock.toFixed(2)} ${unit} in stock`;
    }
  }

  /* ── Re-render the table from medicineEntries ── */
  function render() {
    tbody.innerHTML = '';

    if (medicineEntries.length === 0) {
      tableWrap.classList.add('hidden');
      emptyHint.classList.remove('hidden');
      return;
    }

    tableWrap.classList.remove('hidden');
    emptyHint.classList.add('hidden');

    const siteId = getActivePondSiteId();

    medicineEntries.forEach((entry, idx) => {
      // C4 fix: stock is NOT yet deducted (txn deferred to submit), so compute
      // projected stock by subtracting all pending entries up to and including this one
      // M9 fix: use entry.siteId (captured at add time) instead of getActivePondSiteId()
      // so entries from Pond A's site show Pond A's stock after switching to Pond B
      const entrySiteId = entry.siteId || siteId;
      let stockLeft = null;
      if (entrySiteId && entry.inventoryItemName && window.AppStorage) {
        const currentStock = window.AppStorage.getStockBalance(entrySiteId, 'medicine', entry.inventoryItemName);
        const pendingDeduction = medicineEntries
          .slice(0, idx + 1)
          .filter(e => e.inventoryItemName === entry.inventoryItemName && e.siteId === entrySiteId)
          .reduce((sum, e) => sum + e.qty, 0);
        stockLeft = currentStock - pendingDeduction;
      }

      const stockClass = stockLeft === null ? '' :
        stockLeft <= 0 ? 'none' : stockLeft < 10 ? 'low' : 'ok';
      const stockText  = stockLeft === null ? '—' :
        `${stockLeft.toFixed(2)} ${entry.unit || ''}`;

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${escapeHTML(entry.name)}</td>
        <td>${escapeHTML(String(entry.qty))} ${escapeHTML(entry.unit || '')}</td>
        <td><span class="med-stock-left ${stockClass}">${stockText}</span></td>
        <td>
          <button
            type="button"
            class="medicine-del-btn"
            aria-label="Remove ${escapeHTML(entry.name)}"
            data-idx="${idx}"
          >✕</button>
        </td>
      `;
      tr.querySelector('.medicine-del-btn').addEventListener('click', handleDelete);
      tbody.appendChild(tr);
    });
  }

  /* ── Show / hide inline error ── */
  function showError(msg) {
    errEl.textContent = msg;
    errEl.classList.add('show');
    errEl.classList.remove('hidden');
  }
  function clearError() {
    errEl.textContent = '';
    errEl.classList.remove('show');
    errEl.classList.add('hidden');
  }

  /* ── Add button handler ── */
  function handleAdd() {
    clearError();
    const val = itemSelect.value;
    // val will always be set (first item auto-selected) — only need to guard custom text

    const isCustom = val === '__custom__';
    const name = isCustom ? nameInput.value.trim() : val;
    if (!name) {
      showError('Please enter the medicine or supplement name.');
      nameInput.focus();
      return;
    }

    const qtyRaw = qtyInput.value.trim();
    if (!qtyRaw || isNaN(Number(qtyRaw)) || Number(qtyRaw) <= 0) {
      showError('Please enter a valid quantity (must be greater than 0).');
      qtyInput.focus();
      return;
    }
    const qty = Number(qtyRaw);

    // Get unit from selected option
    const opt  = itemSelect.options[itemSelect.selectedIndex];
    const unit = isCustom ? '' : (opt?.dataset?.unit || '');

    // For inventory items: validate stock and create consumption transaction
    let txId = null;
    let inventoryItemName = null;

    if (!isCustom) {
      // Resolve siteId: use active pond's site, else find the site that actually holds this item
      let siteId = getActivePondSiteId();
      if (!siteId && window.SiteManager && window.AppStorage) {
        const sites = window.SiteManager.loadSites();
        const matchingSite = sites.find(s =>
          window.AppStorage.getStockBalance(s.id, 'medicine', name) > 0
        );
        siteId = matchingSite?.id || null;
      }

      if (siteId && window.AppStorage) {
        const currentStock = window.AppStorage.getStockBalance(siteId, 'medicine', name);

        // Account for entries already added this session (C4 fix: deferred — no txn yet)
        const alreadyUsed = medicineEntries
          .filter(e => e.inventoryItemName === name && e.siteId === siteId)
          .reduce((sum, e) => sum + e.qty, 0);
        const effectiveStock = currentStock - alreadyUsed;

        if (effectiveStock < qty) {
          showError(`Insufficient stock. Available: ${effectiveStock.toFixed(2)} ${unit} (${name}).`);
          qtyInput.focus();
          return;
        }

        // C4 fix: defer createTransaction to handleSubmit — store entry now, commit on save.
        // This prevents orphaned consumption transactions when the form is abandoned
        // (navigating away, closing tab, etc.) without submitting.
        inventoryItemName = name;
        txId = null; // will be assigned when handleSubmit commits the transaction
      }
    }

    medicineEntries.push({ name, qty, unit, inventoryItemName, txId, siteId: inventoryItemName ? (getActivePondSiteId() || null) : null });

    render();

    // Reset inputs
    itemSelect.value = '';
    nameInput.value  = '';
    qtyInput.value   = '';
    customNameGroup.classList.add('hidden');
    stockBadge.className   = 'med-stock-badge hidden';
    stockBadge.textContent = '';
    unitLabel.textContent  = '';

    // Refresh selector stock levels
    populateSelector();
    itemSelect.focus();
  }

  /* ── Delete handler — C4 fix: no transaction to reverse (txn is deferred to submit) ── */
  function handleDelete(e) {
    const idx = parseInt(e.currentTarget.dataset.idx, 10);
    if (isNaN(idx) || idx < 0 || idx >= medicineEntries.length) return;

    medicineEntries.splice(idx, 1);
    render();
    populateSelector(); // refresh stock badges
  }

  /* ── Listeners ── */
  itemSelect.addEventListener('change', onItemChange);
  addBtn.addEventListener('click', handleAdd);
  [nameInput, qtyInput].forEach(inp => {
    inp.addEventListener('keydown', e => {
      if (e.key === 'Enter') { e.preventDefault(); handleAdd(); }
    });
    inp.addEventListener('input', clearError);
  });

  /* ── Re-populate when pond changes (siteId may change) ── */
  document.addEventListener('change', e => {
    if (e.target && e.target.id === 'pondSelect') {
      populateSelector();
    }
  });

  /* ── Public API ── */
  window.getMedicineEntries = function () {
    return medicineEntries.map(e => ({
      name    : e.name,
      quantity: e.qty,
      unit    : e.unit || '',
      fromInventory: !!e.inventoryItemName,
      txId    : e.txId || null,
    }));
  };

  window.resetMedicineLog = function () {
    // On reset (after form submit): txIds are now committed — do NOT delete them
    // The consumption transactions should persist as the stock deduction record
    medicineEntries = [];
    nameInput.value  = '';
    qtyInput.value   = '';
    customNameGroup.classList.add('hidden');
    stockBadge.className   = 'med-stock-badge hidden';
    stockBadge.textContent = '';
    unitLabel.textContent  = '';
    clearError();
    render();
    populateSelector(); // re-selects first item automatically
  };


  /* ── Expose repopulate so inventory page changes trigger a refresh ── */
  window.refreshMedicineLogInventory = populateSelector;

  /* Initial populate + render */
  populateSelector();
  render();
})();

// Window bindings for backward compatibility
window.validateFeedQuantitiesForSave = validateFeedQuantitiesForSave;
window.renderFeedGrid = renderFeedGrid;
window.onFeedChange = onFeedChange;
window.renderQtyInputs = renderQtyInputs;
window.getCheckedIds = getCheckedIds;
window.getSuggestedFeedingTime = getSuggestedFeedingTime;
window.setSuggestedFeedTime = setSuggestedFeedTime;
window.getRecordTimestamp = getRecordTimestamp;
window.getPreviousRecord = getPreviousRecord;
window.getPreviousFeedQuantity = getPreviousFeedQuantity;
window.updateAdjustmentIndicator = updateAdjustmentIndicator;
window.refreshPreviousFeedReferences = refreshPreviousFeedReferences;
window.getPreviousOtherFeed = getPreviousOtherFeed;
window.autoSelectPreviousFeedSizes = autoSelectPreviousFeedSizes;
window.setDefaultDate = setDefaultDate;
window.bindFormEvents = bindFormEvents;
window.handleSubmit = handleSubmit;
window.validate = validate;
window.buildRecord = buildRecord;
window.getTime = getTime;
window.resetForm = resetForm;
window.confirmDelete = confirmDelete;
window.doDelete = doDelete;
window.openEditFeedModal = openEditFeedModal;
window.buildEditFeedGrid = buildEditFeedGrid;
window.onEditFeedChange = onEditFeedChange;
window.renderEditQtyInputs = renderEditQtyInputs;
window.getEditCheckedIds = getEditCheckedIds;
window.getEditTime = getEditTime;
window.doSaveEditFeed = doSaveEditFeed;
window.feedSizeDistribution = feedSizeDistribution;
window.pondFeedDistribution = pondFeedDistribution;
window.phaseFeedDistribution = phaseFeedDistribution;
window.isDuplicateRecord = isDuplicateRecord;
window.updateNoBatchWarning = updateNoBatchWarning;

// MODAL_STATE_CLEANUP Registrations
window.MODAL_STATE_CLEANUP = window.MODAL_STATE_CLEANUP || {};
window.MODAL_STATE_CLEANUP.editFeedModal = () => { editFeedIdx = null; };
})();

// --- Module: dashboard.js ---
(function() {
  'use strict';
const {
    escapeHTML,
    startOfDay,
    fmt,
    todayStr,
    isIsoDateStr,
    isFutureDateStr,
    isBeforeDateStr,
    numberFromField,
    isPositiveNumberField,
    isNonNegativeNumberField,
    fmtDateDisplay,
    fmtShrimpCount,
    fmtWeightG,
    fmtGrams,
    capitalize,
    formatInputDate,
    formatTime12,
    calcDOC,
    getDateForDOC,
    isInLastNDays,
    getWeekRange,
    getMonthOffset
  } = AppUtils;

function populateContextSelector() {
  const select = $('dashboardContextSelect');
  if (!select) return;

  // ── Preserve the current selection before rebuilding options ──
  const previousValue = select.value || 'farm';

  const activeGroup   = $('activeBatchesOptGroup');
  const completedGroup = $('completedBatchesOptGroup');
  if (activeGroup)    activeGroup.innerHTML    = '';
  if (completedGroup) completedGroup.innerHTML = '';

  // Active batches — newest stocking date first
  const activeList = batches
    .filter(b => b.status === 'active')
    .slice()
    .sort((a, b) => {
      const da = a.stockingDate ? new Date(a.stockingDate) : new Date(0);
      const db = b.stockingDate ? new Date(b.stockingDate) : new Date(0);
      return db - da; // descending
    });

  if (activeGroup) activeGroup.label = `Active (${activeList.length})`;

  activeList.forEach(b => {
    const pond     = ponds.find(p => p.id === b.pondId);
    const pondName = pond ? pond.name : (b.pond || 'Unknown');
    const doc      = calcDOC(b.stockingDate);
    const opt      = document.createElement('option');
    opt.value       = `batch_${b.id}`;
    opt.textContent = `${pondName} → Batch #${b.batchNumber} (DOC ${doc})`;
    if (activeGroup) activeGroup.appendChild(opt);
  });

  // Completed batches — newest harvest date first (fallback: stocking date)
  const completedList = batches
    .filter(b => b.status === 'completed')
    .slice()
    .sort((a, b) => {
      const dateA = a.harvestDate || a.stockingDate || '';
      const dateB = b.harvestDate || b.stockingDate || '';
      return dateB.localeCompare(dateA); // descending
    });

  if (completedGroup) completedGroup.label = `Completed (${completedList.length})`;

  completedList.forEach(b => {
    const pond     = ponds.find(p => p.id === b.pondId);
    const pondName = pond ? pond.name : (b.pond || 'Unknown');
    const opt      = document.createElement('option');
    opt.value       = `batch_${b.id}`;
    opt.textContent = `${pondName} → Batch #${b.batchNumber}`;
    if (completedGroup) completedGroup.appendChild(opt);
  });

  // Restore the previous selection; fall back to 'farm' only if the option
  // no longer exists in the rebuilt list (e.g. batch was deleted).
  select.value = previousValue;
  if (!select.value) select.value = 'farm';
  alSelects.dashCtx?.refresh(); // Sync custom dropdown after options rebuild
}

function renderDashboard() {
  // Rebuild dropdown options while preserving the current selection.
  populateContextSelector();



  const select  = $('dashboardContextSelect');
  const context = select ? select.value : 'farm';

  if (context === 'farm') {
    showFarmView();
  } else if (context.startsWith('batch_')) {
    const batchId = context.replace('batch_', '');
    const batch   = batches.find(b => b.id === batchId);
    if (!batch) {
      // Batch no longer exists — gracefully fall back to Farm Overview.
      select.value = 'farm';
      showFarmView();
      return;
    }
    showBatchView(batch);
  }
  // NOTE: The change event listener is wired once in bindEvents().
  // Do NOT attach additional listeners here to avoid duplicates.
}

function anFmtKg(grams) {
  if (!grams || isNaN(grams)) return null;
  const kg = grams / 1000;
  if (kg >= 1) return kg.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 }) + ' kg';
  return Math.round(grams).toLocaleString() + ' g';
}

function anMostUsedFeedSize(recs) {
  const totals = {};
  FEED_SIZES.forEach(f => { totals[f.id] = 0; });
  recs.forEach(r => {
    for (let i = 1; i <= 5; i++) totals[`fs${i}`] += +(r[`Feed Size ${i} Gram`] || 0);
    totals['other'] += +(r['Other Feed Gram'] || 0);
  });
  let maxId = null, maxVal = 0;
  Object.entries(totals).forEach(([id, val]) => {
    if (val > maxVal) { maxVal = val; maxId = id; }
  });
  if (!maxId || maxVal === 0) return null;
  const fs = FEED_SIZES.find(f => f.id === maxId);
  return fs ? fs.label : null;
}

function anHighestDay(recs) {
  const dayMap = {};
  recs.forEach(r => {
    if (!r.Date) return;
    dayMap[r.Date] = (dayMap[r.Date] || 0) + sumGrams([r]);
  });
  let maxDate = null, maxGrams = 0;
  Object.entries(dayMap).forEach(([d, g]) => {
    if (g > maxGrams) { maxGrams = g; maxDate = d; }
  });
  return maxGrams > 0 ? { date: maxDate, grams: maxGrams } : null;
}

function anHighestDOC(batch) {
  const docMap = {};
  const batchRecs = records.filter(r => r.BatchId === batch.id);
  batchRecs.forEach(r => {
    if (!r.Date) return;
    const stock = startOfDay(batch.stockingDate);
    const day   = startOfDay(r.Date);
    const diff  = Math.floor((day - stock) / MS_PER_DAY);
    const doc   = diff >= 0 ? diff + 1 : null;
    if (doc === null) return;
    docMap[doc] = (docMap[doc] || 0) + sumGrams([r]);
  });
  let maxDoc = null, maxGrams = 0;
  Object.entries(docMap).forEach(([d, g]) => {
    if (g > maxGrams) { maxGrams = g; maxDoc = +d; }
  });
  return maxGrams > 0 ? { doc: maxDoc, grams: maxGrams } : null;
}

function renderFarmTotalFeedCard() {
  const el = $('farmTotalFeedValue');
  if (!el) return;
  const total = sumGrams(records);
  if (total === 0 || records.length === 0) {
    el.textContent = 'No Feed Data';
    el.classList.add('an-total-empty');
  } else {
    el.textContent = anFmtKg(total) || 'No Feed Data';
    el.classList.remove('an-total-empty');
  }
}

function renderFarmTrendChart() {
  const card  = $('heroTrendSection');
  const empty = $('farmTrendEmpty');
  const canvas = $('farmTrendChart');
  if (!card || !canvas) return;

  // Build last 7 calendar days
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = fmt(d);
    const dayRecs = records.filter(r => r.Date === key);
    days.push({
      label: d.toLocaleDateString('en-IN', { weekday: 'short' }),
      value: sumGrams(dayRecs)
    });
  }

  const hasData = days.filter(d => d.value > 0).length >= 2;
  if (!hasData) {
    canvas.style.display = 'none';
    if (empty) { empty.textContent = 'No Records Available'; empty.classList.remove('hidden'); }
    const summaryBox = $('farmTrendSummary');
    if (summaryBox) summaryBox.classList.add('hidden');
    return;
  }
  canvas.style.display = '';
  if (empty) empty.classList.add('hidden');
  const desc = "7-Day Feed Trend: " + days.map(d => `${d.label}: ${fmtGrams(d.value)}g`).join(', ');
  canvas.setAttribute('role', 'img');
  canvas.setAttribute('aria-label', desc);

  // Calculate 7-Day Summary
  const values = days.map(d => d.value);
  const totalVal = values.reduce((a, b) => a + b, 0);
  const avgVal = totalVal / 7;
  let highest = days[0];
  let lowest = days[0];
  days.forEach(d => {
    if (d.value > highest.value) highest = d;
    if (d.value < lowest.value) lowest = d;
  });
  const startDay = days[0];
  const endDay = days[6];
  let trendStr = "";
  if (endDay.value > startDay.value) {
    trendStr = `Feed consumption increased from ${fmtGrams(startDay.value)}g on ${startDay.label} to ${fmtGrams(endDay.value)}g on ${endDay.label}.`;
  } else if (endDay.value < startDay.value) {
    trendStr = `Feed consumption decreased from ${fmtGrams(startDay.value)}g on ${startDay.label} to ${fmtGrams(endDay.value)}g on ${endDay.label}.`;
  } else {
    trendStr = `Feed consumption remained steady at ${fmtGrams(endDay.value)}g between ${startDay.label} and ${endDay.label}.`;
  }
  const summaryBox = $('farmTrendSummary');
  if (summaryBox) {
    summaryBox.innerHTML = `7-Day Summary: Total feed of <strong class="summary-highlight">${fmtGrams(totalVal)}g</strong> (avg: ${fmtGrams(Math.round(avgVal))}g/day). Peak consumption was <strong class="summary-highlight">${fmtGrams(highest.value)}g</strong> on ${highest.label}, and lowest was ${fmtGrams(lowest.value)}g on ${lowest.label}. ${trendStr}`;
    summaryBox.classList.remove('hidden');
  }

  requestAnimationFrame(() => {
    const today = new Date();
    const enrichedDays = days.map((d, i) => {
      const dateObj = new Date();
      dateObj.setDate(today.getDate() - (6 - i));
      const dateStr  = fmt(dateObj);
      const dayRecs  = records.filter(r => r.Date === dateStr);
      const pondSet  = [...new Set(dayRecs.map(r => r.PondName || r.Pond || 'Unknown'))];
      const feedDist = feedSizeDistribution(dayRecs);
      return { ...d, _meta: { type: 'farm-day', dateStr, dateLabel: dateObj.toLocaleDateString('en-IN',{weekday:'long',day:'numeric',month:'short'}), sessions: dayRecs.length, ponds: pondSet, feedDist } };
    });
    const canvas = $('farmTrendChart');
    if (canvas) canvas._onBarClick = (bar) => showBarDetailModal(bar._meta, '#38bdf8');
    // ── Fix #2: Mobile-first chart — natural aspect ratio, not vertically stretched.
    // Height 110 gives enough room for bars + x-axis labels + value labels without
    // making the chart look tall-and-thin. Combined with the CSS fix that stops
    // forcing width:100% on the canvas, the chart now renders at its intended size.
    drawBarChart('farmTrendChart', enrichedDays, { color: '#38bdf8', height: 110 });
  });
}

function renderFarmMonthlyConsumption() {
  const wrap = $('farmMonthlyWrap');
  if (!wrap) return;

  if (!records.length) {
    wrap.innerHTML = `<div class="an-monthly-empty">No Records Available</div>`;
    return;
  }

  // Group by YYYY-MM
  const monthMap = {};
  records.forEach(r => {
    if (!r.Date) return;
    const key = r.Date.slice(0, 7); // YYYY-MM
    monthMap[key] = (monthMap[key] || 0) + sumGrams([r]);
  });

  if (!Object.keys(monthMap).length) {
    wrap.innerHTML = `<div class="an-monthly-empty">No Records Available</div>`;
    return;
  }

  // Sort chronologically
  const sorted = Object.entries(monthMap).sort((a, b) => a[0].localeCompare(b[0]));
  const maxVal  = Math.max(...sorted.map(([, g]) => g), 1);

  const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  wrap.innerHTML = sorted.map(([key, grams]) => {
    const [yr, mo] = key.split('-');
    const label    = `${monthNames[+mo - 1]} ${yr}`;
    const pct      = Math.max(Math.round((grams / maxVal) * 100), 2);
    return `<div class="an-monthly-row">
      <div class="an-monthly-meta">
        <span class="an-monthly-label">${label}</span>
        <span class="an-monthly-val">${anFmtKg(grams)}</span>
      </div>
      <div class="an-monthly-bar-bg">
        <div class="an-monthly-bar-fill" style="width:${pct}%"></div>
      </div>
    </div>`;
  }).join('');
}

function renderActiveBatchSummaryCards() {
  const wrap = $('activeBatchSummaryCards');
  if (!wrap) return;

  const activeBatches = batches
    .filter(b => b.status === 'active')
    .slice()
    .sort((a, b) => {
      // Sort by stocking date ascending = highest DOC first
      const da = a.stockingDate ? new Date(a.stockingDate) : new Date(0);
      const db = b.stockingDate ? new Date(b.stockingDate) : new Date(0);
      return da - db;
    });

  if (!activeBatches.length) {
    wrap.innerHTML = `<div class="abs-empty">
      <span class="abs-empty-icon">🦐</span>
      <span class="abs-empty-text">No Records Available</span>
    </div>`;
    return;
  }

  wrap.innerHTML = activeBatches.map(batch => {
    const pond      = ponds.find(p => p.id === batch.pondId);
    const pondName  = pond ? pond.name : (batch.pond || 'Unknown');
    const doc       = calcDOC(batch.stockingDate);
    const batchRecs = records.filter(r => r.BatchId === batch.id);
    const totalGrams = sumGrams(batchRecs);
    const totalFeedDisplay = totalGrams > 0 ? (anFmtKg(totalGrams) || '—') : '—';

    // Today's feed for this batch
    const todayISO  = fmt(new Date());
    const todayRecs = batchRecs.filter(r => r.Date === todayISO);
    const todayGrams = sumGrams(todayRecs);
    const feedTodayDisplay = todayGrams > 0 ? anFmtKg(todayGrams) : '0 kg';

    // Weight data (primary weight: sampling overrides visual estimation)
    const latestWeightObj = getPrimaryBatchWeight(batch);
    const weightDisplay = latestWeightObj ? fmtWeightG(latestWeightObj.weightGrams).replace('g', ' g') : null;

    // Last updated display
    let lastUpdatedDisplay = '';
    let daysSinceWeight = null;
    if (latestWeightObj) {
      lastUpdatedDisplay = latestWeightObj.lastUpdatedDisplay;
      const today0 = startOfDay();
      const upd0   = startOfDay(latestWeightObj.date + 'T00:00:00');
      daysSinceWeight = Math.floor((today0 - upd0) / MS_PER_DAY);
    }

    // Warning logic — suppress for DOC < 7
    let warningHTML = '';
    let isWeightCritical = false;
    let isWeightWarning = false;
    if (latestWeightObj === null) {
      const freshness = getWeightFreshness(doc);
      if (freshness !== 'ok') {
        isWeightCritical = freshness === 'critical';
        isWeightWarning  = freshness === 'warning';
        const titleText  = isWeightCritical ? 'Growth Data Outdated' : 'Weight Update Recommended';
        const warnClass  = isWeightCritical ? 'abs-weight-warn abs-weight-warn--critical' : 'abs-weight-warn';
        warningHTML = `<div class="${warnClass}">
          <span class="abs-warn-icon">⚠</span>
          <div class="abs-warn-text">
            <div class="abs-warn-title">${titleText}</div>
            <div class="abs-warn-sub">
              Current Weight: <strong>Not Recorded</strong><br/>
              Last Updated: <strong>Never</strong>
            </div>
          </div>
        </div>`;
      }
    } else {
      const weightVal = fmtWeightG(latestWeightObj.weightGrams).replace('g', ' g');
      const freshness = getWeightFreshness(daysSinceWeight);
      if (freshness === 'critical') {
        isWeightCritical = true;
        warningHTML = `<div class="abs-weight-warn abs-weight-warn--critical">
          <span class="abs-warn-icon">⚠</span>
          <div class="abs-warn-text">
            <div class="abs-warn-title">Growth Data Outdated</div>
            <div class="abs-warn-sub">
              Current Weight: <strong>${weightVal}</strong><br/>
              Last Updated: <strong>${lastUpdatedDisplay}</strong>
            </div>
          </div>
        </div>`;
      } else if (freshness === 'warning') {
        isWeightWarning = true;
        warningHTML = `<div class="abs-weight-warn">
          <span class="abs-warn-icon">⚠</span>
          <div class="abs-warn-text">
            <div class="abs-warn-title">Weight Update Recommended</div>
            <div class="abs-warn-sub">
              Current Weight: <strong>${weightVal}</strong><br/>
              Last Updated: <strong>${lastUpdatedDisplay}</strong>
            </div>
          </div>
        </div>`;
      }
    }

    // Biomass display
    const bioResult = updateBatchBiomassEstimation(batch);
    let biomassHTML = '';
    if (bioResult.success) {
      const biomassDisplay = `${Number(bioResult.biomassKg).toLocaleString()} kg`;
      if (bioResult.abwSource === 'visual_estimation') {
        biomassHTML = `<div class="abs-stat-val" style="color:var(--amber);">${biomassDisplay}
          <span class="abs-weight-sub" style="color:var(--t3);font-weight:normal;text-transform:none;">Visual Est.</span>
        </div>`;
      } else {
        biomassHTML = `<div class="abs-stat-val" style="color:var(--teal);">${biomassDisplay}
          <span class="abs-weight-sub" style="color:var(--t3);font-weight:normal;text-transform:none;">Sampling</span>
        </div>`;
      }
    } else {
      if (bioResult.status === 'HAPA_MISSING') {
        biomassHTML = `<div class="abs-stat-val abs-stat-val--na">—
          <span class="abs-weight-sub" style="color:var(--red);font-weight:normal;text-transform:none;">No Hapa</span>
        </div>`;
      } else {
        biomassHTML = `<div class="abs-stat-val abs-stat-val--na">—
          <span class="abs-weight-sub" style="color:var(--t3);font-weight:normal;text-transform:none;">No ABW</span>
        </div>`;
      }
    }

    const activeSamplings = getSamplingForBatch(batch.id);
    const hasActiveSampling = activeSamplings.length > 0;
    const weightBtnAttrs = hasActiveSampling
      ? 'disabled title="Visual Weight disabled after first sampling entry."'
      : `data-action="openLogWeightModal" data-batch-id="${batch.id}"`;

    return `<div class="abs-card">
      <div class="abs-card-top">
        <div class="abs-batch-name">${escapeHTML(batch.pond || pondName)}</div>
        <div class="abs-doc-badge">DOC ${doc}</div>
      </div>
      <div class="abs-pond-name">${escapeHTML(pondName)}</div>
      ${getHapaBadgeHTML(batch.id, doc)}
      ${getSamplingBadgeHTML(batch)}
      <div class="abs-stats">
        <div class="abs-stat">
          <div class="abs-stat-lbl">Feed Today</div>
          <div class="abs-stat-val">${feedTodayDisplay}</div>
        </div>
        <div class="abs-stat abs-stat--weight">
          <div class="abs-stat-lbl">Weight</div>
          ${weightDisplay
            ? `<div class="abs-stat-val abs-stat-val--weight">${weightDisplay}
                <span class="abs-weight-sub">DOC ${latestWeightObj.doc} · ${lastUpdatedDisplay}</span>
               </div>`
            : `<div class="abs-stat-val abs-stat-val--na">Not Recorded</div>`}
        </div>
        <div class="abs-stat">
          <div class="abs-stat-lbl">Biomass</div>
          ${biomassHTML}
        </div>
      </div>
      ${warningHTML}
      <div class="abs-quick-actions">
        <button class="abs-qa-btn abs-qa-btn--feed" data-action="openQuickAddFeed" data-pond-id="${pond ? pond.id : ''}">
          <span class="abs-qa-icon">＋</span> Add Feed
        </button>
        <button class="abs-qa-btn ${isWeightCritical ? 'abs-qa-btn--weight-critical' : isWeightWarning ? 'abs-qa-btn--weight-warning' : 'abs-qa-btn--weight'}" ${weightBtnAttrs}>
          <span class="abs-qa-icon">⚖</span> Add Weight
        </button>
        <button class="abs-qa-btn ${batchNeedsSampling(batch) ? 'abs-qa-btn--sampling-warning' : 'abs-qa-btn--sampling'}" data-action="openSamplingModal" data-batch-id="${batch.id}">
          <span class="sampling-btn-label">Sampling</span>
          
          <svg class="sampling-btn-sparkle" viewBox="0 0 24 24" fill="none">
            <path d="M12,2 C12,2 13,8 15,10 C17,12 22,12 22,12 C22,12 17,12 15,14 C13,16 12,22 12,22 C12,22 11,16 9,14 C7,12 2,12 2,12 C2,12 7,12 9,10 C11,8 12,2 12,2 Z" fill="rgba(255,255,255,0.6)" />
          </svg>
        </button>
        ${!getHapaForBatch(batch.id) ? `<button class="abs-qa-btn abs-qa-btn--hapa" data-action="openHapaEntryModal" data-batch-id="${batch.id}">
          <span class="abs-qa-icon">🔍</span> Hapa Check
        </button>` : ''}
      </div>
    </div>`;
  }).join('');
}

function openQuickAddFeed(pondId) {
  switchPage('pageLog');
  if (!pondId) return;
  requestAnimationFrame(() => {
    const sel = $('pondSelect');
    if (!sel) return;
    // Try native select first
    const opt = sel.querySelector(`option[value="${pondId}"]`);
    if (opt && !opt.disabled) {
      sel.value = pondId;
      sel.dispatchEvent(new Event('change', { bubbles: true }));
      // Sync custom dropdown if present
      if (alSelects.pondSelect) alSelects.pondSelect.sync();
    }
  });
}

function renderBatchSummaryCard(batch) {
  // This populates the new consolidated fields added to batchSummaryCard in the hero card
  const isCompleted = batch.status === 'completed';
  const days = getBatchCycleLength(batch);

  // Set the title for DOC dynamically (Final DOC vs DOC)
  const docValueEl = $('batchDocValue');
  if (docValueEl) {
    docValueEl.textContent = isCompleted ? `Final DOC ${days}` : `DOC ${days}`;
  }

  // Stock date
  const stockDateEl = $('batchCardStockDate');
  if (stockDateEl) stockDateEl.textContent = fmtDateDisplay(batch.stockingDate);

  // Expand/collapse details restoration
  const isExpanded = sessionStorage.getItem(`aqualog_batch_expanded_${batch.id}`) === 'true';
  const contentEl = $('batchDetailsContent');
  const indicator = $('batchDetailsIndicator');
  const batchSummaryCardEl = $('batchSummaryCard');
  if (contentEl) {
    if (isExpanded) {
      contentEl.classList.remove('collapsed');
      if (indicator) indicator.textContent = '⌃';
      if (batchSummaryCardEl) batchSummaryCardEl.setAttribute('aria-expanded', 'true');
    } else {
      contentEl.classList.add('collapsed');
      if (indicator) indicator.textContent = '⌄';
      if (batchSummaryCardEl) batchSummaryCardEl.setAttribute('aria-expanded', 'false');
    }
  }

  // Weight label (Final Weight vs Current Weight)
  const weightLblEl = $('batchCardWeightLbl');
  if (weightLblEl) weightLblEl.textContent = isCompleted ? 'Final Weight' : 'Current Shrimp Weight';

  // Weight data (primary weight: sampling overrides visual estimation)
  const latest = getPrimaryBatchWeight(batch);
  const pond   = ponds.find(p => p.id === batch.pondId);

  const weightEl = $('batchCardWeight');
  const metaEl   = $('batchCardWeightMeta');
  const statusEl = $('batchCardWeightStatus');

  let daysSinceWeight = null;
  let lastUpdatedDisplay = '';
  if (latest) {
    lastUpdatedDisplay = latest.lastUpdatedDisplay;
    const today0 = startOfDay();
    const upd0   = startOfDay(latest.date + 'T00:00:00');
    daysSinceWeight = Math.floor((today0 - upd0) / MS_PER_DAY);
  }

  // Render Weight Value
  if (latest) {
    if (weightEl) {
      const displayVal = fmtWeightG(latest.weightGrams).replace('g', ' g');
      const suffix = latest.source === 'sampling' ? ' (Sample)' : ' (Visual)';
      weightEl.innerHTML = `${displayVal} <span style="font-size:0.75rem;font-weight:normal;color:var(--t3)">${suffix}</span>`;
    }
    if (metaEl) {
      metaEl.textContent = `DOC ${latest.doc} (${lastUpdatedDisplay})`;
    }
  } else {
    if (weightEl) weightEl.innerHTML = `<span class="bsc-weight-na">Not Recorded</span>`;
    if (metaEl) {
      metaEl.textContent = 'Never';
    }
  }

  // Render Warning / Status Banner (Active only)
  if (statusEl) {
    if (!isCompleted) {
      if (latest === null) {
        const freshness = getWeightFreshness(days);
        if (freshness === 'critical') {
          statusEl.innerHTML = `<span class="bsc-weight-status-critical">⚠ Outdated (Never Updated)</span>`;
        } else if (freshness === 'warning') {
          statusEl.innerHTML = `<span class="bsc-weight-status-warn">⚠ Update Recommended (Never Updated)</span>`;
        } else {
          statusEl.innerHTML = `<span class="bsc-weight-status-none">Never Updated</span>`;
        }
      } else {
        const freshness = getWeightFreshness(daysSinceWeight);
        if (freshness === 'critical') {
          statusEl.innerHTML = `<span class="bsc-weight-status-critical">⚠ Outdated (${lastUpdatedDisplay})</span>`;
        } else if (freshness === 'warning') {
          statusEl.innerHTML = `<span class="bsc-weight-status-warn">⚠ Update Recommended (${lastUpdatedDisplay})</span>`;
        } else {
          statusEl.innerHTML = `<span class="bsc-weight-status-ok">✓ Updated ${lastUpdatedDisplay}</span>`;
        }
      }
    } else {
      statusEl.innerHTML = '';
    }
  }

  // Quick action buttons: show for active, hide for completed
  const actionsEl = $('batchCardQuickActions');
  if (actionsEl) {
    if (isCompleted) {
      actionsEl.classList.add('hidden');
    } else {
      actionsEl.classList.remove('hidden');
      // Wire up Add Feed button — navigate to Log page with pond pre-selected.
      // 3-f fix: use .onclick (which auto-replaces) instead of addEventListener
      // to avoid listener leaks — renderBatchSummaryCard runs every time the
      // batch dashboard is opened, and addEventListener was stacking one new
      // listener per visit.
      const addFeedBtn = $('batchCardAddFeedBtn');
      if (addFeedBtn) {
        addFeedBtn.onclick = () => openQuickAddFeed(pond ? pond.id : '');
      }
      // Wire up Add Weight button
      const addWeightBtn = $('batchCardAddWeightBtn');
      if (addWeightBtn) {
        const samplings = getSamplingForBatch(batch.id);
        const hasSampling = samplings.length > 0;
        addWeightBtn.disabled = hasSampling;
        if (hasSampling) {
          addWeightBtn.setAttribute('title', 'Visual Weight disabled after first sampling entry.');
        } else {
          addWeightBtn.removeAttribute('title');
        }
        addWeightBtn.onclick = () => {
          if (!hasSampling) openLogWeightModal(batch.id);
        };

        // Dynamically style based on weight data freshness
        const freshness      = getWeightFreshness(latest === null ? days : daysSinceWeight);
        const isWeightCritical = freshness === 'critical';
        const isWeightWarning  = freshness === 'warning';

        let weightClass = 'abs-qa-btn--weight';
        if (isWeightCritical) {
          weightClass = 'abs-qa-btn--weight-critical';
        } else if (isWeightWarning) {
          weightClass = 'abs-qa-btn--weight-warning';
        }
        addWeightBtn.className = `abs-qa-btn ${weightClass}`;
      }

      // Wire up Add Sampling button
      const addSamplingBtn = $('batchCardAddSamplingBtn');
      if (addSamplingBtn) {
        addSamplingBtn.onclick = () => launchSampling(batch.id);
      }
    }
  }

  // Last Feed Status
  const lastFeedEl = $('batchLastFeedStatus');
  if (lastFeedEl) {
    if (isCompleted) {
      lastFeedEl.textContent = '';
    } else {
      const todayStr = fmt(new Date());
      const batchRecs = records.filter(r => r.BatchId === batch.id && r.Date === todayStr);
      let lastFeedText = "Waiting for Today's Feed";
      if (batchRecs.length > 0) {
        const sorted = batchRecs.slice().sort((a, b) => {
          const order = t => {
            if (!t) return 0;
            const pm = t.includes('PM');
            const [h, m] = (t.split(' ')[0]).split(':').map(Number);
            let h24 = h;
            if (pm && h !== 12) h24 += 12;
            if (!pm && h === 12) h24 = 0;
            return h24 * 60 + (m || 0);
          };
          return order(a.Time) - order(b.Time);
        });
        const latestRec = sorted[sorted.length - 1];
        if (latestRec && latestRec.Time) {
          lastFeedText = `Last Feed: Today ${latestRec.Time}`;
        }
      }
      lastFeedEl.textContent = lastFeedText;
    }
  }

  // Latest Sampling overview
  renderBatchSamplingOverview(batch);

  // Render biomass estimation
  renderBatchBiomassEstimation(batch);
}

function renderBatchBiomassEstimation(batch) {
  const el = $('batchBiomassSection');
  if (!el) return;

  const result = updateBatchBiomassEstimation(batch);
  const doc = getBatchCycleLength(batch);

  if (!result.success) {
    if (result.status === 'HAPA_MISSING') {
      el.innerHTML = `
        <div class="bsc-biomass-title">⚖ Biomass Estimation</div>
        <div class="bsc-biomass-warning-critical">
          <span>⚠️</span>
          <span>Hapa details missing, please fill Hapa first</span>
        </div>
      `;
    } else {
      el.innerHTML = `
        <div class="bsc-biomass-title">⚖ Biomass Estimation</div>
        <div class="bsc-biomass-warning-critical">
          <span>⚠️</span>
          <span>${result.message}</span>
        </div>
      `;
    }
    return;
  }

  let warningHTML = '';
  if (result.warning) {
    warningHTML = `
      <div class="bsc-biomass-warning">
        <span>⚠️</span>
        <span>${result.warning}</span>
      </div>
    `;
  }

  const abwDisplay = fmtWeightG(result.abw).replace('g', ' g');
  const popDisplay = Number(result.estimatedPopulation).toLocaleString();
  const biomassDisplay = `${Number(result.biomassKg).toLocaleString()} kg`;

  el.innerHTML = `
    <div class="bsc-biomass-title">⚖ Biomass Estimation</div>
    <div class="bsc-biomass-grid">
      <div class="bsc-biomass-item">
        <div class="bsc-biomass-lbl">DOC</div>
        <div class="bsc-biomass-val">${doc}</div>
      </div>
      <div class="bsc-biomass-item">
        <div class="bsc-biomass-lbl">ABW</div>
        <div class="bsc-biomass-val">${abwDisplay}</div>
      </div>
      <div class="bsc-biomass-item">
        <div class="bsc-biomass-lbl">Estimated Population</div>
        <div class="bsc-biomass-val">${popDisplay}</div>
      </div>
      <div class="bsc-biomass-item">
        <div class="bsc-biomass-lbl">Biomass</div>
        <div class="bsc-biomass-val" style="color:var(--teal);">${biomassDisplay}</div>
      </div>
    </div>
    ${warningHTML}
  `;
}

function hideAllBatchAnalytics() {
  ['growthTrackingHeader','growthTrackingCard',
   'growthFeedTrendHeader','growthFeedTrendCard',
  ].forEach(id => $(id)?.classList.add('hidden'));
}

function renderFarmDashboard() {
  // Skeleton: briefly show loading pulse on stat value while computing
  const heroNum = $('heroTotalNum');
  if (heroNum) { heroNum.style.opacity = '0.3'; }

  const now   = new Date();
  const today = fmt(now);

  // Greeting
  const h = now.getHours();
  const gr = h < 12
    ? 'Good Morning 🌅 · सुप्रभात'
    : h < 17
      ? 'Good Afternoon ☀️ · नमस्ते'
      : 'Good Evening 🌙 · शुभ संध्या';
  // Null-guard each hero element: during Next.js HMR the body may be briefly
  // re-injected, and an unguarded .textContent here would throw and freeze
  // the dashboard render mid-way.
  const _heroGreeting = $('heroGreeting'); if (_heroGreeting) _heroGreeting.textContent = gr;
  const _heroDate = $('heroDate'); if (_heroDate) _heroDate.textContent = now.toLocaleDateString('en-IN', {weekday:'long',day:'numeric',month:'long'});
  const hindiEl = document.getElementById('heroGreetingHindi');
  if (hindiEl) hindiEl.style.display = 'block';

  // Today's total
  const todayRecs = records.filter(r => r.Date === today);
  const todayGrams = sumGrams(todayRecs);
  const _heroTodayTotal = $('heroTodayTotal');
  if (_heroTodayTotal) {
    _heroTodayTotal.innerHTML = '<span id="heroTotalNum">0</span> <span class="hero-unit">g</span>';
  }
  animateValue($('heroTotalNum'), todayGrams, '', 700);
  const _heroTodaySessions = $('heroTodaySessions');
  if (_heroTodaySessions) _heroTodaySessions.textContent = `${todayRecs.length} session${todayRecs.length !== 1 ? 's' : ''} logged today`;

  // Pond chips
  const pondMap = {};
  todayRecs.forEach(r => { pondMap[r.PondName || r.Pond] = (pondMap[r.PondName || r.Pond]||0) + sumGrams([r]); });
  const _heroChips = $('heroChips');
  if (_heroChips) {
    _heroChips.innerHTML = Object.entries(pondMap).map(([p,g]) =>
      `<div class="hero-chip">${p}: <span>${fmtGrams(g)}g</span></div>`
    ).join('') || '<div class="hero-chip">No ponds fed today</div>';
  }

  // ── Fix #3: Redundant KPI cards (This Week / This Month / Active Ponds / Active Batches)
  // have been removed from the dashboard. They duplicate info available elsewhere
  // (Reports, Batches pages). Skipping their population here.

  if (heroNum) {
    heroNum.style.transition = 'opacity .3s ease';
    heroNum.style.opacity = '1';
  }

  // Today's sessions — Pond-Based Viewer
  renderPondSessionSelector();

  // Donut
  requestAnimationFrame(() => {
    drawDonutChart('chartDonut', feedSizeDistribution(records));
  });

  // ── Farm Analytics ──────────────────────────────────────
  hideAllBatchAnalytics();
  renderSamplingDashboardWarning(); // Sampling reminder banner
  renderActiveBatchSummaryCards(); // Feature 1: Active Batch Summary Cards
  renderFarmTrendChart();
  // ────────────────────────────────────────────────────────

  updateExportCount();
}

function renderPondSessionSelector() {
  const strip = $('pondSessionStrip');
  if (!strip) return;

  // Initialise date to today if not already set
  if (!selectedSessionDate) selectedSessionDate = fmt(new Date());

  // Build list of active batches sorted oldest-stocked first (= highest DOC)
  const activeBatchList = batches
    .filter(b => b.status === 'active')
    .slice()
    .sort((a, b) => {
      const da = a.stockingDate ? new Date(a.stockingDate) : new Date(0);
      const db = b.stockingDate ? new Date(b.stockingDate) : new Date(0);
      return da - db;
    });

  if (!activeBatchList.length) {
    strip.innerHTML = `<div class="ps-no-ponds">No active batches — stock a batch to see pond sessions.</div>`;
    const dnav = $('sessionDateNav'); if (dnav) dnav.innerHTML = '';
    const summ = $('pondSessionSummary'); if (summ) summ.innerHTML = '';
    const list = $('todaySessionsList'); if (list) list.innerHTML = '';
    return;
  }

  // Restore or default selected pond
  const validIds = new Set(activeBatchList.map(b => b.pondId));
  if (!selectedSessionPondId || !validIds.has(selectedSessionPondId)) {
    selectedSessionPondId = activeBatchList[0].pondId;
  }

  // ── Fix #5: Compact, scrollable pond selector ──
  // Build pond chips (compact, vertical layout so all chips are visible)
  strip.innerHTML = '';
  activeBatchList.forEach(batch => {
    const pond = ponds.find(p => p.id === batch.pondId);
    if (!pond) return;
    const doc  = calcDOC(batch.stockingDate);
    const chip = document.createElement('button');
    chip.className = 'ps-chip' + (pond.id === selectedSessionPondId ? ' active' : '');
    chip.dataset.pondId = pond.id;
    chip.innerHTML = `
      <span class="ps-chip-name">${escapeHTML(pond.name)}</span>
      <span class="ps-chip-batch">Batch #${batch.batchNumber}</span>
      <span class="ps-chip-doc">DOC ${doc}</span>`;
    chip.addEventListener('click', () => {
      selectedSessionPondId = pond.id;
      strip.querySelectorAll('.ps-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      updateScrollHint();
      renderPondSessionSummary(pond.id);
    });
    strip.appendChild(chip);
  });

  // ── Fix #5: Scroll hint dots below the strip ──
  // Remove any existing hint, then add one if there are multiple chips
  const section = strip.closest('.dash-section--sessions') || strip.parentElement;
  if (section) {
    const oldHint = section.querySelector('.ps-scroll-hint');
    if (oldHint) oldHint.remove();
    if (activeBatchList.length > 1) {
      const hint = document.createElement('div');
      hint.className = 'ps-scroll-hint';
      hint.innerHTML = activeBatchList.map((b, i) =>
        `<span class="ps-scroll-hint-dot${i === 0 ? ' active' : ''}" data-idx="${i}"></span>`
      ).join('');
      strip.insertAdjacentElement('afterend', hint);
    }
  }

  function updateScrollHint() {
    if (!section) return;
    const dots = section.querySelectorAll('.ps-scroll-hint-dot');
    if (!dots.length) return;
    // Determine which chip is closest to the visible center
    const stripRect = strip.getBoundingClientRect();
    const stripCenter = stripRect.left + stripRect.width / 2;
    let closestIdx = 0, closestDist = Infinity;
    strip.querySelectorAll('.ps-chip').forEach((c, i) => {
      const r = c.getBoundingClientRect();
      const center = r.left + r.width / 2;
      const d = Math.abs(center - stripCenter);
      if (d < closestDist) { closestDist = d; closestIdx = i; }
    });
    dots.forEach((d, i) => d.classList.toggle('active', i === closestIdx));
    // Toggle right-edge fade based on whether user is at the end
    const atEnd = strip.scrollLeft + strip.clientWidth >= strip.scrollWidth - 4;
    strip.classList.toggle('is-scrolled-end', atEnd);
  }

  strip.addEventListener('scroll', updateScrollHint, { passive: true });
  // Initial sync after layout
  requestAnimationFrame(updateScrollHint);

  // Render date navigator then summary
  renderSessionDateNav();
  renderPondSessionSummary(selectedSessionPondId);
}

function renderSessionDateNav() {
  const container = $('sessionDateNav');
  if (!container) return;

  const today     = fmt(new Date());
  const yesterday = fmt(new Date(new Date().setDate(new Date().getDate() - 1)));

  if (!selectedSessionDate) selectedSessionDate = today;

  const isToday     = selectedSessionDate === today;
  const isYesterday = selectedSessionDate === yesterday;
  const isCustom    = !isToday && !isYesterday;

  const canGoNext = selectedSessionDate < today; // cannot go past today

  // Human-readable date for the nav row
  const dateObj = startOfDay(selectedSessionDate);
  const displayDate = dateObj.toLocaleDateString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric'
  });
  const dayLabel = isToday ? 'Today' : isYesterday ? 'Yesterday' : dateObj.toLocaleDateString('en-US', { weekday: 'short' });

  container.className = 'session-date-nav';
  container.innerHTML = `
    <!-- Quick tabs -->
    <div class="sdn-tabs">
      <button class="sdn-tab${isToday ? ' active' : ''}" id="sdnTabToday">Today</button>
      <button class="sdn-tab${isYesterday ? ' active' : ''}" id="sdnTabYesterday">Yesterday</button>
      <button class="sdn-tab${isCustom ? ' active' : ''}" id="sdnTabCustom">Custom 📅</button>
    </div>
    <!-- Navigation row -->
    <div class="sdn-nav">
      <button class="sdn-arrow" id="sdnPrev" aria-label="Previous day">◄</button>
      <div class="sdn-date-display" id="sdnDateDisplay">
        <span class="sdn-date-text">${displayDate}</span>
        <span class="sdn-date-sub">${dayLabel}</span>
        <input type="date" class="sdn-date-input" id="sdnDateInput"
               value="${selectedSessionDate}" max="${today}"
               aria-label="Pick a date">
      </div>
      <button class="sdn-arrow" id="sdnNext" aria-label="Next day"${canGoNext ? '' : ' disabled'}>►</button>
    </div>`;

  function goToDate(dateStr) {
    selectedSessionDate = dateStr;
    renderSessionDateNav();
    renderPondSessionSummary(selectedSessionPondId);
  }

  $('sdnTabToday')?.addEventListener('click',     () => goToDate(today));
  $('sdnTabYesterday')?.addEventListener('click', () => goToDate(yesterday));
  $('sdnTabCustom')?.addEventListener('click',    () => {
    const inp = $('sdnDateInput');
    if (inp) { try { inp.showPicker(); } catch { inp.click(); } }
  });
  $('sdnPrev')?.addEventListener('click', () => {
    const d = startOfDay(selectedSessionDate);
    d.setDate(d.getDate() - 1);
    goToDate(fmt(d));
  });
  $('sdnNext')?.addEventListener('click', () => {
    if (!canGoNext) return;
    const d = startOfDay(selectedSessionDate);
    d.setDate(d.getDate() + 1);
    goToDate(fmt(d));
  });
  $('sdnDateInput')?.addEventListener('change', function () {
    if (this.value) goToDate(this.value);
  });
  // Clicking anywhere on the display row also opens the picker
  $('sdnDateDisplay')?.addEventListener('click', e => {
    if (!e.isTrusted) return;
    const inp = $('sdnDateInput');
    if (inp) { try { inp.showPicker(); } catch { inp.click(); } }
  });
}

function renderPondSessionSummary(pondId) {
  const summaryWrap  = $('pondSessionSummary');
  if (!summaryWrap) return;

  const today    = fmt(new Date());
  const viewDate = selectedSessionDate || today;

  const pond  = ponds.find(p => p.id === pondId);

  // ── Determine which batch to show feed sessions for ──
  // Priority:
  //   1. If the dashboard dropdown has a specific batch selected, use that batch
  //      (this is critical for completed batches — otherwise we'd find an active
  //      batch on the pond and show its empty feed data instead of the completed
  //      batch's historical feed logs).
  //   2. Otherwise, find the batch that was active on the selected date.
  const select = $('dashboardContextSelect');
  const ctxVal = select ? select.value : 'farm';
  let batch = null;
  if (ctxVal && ctxVal.startsWith('batch_')) {
    const ctxBatchId = ctxVal.replace('batch_', '');
    batch = batches.find(b => b.id === ctxBatchId);
  }
  if (!batch) {
    batch = batches.find(b =>
      b.pondId === pondId &&
      b.status === 'active'
    ) || batches.find(b =>
      b.pondId === pondId &&
      b.stockingDate <= viewDate &&
      (!b.harvestDate || b.harvestDate >= viewDate)
    );
  }

  if (!pond || !batch) {
    summaryWrap.innerHTML = `<div class="pss-card">
      <div class="pss-empty">
        <span class="pss-empty-icon">📄</span>
        <span class="pss-empty-text">No active batch in this pond.</span>
        <span class="pss-empty-sub">Select a pond with an active batch to view its feed sessions.</span>
      </div>
    </div>`;
    return;
  }

  const doc = calcDOC(batch.stockingDate);

  // Filter records to selected pond + batch + date
  const dateRecs = records.filter(r =>
    r.Date === viewDate &&
    r.PondId === pondId &&
    r.BatchId === batch.id
  );

  // ── Fix #6: Daily Feed Timeline ──
  // Build a data-driven timeline of feed sessions. Standard sessions are
  // Morning (7 AM), Midday (11 AM), Afternoon (4 PM), Evening (7 PM).
  // Any additional feed entries with non-standard times are appended in
  // chronological order. Total feed consumed is always shown.
  const STANDARD_SESSIONS = [
    { key: 'morning',   label: 'Morning',   icon: '🌅', time: '7:00 AM',  hour: 7  },
    { key: 'midday',    label: 'Midday',    icon: '☀️', time: '11:00 AM', hour: 11 },
    { key: 'afternoon', label: 'Afternoon', icon: '🌤', time: '4:00 PM',  hour: 16 },
    { key: 'evening',   label: 'Evening',   icon: '🌙', time: '7:00 PM',  hour: 19 }
  ];

  // Match a record to a standard session by exact time string OR by hour
  function matchesStandard(rec, sess) {
    const t = rec.Time || '';
    if (t === sess.time) return true;
    // Parse "H:MM AM/PM" and compare hour
    const m = String(t).match(/(\d+):(\d+)\s*(AM|PM)?/i);
    if (!m) return false;
    let h = parseInt(m[1], 10);
    const ap = m[3] ? m[3].toUpperCase() : null;
    if (ap === 'PM' && h !== 12) h += 12;
    if (ap === 'AM' && h === 12) h = 0;
    return h === sess.hour;
  }

  // Group records into standard sessions and "custom" sessions
  const sessionBuckets = STANDARD_SESSIONS.map(s => ({ ...s, recs: [] }));
  const customRecs = [];

  dateRecs.forEach(r => {
    const matchedIdx = sessionBuckets.findIndex(s => matchesStandard(r, s));
    if (matchedIdx >= 0) {
      sessionBuckets[matchedIdx].recs.push(r);
    } else {
      customRecs.push(r);
    }
  });

  // Sort custom recs chronologically by parsed hour
  function parseHour(t) {
    const m = String(t || '').match(/(\d+):(\d+)\s*(AM|PM)?/i);
    if (!m) return 99;
    let h = parseInt(m[1], 10);
    const ap = m[3] ? m[3].toUpperCase() : null;
    if (ap === 'PM' && h !== 12) h += 12;
    if (ap === 'AM' && h === 12) h = 0;
    return h;
  }
  customRecs.sort((a, b) => parseHour(a.Time) - parseHour(b.Time));

  // Append custom sessions to the timeline
  const allSessions = sessionBuckets.concat(
    customRecs.map((r, i) => ({
      key: 'custom_' + i,
      label: 'Extra',
      icon: '🍽',
      time: r.Time || '—',
      hour: parseHour(r.Time),
      recs: [r]
    }))
  );

  const totalG = sumGrams(dateRecs);

  // Update section title (now inside .dash-section-header)
  const isToday     = viewDate === today;
  const isYesterday = viewDate === fmt(new Date(new Date().setDate(new Date().getDate() - 1)));
  const titleEl = $('sessionSectionTitle');
  if (titleEl) {
    titleEl.textContent = isToday
      ? "Today's Sessions"
      : isYesterday
        ? "Yesterday's Sessions"
        : `Sessions — ${startOfDay(viewDate).toLocaleDateString('en-GB', { day:'2-digit', month:'short' })}`;
  }

  // Total label adapts to selected date
  const totalLbl = isToday ? 'Total Today' : isYesterday ? 'Total Yesterday' : 'Total Feed';

  function slotHTML(sess) {
    const g = sumGrams(sess.recs);
    const hasData = g > 0;
    const val  = hasData ? fmtGrams(g) : '—';
    const unit = hasData ? 'g' : '';
    const sessionCount = sess.recs.length > 1 ? `<span class="pss-slot-time">${sess.recs.length} entries</span>` : `<span class="pss-slot-time">${sess.time}</span>`;
    return `<div class="pss-slot${hasData ? ' has-data' : ''}" title="${escapeHTML(sess.label + ' · ' + sess.time)}">
      <span class="pss-slot-icon">${sess.icon}</span>
      <span class="pss-slot-lbl">${sess.label}</span>
      ${sessionCount}
      <span class="pss-slot-val">${val}<span class="pss-slot-unit">${unit}</span></span>
    </div>`;
  }

  const slotsHTML = allSessions.map(slotHTML).join('');
  const totalDisplay = totalG > 0
    ? `${fmtGrams(totalG)}<span class="pss-timeline-total-unit">g</span>`
    : '<span style="font-size:.95rem;color:var(--t3);">—</span>';

  const emptyMsg = 'No Records Available';
  const emptySub = isToday
    ? (batch.status === 'completed'
        ? `This batch was harvested on ${batch.harvestDate || 'a past date'}. Use ◄ or the date picker to view feed sessions from the culture cycle.`
        : 'Tap + to log a feeding session')
    : `No sessions were logged for ${startOfDay(viewDate).toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' })}`;

  summaryWrap.innerHTML = `<div class="pss-card">
    <div class="pss-header">
      <div>
        <div class="pss-pond-name">${escapeHTML(pond.name)}</div>
        <div class="pss-meta">
          <span class="pss-badge batch">Batch #${batch.batchNumber}</span>
          <span class="pss-badge doc">DOC ${doc}</span>
        </div>
      </div>
      <div class="pss-total-wrap">
        <div class="pss-total-lbl">${totalLbl}</div>
        <div class="pss-total-val">${totalG > 0 ? fmtGrams(totalG) : '—'}<span class="pss-total-unit">${totalG > 0 ? 'g' : ''}</span></div>
      </div>
    </div>
    ${dateRecs.length === 0
      ? `<div class="pss-empty">
           <span class="pss-empty-icon">📄</span>
           <span class="pss-empty-text">${emptyMsg}</span>
           <span class="pss-empty-sub">${emptySub}</span>
         </div>`
      : `<div class="pss-slots pss-slots--count-${allSessions.length}">
           ${slotsHTML}
         </div>
         <div class="pss-timeline-total">
           <span class="pss-timeline-total-lbl">${totalLbl} (${dateRecs.length} session${dateRecs.length !== 1 ? 's' : ''})</span>
           <span class="pss-timeline-total-val">${totalDisplay}</span>
         </div>
         <div id="todaySessionsList" class="sessions-list sessions-list-mt"></div>`
    }
  </div>`;

  // Render filtered session cards — most recent first (inside the unified card)
  if (dateRecs.length > 0) {
    const sessionsList = $('todaySessionsList');
    if (sessionsList) {
      renderSessionsList(sessionsList, dateRecs.slice().reverse());
    }
  }
}

function calcWoWTrend(thisWeekRecs, prevWeekRecs) {
  const thisWeek = thisWeekRecs.filter(r => isInLastNDays(r.Date, 7)).reduce((s, r) => s + sumGrams([r]), 0);
  const prevWeek = prevWeekRecs.reduce((s, r) => s + sumGrams([r]), 0);

  if (!prevWeek) return { dir: 'fl', txt: '→ No prior week data' };
  const pct = Math.round(((thisWeek - prevWeek) / prevWeek) * 100);
  if (pct > 0)  return { dir: 'up', txt: `↑ +${pct}% vs last week` };
  if (pct < 0)  return { dir: 'dn', txt: `↓ ${pct}% vs last week` };
  return { dir: 'fl', txt: '→ Same as last week' };
}

function getWeightFreshness(daysSince) {
  if (daysSince === null || daysSince === undefined) return 'never';
  if (daysSince >= 14) return 'critical';
  if (daysSince >= 7)  return 'warning';
  return 'ok';
}

function showDashboardSkeleton() {
  const hero = document.querySelector('.hero-card');
  if (!hero || hero.dataset.loaded) return;
  hero.dataset.loading = 'true';
}

function hideDashboardSkeleton() {
  const hero = document.querySelector('.hero-card');
  if (hero) delete hero.dataset.loading;
}

function showFarmView() {
  $('farmOverviewContent').classList.remove('hidden');
  $('batchSummaryCard').classList.add('hidden');
  $('docChartHeader').classList.add('hidden');
  $('docChartSection').classList.add('hidden');
  $('weatherIntelligenceSection').classList.add('hidden');
  // Sessions section is visible in both views — but pond selector only shows in Farm view
  const sessionsWrap = $('sessionsSectionWrap');
  if (sessionsWrap) {
    sessionsWrap.classList.remove('hidden');
    sessionsWrap.classList.remove('batch-mode');
  }
  const pondStrip = $('pondSessionStrip');
  if (pondStrip) pondStrip.classList.remove('hidden');
  stopWeatherAutoRefresh(); // stop auto-refresh when leaving pond overview
  renderFarmDashboard();
}

function showBatchView(batch) {
  $('farmOverviewContent').classList.add('hidden');
  $('batchSummaryCard').classList.remove('hidden');
  $('docChartHeader').classList.remove('hidden');
  $('docChartSection').classList.remove('hidden');

  // ── Fix: Sessions section stays visible in Batch view too ──
  // The pond selector chips are hidden (the pond is already chosen via the
  // dashboard dropdown), but the Daily Feed Timeline + date nav remain
  // so the user can see feed sessions for the selected batch's pond.
  const sessionsWrap = $('sessionsSectionWrap');
  if (sessionsWrap) {
    sessionsWrap.classList.remove('hidden');
    sessionsWrap.classList.add('batch-mode');
  }
  // Hide pond selector strip in batch view — pond is implicit
  const pondStrip = $('pondSessionStrip');
  if (pondStrip) pondStrip.classList.add('hidden');
  // Force the selected pond to the batch's pond
  if (batch && batch.pondId) {
    selectedSessionPondId = batch.pondId;
  }

  // Weather intelligence for this specific pond's site
  const pond = ponds.find(p => p.id === batch.pondId);
  const site = pond && window.SiteManager ? window.SiteManager.getSiteById(pond.siteId) : null;
  if (batch.status === 'active' && site && window.SiteManager.hasLocation(site)) {
    $('weatherIntelligenceSection').classList.remove('hidden');
    renderWeatherIntelligence(site);
    startWeatherAutoRefresh(site); // begin 10-min background auto-refresh
  } else {
    $('weatherIntelligenceSection').classList.add('hidden');
    stopWeatherAutoRefresh();
  }

  // Update the batch shortcut button
  updateBatchShortcut(batch);

  renderBatchDashboard(batch);

  // ── Fix: Render the Daily Feed Timeline for this batch's pond ──
  // In batch view, we skip renderPondSessionSelector (which builds pond chips)
  // and go straight to renderSessionDateNav + renderPondSessionSummary.
  if (batch && batch.pondId) {
    if (!selectedSessionDate) selectedSessionDate = fmt(new Date());
    renderSessionDateNav();
    renderPondSessionSummary(batch.pondId);
  }
}

/* ── Batch shortcut button: shows/hides a floating "View Batch" button above the bottom nav ── */
function updateBatchShortcut(batch) {
  const btn = $('batchShortcutBtn');
  const textEl = $('batchShortcutText');
  if (!btn) return;

  if (batch) {
    const pond = ponds.find(p => p.id === batch.pondId);
    const pondName = pond ? pond.name : (batch.pond || 'Batch');
    if (textEl) textEl.textContent = `${pondName} · #${batch.batchNumber}`;
    btn.classList.remove('hidden');
  } else {
    btn.classList.add('hidden');
  }
}

// Window bindings for backward compatibility
window.populateContextSelector = populateContextSelector;
window.renderDashboard = renderDashboard;
window.anFmtKg = anFmtKg;
window.anMostUsedFeedSize = anMostUsedFeedSize;
window.anHighestDay = anHighestDay;
window.anHighestDOC = anHighestDOC;
window.renderFarmTotalFeedCard = renderFarmTotalFeedCard;
window.renderFarmTrendChart = renderFarmTrendChart;
window.renderFarmMonthlyConsumption = renderFarmMonthlyConsumption;
window.renderActiveBatchSummaryCards = renderActiveBatchSummaryCards;
window.openQuickAddFeed = openQuickAddFeed;
window.renderBatchSummaryCard = renderBatchSummaryCard;
window.renderBatchBiomassEstimation = renderBatchBiomassEstimation;
window.hideAllBatchAnalytics = hideAllBatchAnalytics;
window.renderFarmDashboard = renderFarmDashboard;
window.renderPondSessionSelector = renderPondSessionSelector;
window.renderSessionDateNav = renderSessionDateNav;
window.renderPondSessionSummary = renderPondSessionSummary;
window.calcWoWTrend = calcWoWTrend;
window.getWeightFreshness = getWeightFreshness;
window.showDashboardSkeleton = showDashboardSkeleton;
window.hideDashboardSkeleton = hideDashboardSkeleton;
window.showFarmView = showFarmView;
window.showBatchView = showBatchView;
window.updateBatchShortcut = updateBatchShortcut;
})();

// --- Module: finance.js ---
(function() {
  'use strict';
  const { escapeHTML, fmt, fmtDateDisplay, todayStr, genId, toNumber, calcDOC } = AppUtils;

  const EXPENSE_CATEGORIES = Object.freeze([
    'feed', 'medicine', 'fuel', 'seed', 'labor', 'electricity',
    'maintenance', 'rent', 'equipment', 'other'
  ]);
  const EXPENSE_LABELS = {
    feed: 'Feed', medicine: 'Medicine', fuel: 'Fuel', seed: 'Seed / Post-larvae',
    labor: 'Labor', electricity: 'Electricity', maintenance: 'Pond Maintenance',
    rent: 'Rent', equipment: 'Equipment', other: 'Other'
  };
  const EXPENSE_ICONS = {
    feed: '🌾', medicine: '💊', fuel: '⛽', seed: '🦐', labor: '👷',
    electricity: '⚡', maintenance: '🔧', rent: '🏠', equipment: '🛠️', other: '📦'
  };

  let financeTab = 'overview';

  /* ── Cost aggregation from inventory ── */
  // Site-wide inventory cost cache — avoids re-iterating all inventory txs per batch
  // and prevents the previous bug where each batch was attributed the FULL site total
  // (multiplying site-wide costs by the number of batches on the site).
  const _siteInventoryCostCache = new Map();
  function _getSiteInventoryCosts(siteId) {
    if (!siteId) return { feed: 0, medicine: 0, fuel: 0, totalFeedGrams: 0 };
    if (_siteInventoryCostCache.has(siteId)) return _siteInventoryCostCache.get(siteId);
    const allTx = window.AppStorage.getInventoryByCategory(siteId, 'feed')
      .concat(window.AppStorage.getInventoryByCategory(siteId, 'medicine'))
      .concat(window.AppStorage.getInventoryByCategory(siteId, 'fuel'));
    const result = { feed: 0, medicine: 0, fuel: 0, totalFeedGrams: 0 };
    allTx.forEach(t => {
      if (t.type === 'purchase' && result[t.category] !== undefined) {
        result[t.category] += Number(t.totalCost) || 0;
      }
    });
    // Total feed consumed (in grams) across ALL batches on this site — used as the
    // allocation denominator so each batch only gets its proportional share of cost.
    const siteBatches = (window.AppStorage.getBatches ? window.AppStorage.getBatches() : batches).filter(b => {
      const p = (window.AppStorage.getPonds() || []).find(pp => pp.id === b.pondId);
      return p && p.siteId === siteId;
    });
    siteBatches.forEach(b => { result.totalFeedGrams += getBatchTotalFeedGrams(b.id); });
    _siteInventoryCostCache.set(siteId, result);
    return result;
  }

  function getInventoryCostsForBatch(batch) {
    if (!batch) return { feed: 0, medicine: 0, fuel: 0 };
    const pond = (window.AppStorage.getPonds() || []).find(p => p.id === batch.pondId);
    const siteId = pond ? pond.siteId : null;
    if (!siteId) return { feed: 0, medicine: 0, fuel: 0 };
    const site = _getSiteInventoryCosts(siteId);
    // Allocate site-wide costs proportionally based on this batch's share of total
    // site feed consumption. Falls back to an even split when no feed has been
    // consumed yet (avoids divide-by-zero).
    const batchFeedGrams = getBatchTotalFeedGrams(batch.id);
    const ratio = site.totalFeedGrams > 0 ? Math.min(batchFeedGrams / site.totalFeedGrams, 1) : 0;
    return {
      feed: site.feed * ratio,
      medicine: site.medicine * ratio,
      fuel: site.fuel * ratio
    };
  }

  function getManualExpenses(batchId, siteId) {
    const all = window.AppStorage.getFinanceExpenses();
    return all.filter(e => {
      if (batchId && e.batchId === batchId) return true;
      if (!batchId && siteId && e.siteId === siteId) return true;
      if (!batchId && !siteId) return true;
      return false;
    });
  }

  function getBatchCosts(batch) {
    if (!batch) return { total: 0, breakdown: {} };
    const invCosts = getInventoryCostsForBatch(batch);
    const manualExpenses = getManualExpenses(batch.id);
    const breakdown = {};
    breakdown.feed = invCosts.feed;
    breakdown.medicine = invCosts.medicine;
    breakdown.fuel = invCosts.fuel;
    manualExpenses.forEach(e => {
      breakdown[e.category] = (breakdown[e.category] || 0) + (Number(e.amount) || 0);
    });
    const total = Object.values(breakdown).reduce((s, v) => s + v, 0);
    return { total, breakdown };
  }

  function getBatchRevenue(batch) {
    if (!batch) return { total: 0, entries: [] };
    const revenue = window.AppStorage.getFinanceRevenue().filter(r => r.batchId === batch.id);
    const total = revenue.reduce((s, r) => s + (Number(r.totalAmount) || 0), 0);
    return { total, entries: revenue };
  }

  function getBatchProfit(batch) {
    const costs = getBatchCosts(batch);
    const revenue = getBatchRevenue(batch);
    const profit = revenue.total - costs.total;
    const margin = revenue.total > 0 ? (profit / revenue.total) * 100 : 0;
    const harvestWeightKg = Number(batch.harvestWeightKg) || 0;
    const breakEvenPrice = harvestWeightKg > 0 ? costs.total / harvestWeightKg : 0;
    return { costs, revenue, profit, margin, breakEvenPrice, harvestWeightKg };
  }

  function getLatestMarketPrice() {
    const prices = window.AppStorage.getMarketPrices().slice().sort((a, b) => b.date.localeCompare(a.date));
    return prices.length ? prices[0] : null;
  }

  function getProjectedRevenue(batch) {
    const biomassKg = (function() {
      try { return updateBatchBiomassEstimation(batch).biomassKg || 0; } catch { return 0; }
    })();
    const latestPrice = getLatestMarketPrice();
    const pricePerKg = latestPrice ? Number(latestPrice.pricePerKg) : 0;
    return { biomassKg, pricePerKg, projectedRevenue: biomassKg * pricePerKg };
  }

  /* ── Formatting helpers ── */
  function fmtCurrency(amount) {
    const n = Number(amount) || 0;
    if (Math.abs(n) >= 100000) return '₹' + (n / 100000).toFixed(2) + 'L';
    if (Math.abs(n) >= 1000) return '₹' + (n / 1000).toFixed(1) + 'K';
    return '₹' + n.toFixed(0);
  }
  function fmtCurrencyFull(amount) {
    return '₹' + (Number(amount) || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 });
  }

  /* ── Rendering: Overview Tab ── */
  function renderFinanceOverview() {
    const container = $('financeOverviewTab');
    if (!container) return;

    const allBatches = batches.slice();
    const activeBatches = allBatches.filter(b => b.status === 'active');
    const completedBatches = allBatches.filter(b => b.status === 'completed');

    // Aggregate costs across all batches
    let totalCosts = 0, totalRevenue = 0, totalProjected = 0;
    const costBreakdown = {};
    allBatches.forEach(b => {
      const c = getBatchCosts(b);
      totalCosts += c.total;
      Object.entries(c.breakdown).forEach(([k, v]) => { costBreakdown[k] = (costBreakdown[k] || 0) + v; });
      const r = getBatchRevenue(b);
      totalRevenue += r.total;
      if (b.status === 'active') {
        const proj = getProjectedRevenue(b);
        totalProjected += proj.projectedRevenue;
      }
    });

    const totalProfit = totalRevenue - totalCosts;
    const latestPrice = getLatestMarketPrice();

    container.innerHTML = `
      <div class="fin-kpi-grid">
        <div class="fin-kpi-card ${totalProfit >= 0 ? 'positive' : 'negative'}">
          <div class="fin-kpi-icon">${totalProfit >= 0 ? '📈' : '📉'}</div>
          <div class="fin-kpi-val">${fmtCurrencyFull(totalProfit)}</div>
          <div class="fin-kpi-lbl">Net Profit / Loss</div>
        </div>
        <div class="fin-kpi-card">
          <div class="fin-kpi-icon">💰</div>
          <div class="fin-kpi-val">${fmtCurrencyFull(totalRevenue)}</div>
          <div class="fin-kpi-lbl">Total Revenue (Realized)</div>
        </div>
        <div class="fin-kpi-card">
          <div class="fin-kpi-icon">🔮</div>
          <div class="fin-kpi-val">${fmtCurrencyFull(totalProjected)}</div>
          <div class="fin-kpi-lbl">Projected Revenue (Active)</div>
        </div>
        <div class="fin-kpi-card">
          <div class="fin-kpi-icon">💸</div>
          <div class="fin-kpi-val">${fmtCurrencyFull(totalCosts)}</div>
          <div class="fin-kpi-lbl">Total Costs</div>
        </div>
      </div>

      ${latestPrice ? `
      <div class="fin-price-banner">
        <div class="fin-price-icon">🏷️</div>
        <div class="fin-price-info">
          <div class="fin-price-lbl">Latest Market Price</div>
          <div class="fin-price-val">₹${Number(latestPrice.pricePerKg).toFixed(0)}/kg</div>
        </div>
        <div class="fin-price-meta">
          <div>${fmtDateDisplay(latestPrice.date)}</div>
          ${latestPrice.sizeCategory ? `<div style="opacity:0.7;font-size:0.75rem">${escapeHTML(latestPrice.sizeCategory)}</div>` : ''}
        </div>
      </div>` : ''}

      <div class="section-title-sm mt16">Cost Breakdown</div>
      <div class="fin-cost-breakdown">
        ${Object.entries(costBreakdown)
          .filter(([k, v]) => v > 0)
          .sort((a, b) => b[1] - a[1])
          .map(([cat, amt]) => {
            const pct = totalCosts > 0 ? (amt / totalCosts) * 100 : 0;
            return `
              <div class="fin-cost-row">
                <div class="fin-cost-icon">${EXPENSE_ICONS[cat] || '📦'}</div>
                <div class="fin-cost-info">
                  <div class="fin-cost-name">${EXPENSE_LABELS[cat] || cat}</div>
                  <div class="fin-cost-bar-wrap">
                    <div class="fin-cost-bar" style="width:${pct.toFixed(1)}%"></div>
                  </div>
                </div>
                <div class="fin-cost-amount">
                  <div class="fin-cost-val">${fmtCurrencyFull(amt)}</div>
                  <div class="fin-cost-pct">${pct.toFixed(1)}%</div>
                </div>
              </div>`;
          }).join('') || '<div class="fin-empty">No costs recorded yet</div>'}
      </div>

      <div class="section-title-sm mt16">Batch Profitability</div>
      <div class="fin-batch-list">
        ${allBatches.slice().reverse().map(b => {
          const p = getBatchProfit(b);
          const pond = ponds.find(pd => pd.id === b.pondId);
          const pondName = pond ? pond.name : (b.pond || '—');
          const proj = b.status === 'active' ? getProjectedRevenue(b) : null;
          return `
            <div class="fin-batch-card ${p.profit >= 0 ? 'profit' : 'loss'}" data-batch-id="${b.id}">
              <div class="fin-batch-header">
                <div class="fin-batch-name">${escapeHTML(pondName)} · Batch #${b.batchNumber}</div>
                <div class="fin-batch-status ${b.status}">${b.status === 'active' ? 'ACTIVE' : 'COMPLETED'}</div>
              </div>
              <div class="fin-batch-stats">
                <div class="fin-bs-item">
                  <div class="fin-bs-lbl">Costs</div>
                  <div class="fin-bs-val">${fmtCurrency(p.costs.total)}</div>
                </div>
                <div class="fin-bs-item">
                  <div class="fin-bs-lbl">Revenue</div>
                  <div class="fin-bs-val">${fmtCurrency(p.revenue.total)}</div>
                </div>
                <div class="fin-bs-item">
                  <div class="fin-bs-lbl">${b.status === 'active' ? 'Projected' : 'Profit'}</div>
                  <div class="fin-bs-val ${b.status === 'active' ? '' : (p.profit >= 0 ? 'pos' : 'neg')}">
                    ${b.status === 'active' ? fmtCurrency(proj.projectedRevenue) : fmtCurrency(p.profit)}
                  </div>
                </div>
                <div class="fin-bs-item">
                  <div class="fin-bs-lbl">Break-even</div>
                  <div class="fin-bs-val">${p.breakEvenPrice > 0 ? '₹' + p.breakEvenPrice.toFixed(0) + '/kg' : '—'}</div>
                </div>
              </div>
            </div>`;
        }).join('') || '<div class="fin-empty">No batches yet</div>'}
      </div>
    `;
  }

  /* ── Rendering: Expenses Tab ── */
  function renderExpensesTab() {
    const container = $('financeExpensesTab');
    if (!container) return;
    const expenses = window.AppStorage.getFinanceExpenses().slice().sort((a, b) => b.date.localeCompare(a.date));
    const total = expenses.reduce((s, e) => s + (Number(e.amount) || 0), 0);

    container.innerHTML = `
      <div class="fin-tab-header">
        <div class="fin-tab-total">
          <span class="fin-tab-total-lbl">Total Manual Expenses</span>
          <span class="fin-tab-total-val">${fmtCurrencyFull(total)}</span>
        </div>
        <button class="pill-btn green-btn fin-add-btn" data-action="openAddExpenseModal">＋ Add Expense</button>
      </div>
      ${expenses.length ? `
        <div class="fin-table-wrap">
          <table class="fin-table">
            <thead>
              <tr><th>Date</th><th>Category</th><th>Description</th><th>Amount</th><th></th></tr>
            </thead>
            <tbody>
              ${expenses.map(e => {
                const pond = ponds.find(p => p.id === e.pondId);
                const batch = batches.find(b => b.id === e.batchId);
                let scope = '';
                if (batch) scope = ` · ${escapeHTML(pond ? pond.name : '')} #${batch.batchNumber}`;
                else if (pond) scope = ` · ${escapeHTML(pond.name)}`;
                return `
                <tr>
                  <td class="fin-td-date">${fmtDateDisplay(e.date)}</td>
                  <td class="fin-td-cat"><span class="fin-cat-badge">${EXPENSE_ICONS[e.category] || '📦'} ${EXPENSE_LABELS[e.category] || e.category}</span></td>
                  <td class="fin-td-desc">${escapeHTML(e.description || '')}${scope ? `<span class="fin-scope">${scope}</span>` : ''}</td>
                  <td class="fin-td-amt">${fmtCurrencyFull(e.amount)}</td>
                  <td class="fin-td-action"><button class="fin-del-btn" data-action="deleteExpense" data-id="${e.id}" aria-label="Delete">✕</button></td>
                </tr>`;
              }).join('')}
            </tbody>
          </table>
        </div>` : '<div class="fin-empty">No manual expenses recorded yet.<br>Feed, medicine & fuel costs are auto-tracked from inventory purchases.</div>'}
    `;
  }

  /* ── Rendering: Revenue Tab ── */
  function renderRevenueTab() {
    const container = $('financeRevenueTab');
    if (!container) return;
    const revenue = window.AppStorage.getFinanceRevenue().slice().sort((a, b) => b.date.localeCompare(a.date));
    const total = revenue.reduce((s, r) => s + (Number(r.totalAmount) || 0), 0);
    const totalKg = revenue.reduce((s, r) => s + (Number(r.weightKg) || 0), 0);

    container.innerHTML = `
      <div class="fin-tab-header">
        <div class="fin-tab-total">
          <span class="fin-tab-total-lbl">Total Revenue · ${totalKg.toFixed(1)} kg sold</span>
          <span class="fin-tab-total-val">${fmtCurrencyFull(total)}</span>
        </div>
        <button class="pill-btn green-btn fin-add-btn" data-action="openAddRevenueModal">＋ Add Sale</button>
      </div>
      ${revenue.length ? `
        <div class="fin-table-wrap">
          <table class="fin-table">
            <thead>
              <tr><th>Date</th><th>Batch</th><th>Weight</th><th>₹/kg</th><th>Total</th><th></th></tr>
            </thead>
            <tbody>
              ${revenue.map(r => {
                const batch = batches.find(b => b.id === r.batchId);
                const pond = batch ? ponds.find(p => p.id === batch.pondId) : null;
                const batchLabel = batch ? `${escapeHTML(pond ? pond.name : '')} #${batch.batchNumber}` : '—';
                return `
                <tr>
                  <td class="fin-td-date">${fmtDateDisplay(r.date)}</td>
                  <td class="fin-td-batch">${batchLabel}</td>
                  <td class="fin-td-wt">${Number(r.weightKg).toFixed(1)} kg</td>
                  <td class="fin-td-price">₹${Number(r.pricePerKg).toFixed(0)}</td>
                  <td class="fin-td-amt">${fmtCurrencyFull(r.totalAmount)}</td>
                  <td class="fin-td-action"><button class="fin-del-btn" data-action="deleteRevenue" data-id="${r.id}" aria-label="Delete">✕</button></td>
                </tr>`;
              }).join('')}
            </tbody>
          </table>
        </div>` : '<div class="fin-empty">No sales recorded yet.<br>Add a sale when you harvest and sell shrimp.</div>'}
    `;
  }

  /* ── Rendering: Market Prices Tab ── */
  function renderPricesTab() {
    const container = $('financePricesTab');
    if (!container) return;
    const prices = window.AppStorage.getMarketPrices().slice().sort((a, b) => b.date.localeCompare(a.date));

    container.innerHTML = `
      <div class="fin-tab-header">
        <div class="fin-tab-total">
          <span class="fin-tab-total-lbl">Market Price History</span>
          <span class="fin-tab-total-val">${prices.length} entries</span>
        </div>
        <button class="pill-btn green-btn fin-add-btn" data-action="openAddPriceModal">＋ Add Price</button>
      </div>
      ${prices.length ? `
        <div class="fin-table-wrap">
          <table class="fin-table">
            <thead>
              <tr><th>Date</th><th>₹/kg</th><th>Size</th><th>Location</th><th></th></tr>
            </thead>
            <tbody>
              ${prices.map(p => `
                <tr>
                  <td class="fin-td-date">${fmtDateDisplay(p.date)}</td>
                  <td class="fin-td-price">₹${Number(p.pricePerKg).toFixed(0)}</td>
                  <td class="fin-td-size">${escapeHTML(p.sizeCategory || '—')}</td>
                  <td class="fin-td-loc">${escapeHTML(p.location || '—')}</td>
                  <td class="fin-td-action"><button class="fin-del-btn" data-action="deletePrice" data-id="${p.id}" aria-label="Delete">✕</button></td>
                </tr>`).join('')}
            </tbody>
          </table>
        </div>` : '<div class="fin-empty">No market prices recorded yet.<br>Log shrimp selling prices to track market trends and project revenue.</div>'}
    `;
  }

  /* ── Main render ── */
  function renderFinancePage() {
    renderFinanceOverview();
    renderExpensesTab();
    renderRevenueTab();
    renderPricesTab();
  }

  function switchFinanceTab(tab) {
    financeTab = tab;
    document.querySelectorAll('.fin-tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));
    document.querySelectorAll('.fin-tab-panel').forEach(p => p.classList.toggle('hidden', p.id !== 'finance' + tab.charAt(0).toUpperCase() + tab.slice(1) + 'Tab'));
  }

  /* ── Modal: Add Expense ── */
  function openAddExpenseModal() {
    const today = fmt(new Date());
    $('expenseDate').value = today;
    $('expenseCategory').value = 'labor';
    $('expenseAmount').value = '';
    $('expenseDescription').value = '';

    // Populate batch select
    const sel = $('expenseBatch');
    sel.innerHTML = '<option value="">— General (no specific batch) —</option>';
    batches.forEach(b => {
      const pond = ponds.find(p => p.id === b.pondId);
      const name = pond ? pond.name : 'Unknown';
      sel.innerHTML += `<option value="${b.id}">${escapeHTML(name)} · Batch #${b.batchNumber} (${b.status})</option>`;
    });

    openModal('addExpenseModal');
  }

  function doSaveExpense() {
    const date = $('expenseDate').value;
    const category = $('expenseCategory').value;
    const amount = Number($('expenseAmount').value);
    const description = $('expenseDescription').value.trim();
    const batchId = $('expenseBatch').value;

    if (!date) { showToast('⚠️', 'Date Required', 'Please select a date.'); return; }
    if (!amount || amount <= 0 || isNaN(amount)) { showToast('⚠️', 'Invalid Amount', 'Enter a valid amount greater than 0.'); return; }

    let siteId = null, pondId = null;
    if (batchId) {
      const batch = batches.find(b => b.id === batchId);
      if (batch) {
        pondId = batch.pondId;
        const pond = ponds.find(p => p.id === pondId);
        siteId = pond ? pond.siteId : null;
      }
    }

    const expense = {
      id: genId('exp'),
      date, category, amount, description, batchId, pondId, siteId,
      createdAt: new Date().toISOString()
    };
    window.AppStorage.addFinanceExpense(expense);
    closeModal('addExpenseModal');
    renderFinancePage();
    showToast('✅', 'Expense Added', `${fmtCurrencyFull(amount)} for ${EXPENSE_LABELS[category] || category}`);
  }

  /* ── Modal: Add Revenue ── */
  function openAddRevenueModal() {
    const today = fmt(new Date());
    $('revenueDate').value = today;
    $('revenueWeightKg').value = '';
    $('revenuePricePerKg').value = '';
    $('revenueBuyer').value = '';

    const latestPrice = getLatestMarketPrice();
    if (latestPrice) $('revenuePricePerKg').value = latestPrice.pricePerKg;

    const sel = $('revenueBatch');
    sel.innerHTML = '<option value="">— Select Batch —</option>';
    batches.forEach(b => {
      const pond = ponds.find(p => p.id === b.pondId);
      const name = pond ? pond.name : 'Unknown';
      sel.innerHTML += `<option value="${b.id}">${escapeHTML(name)} · Batch #${b.batchNumber} (${b.status})</option>`;
    });

    openModal('addRevenueModal');
  }

  function doSaveRevenue() {
    const date = $('revenueDate').value;
    const batchId = $('revenueBatch').value;
    const weightKg = Number($('revenueWeightKg').value);
    const pricePerKg = Number($('revenuePricePerKg').value);
    const buyer = $('revenueBuyer').value.trim();

    if (!date) { showToast('⚠️', 'Date Required', 'Please select a date.'); return; }
    if (!batchId) { showToast('⚠️', 'Batch Required', 'Please select a batch.'); return; }
    if (!weightKg || weightKg <= 0 || isNaN(weightKg)) { showToast('⚠️', 'Invalid Weight', 'Enter a valid weight in kg.'); return; }
    if (!pricePerKg || pricePerKg <= 0 || isNaN(pricePerKg)) { showToast('⚠️', 'Invalid Price', 'Enter a valid price per kg.'); return; }

    const batch = batches.find(b => b.id === batchId);
    const pond = batch ? ponds.find(p => p.id === batch.pondId) : null;
    const siteId = pond ? pond.siteId : null;

    const rev = {
      id: genId('rev'),
      date, batchId, weightKg, pricePerKg, buyer, siteId,
      totalAmount: +(weightKg * pricePerKg).toFixed(2),
      createdAt: new Date().toISOString()
    };
    window.AppStorage.addFinanceRevenue(rev);
    closeModal('addRevenueModal');
    renderFinancePage();
    showToast('✅', 'Sale Recorded', `${fmtCurrencyFull(rev.totalAmount)} for ${weightKg} kg`);
  }

  /* ── Modal: Add Market Price ── */
  function openAddPriceModal() {
    const today = fmt(new Date());
    $('priceDate').value = today;
    $('pricePerKg').value = '';
    $('priceSizeCategory').value = '';
    $('priceLocation').value = '';
    openModal('addPriceModal');
  }

  function doSavePrice() {
    const date = $('priceDate').value;
    const pricePerKg = Number($('pricePerKg').value);
    const sizeCategory = $('priceSizeCategory').value.trim();
    const location = $('priceLocation').value.trim();

    if (!date) { showToast('⚠️', 'Date Required', 'Please select a date.'); return; }
    if (!pricePerKg || pricePerKg <= 0 || isNaN(pricePerKg)) { showToast('⚠️', 'Invalid Price', 'Enter a valid price per kg.'); return; }

    const price = {
      id: genId('price'),
      date, pricePerKg, sizeCategory, location,
      createdAt: new Date().toISOString()
    };
    window.AppStorage.addMarketPrice(price);
    closeModal('addPriceModal');
    renderFinancePage();
    showToast('✅', 'Price Added', `₹${pricePerKg.toFixed(0)}/kg market price recorded`);
  }

  /* ── Delete handlers ── */
  function deleteExpense(id) {
    showConfirm('Delete Expense', 'Remove this expense entry? This cannot be undone.', () => {
      window.AppStorage.deleteFinanceExpense(id);
      renderFinancePage();
      showToast('🗑️', 'Deleted', 'Expense removed');
    }, { danger: true });
  }

  function deleteRevenue(id) {
    showConfirm('Delete Sale', 'Remove this sale record? This cannot be undone.', () => {
      window.AppStorage.deleteFinanceRevenue(id);
      renderFinancePage();
      showToast('🗑️', 'Deleted', 'Sale removed');
    }, { danger: true });
  }

  function deletePrice(id) {
    showConfirm('Delete Price', 'Remove this market price entry?', () => {
      window.AppStorage.deleteMarketPrice(id);
      renderFinancePage();
      showToast('🗑️', 'Deleted', 'Price removed');
    }, { danger: true });
  }

  /* ── Delegated click handler ── */
  function bindFinanceEvents() {
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn) return;
      const action = btn.dataset.action;
      if (action === 'openAddExpenseModal') openAddExpenseModal();
      else if (action === 'openAddRevenueModal') openAddRevenueModal();
      else if (action === 'openAddPriceModal') openAddPriceModal();
      else if (action === 'deleteExpense') deleteExpense(btn.dataset.id);
      else if (action === 'deleteRevenue') deleteRevenue(btn.dataset.id);
      else if (action === 'deletePrice') deletePrice(btn.dataset.id);
      else if (action === 'switchFinanceTab') switchFinanceTab(btn.dataset.tab);
      else if (action === 'doSaveExpense') doSaveExpense();
      else if (action === 'doSaveRevenue') doSaveRevenue();
      else if (action === 'doSavePrice') doSavePrice();
    });
  }

  // Expose globally
  window.renderFinancePage = renderFinancePage;
  window.switchFinanceTab = switchFinanceTab;
  window.bindFinanceEvents = bindFinanceEvents;
  window.getBatchCosts = getBatchCosts;
  window.getBatchRevenue = getBatchRevenue;
  window.getBatchProfit = getBatchProfit;
  window.getLatestMarketPrice = getLatestMarketPrice;
  window.getProjectedRevenue = getProjectedRevenue;
  window.fmtCurrency = fmtCurrency;
  window.fmtCurrencyFull = fmtCurrencyFull;
})();

// --- Bootstrapper ---
(function() {
  'use strict';
// ── Service & Manager Imports ─────────────────────────────────

// ── Module Imports ────────────────────────────────────────────

const {
  escapeHTML,
  startOfDay,
  fmt,
  todayStr,
  isIsoDateStr,
  isFutureDateStr,
  isBeforeDateStr,
  numberFromField,
  isPositiveNumberField,
  isNonNegativeNumberField,
  fmtDateDisplay,
  fmtShrimpCount,
  fmtWeightG,
  fmtGrams,
  capitalize,
  formatInputDate,
  formatTime12,
  calcDOC,
  getDateForDOC,
  isInLastNDays,
  getWeekRange,
  getMonthOffset
} = AppUtils;

const $ = id => document.getElementById(id);
window.$ = $;

// ── Application Bootstrapper ──────────────────────────────────
function initApp() {
  setTimeout(() => {
    const splash = $('splash');
    if (splash) {
      splash.classList.add('fade-out');
      setTimeout(() => {
        splash.style.display = 'none';
        const app = $('app');
        if (app) app.classList.remove('hidden');
        bootApp();
      }, 600);
    } else {
      bootApp();
    }
  }, 1200);
}

function bootApp() {
  state.setPonds(AppStorage.getPonds());

  // AquaLog Intelligence: migrate legacy free-text pond.site strings into
  // real Site records (siteManager.js). Safe/idempotent — no data is deleted.
  if (window.SiteManager) {
    const migResult = window.SiteManager.migrate(state.ponds);
    if (migResult.pondsChanged) savePonds();
  }

  // C9/C10 fix: Run inventory migration + backfill AFTER SiteManager.migrate
  // so legacy ponds have siteIds assigned before inventory transactions are created.
  // Previously these ran at IIFE-load time (before SiteManager.migrate), causing
  // them to no-op because resolveSiteIdForPond returned null for un-migrated ponds.
  if (window.InventoryManager) {
    try { window.InventoryManager.migrateLegacyInventoryData(); } catch (e) {
      console.error('[AquaLog] Inventory legacy migration failed:', e);
    }
    const _scheduleInventoryBackfill = () => {
      // Cap boot-time backfill to last 90 days to prevent localStorage quota overflow
      // when the user has large historical datasets (e.g. demo data with 10K+ records).
      // Older feed logs remain in the records array for reporting; only inventory
      // consumption transactions are limited to recent history.
      try { window.InventoryManager.backfillHistoricalFeedConsumption(90); } catch (e) {
        console.error('[AquaLog] Inventory backfill failed:', e);
      }
    };
    if (typeof requestIdleCallback === 'function') {
      requestIdleCallback(_scheduleInventoryBackfill, { timeout: 3000 });
    } else {
      setTimeout(_scheduleInventoryBackfill, 0);
    }
  }

  setDefaultDate();
  renderLogPondSelect();
  renderFeedGrid();
  loadSheetsUrl();
  loadApiSettings();
  updateStatusBar();
  setInterval(updateStatusBar, 30000);
  checkOnline();
  document.querySelectorAll('.cc-body').forEach(el => el.classList.remove('hidden'));
  bindEvents();

  // M5 fix: initDragToClose was defined but never called — drag-to-close on modal sheets never activated
  try { initDragToClose(); } catch(e) { console.warn('[AquaLog] initDragToClose failed:', e); }

  // Show skeleton state on qs-cards
  ['qsWeek','qsMonth','qsPonds','qsActiveBatches'].forEach(id => {
    const el = $(id);
    if (el) { el.textContent = '—'; el.style.opacity = '0.4'; }
  });

  renderDashboard();
  initAlSelects(); // Init custom dropdowns after first render so options are populated
  initDateTimeCapsules();

  // AquaLog Intelligence
  renderSitesSettings();
  renderManageSites();
  renderWeatherIntelligence(null);

  // Self-tests: only run when ?debug=1 is in the URL (never in production)
  if (new URLSearchParams(location.search).get('debug') === '1') {
    runBiomassSelfTests();
    runWeightManagementSelfTests();
  }

  // Dynamic focus management for modals
  // H7 fix: only focus when transitioning FROM hidden TO visible.
  // Previously fired on any class change (including 'modal-closing' added before 'hidden'),
  // trapping focus on an element inside a modal that was about to be hidden.
  const modalObserver = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.attributeName === 'class') {
        const el = mutation.target;
        const wasHidden = mutation.oldValue && mutation.oldValue.includes('hidden');
        const isHidden = el.classList.contains('hidden');
        const isClosing = el.classList.contains('modal-closing');
        // Only focus when transitioning from hidden → visible, and not currently closing
        if (wasHidden && !isHidden && !isClosing) {
          const firstFocusable = el.querySelector('input:not([type="hidden"]), select, textarea, button');
          if (firstFocusable) {
            setTimeout(() => firstFocusable.focus(), 50);
          }
        }
      }
    });
  });
  document.querySelectorAll('.modal-overlay').forEach((modal) => {
    // H7 fix: pass attributeOldValue: true so the observer can detect the hidden→visible transition
    modalObserver.observe(modal, { attributes: true, attributeFilter: ['class'], attributeOldValue: true });
  });
}

window.initApp = initApp;
window.bootApp = bootApp;

function bindEvents() {
  bindFormEvents();
  bindReportEvents();
  bindManageEvents(); try { bindSettingsEvents(); } catch(e) { console.error('[AquaLog] bindSettingsEvents error:', e); }
  try { bindFinanceEvents(); } catch(e) { console.error('[AquaLog] bindFinanceEvents error:', e); }

  // ── Global data-action delegated handler for modal close buttons ─────────
  // Handles: data-action="closeAnalyticsPointModal" and data-action="closeBarDetailModal"
  // Both buttons live inside their modal sheet and cannot bubble to the overlay,
  // so they must be caught here rather than via overlay-click.
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-action]');
    if (!btn) return;
    const action = btn.dataset.action;
    if (action === 'closeAnalyticsPointModal') closeModal('analyticsPointModal');
    else if (action === 'closeBarDetailModal')  closeModal('barDetailModal');
    else if (action === 'editSite')             openEditSiteModal(btn.dataset.siteId);
    else if (action === 'deleteSite')           confirmDeleteSite(btn.dataset.siteId);
    else if (action === 'switchPage')           switchPage(btn.dataset.pageId);
  });

  // ── Inventory module — delegated click handler (resilient to DOM re-render) ──
  // Next.js HMR / Fast Refresh can replace the body HTML after `bindInventoryEvents`
  // runs, detaching all per-element listeners. This single delegated handler on
  // document catches clicks via element ID matching, so it survives DOM replacement.
  if (!window.__aqInventoryDelegated) {
    window.__aqInventoryDelegated = true;
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('button, [role="button"]');
      if (!btn) return;
      const id = btn.id;
      if (!id) return;
      switch (id) {
        case 'btnQuickAddFeed':       openPurchaseFeedModal(); break;
        case 'btnQuickAddMedicine':   openPurchaseMedicineModal(); break;
        case 'btnQuickAddFuel':       openPurchaseFuelModal(); break;
        case 'btnViewDetailsFeed':    switchPage('pageFeedDetail'); break;
        case 'btnViewDetailsMedicine':switchPage('pageMedicineDetail'); break;
        case 'btnViewDetailsFuel':    switchPage('pageFuelDetail'); break;
        case 'btnBackFeedDetail':     switchPage('pageInventory'); break;
        case 'btnBackMedicineDetail': switchPage('pageInventory'); break;
        case 'btnBackFuelDetail':     switchPage('pageInventory'); break;
        case 'purchaseFeedCancel':    closeModal('purchaseFeedModal'); break;
        case 'purchaseMedicineCancel':closeModal('purchaseMedicineModal'); break;
        case 'purchaseFuelCancel':    closeModal('purchaseFuelModal'); break;
        case 'inventoryDetailClose':  closeModal('inventoryDetailModal'); break;
        case 'editThresholdCancel':   closeModal('editThresholdModal'); break;
        case 'editThresholdSave':     doSaveThreshold(); break;
        case 'purchaseFeedSave':      doSaveFeedPurchase(); break;
        case 'purchaseMedicineSave':  doSaveMedicinePurchase(); break;
        case 'purchaseFuelSave':      doSaveFuelPurchase(); break;
        case 'btnClearFeedFilters':
          if ($('feedFilterDateFrom')) $('feedFilterDateFrom').value = '';
          if ($('feedFilterDateTo')) $('feedFilterDateTo').value = '';
          if ($('feedFilterLowOnly')) $('feedFilterLowOnly').checked = false;
          if ($('feedFilterOutOnly')) $('feedFilterOutOnly').checked = false;
          if ($('feedSearchInput')) $('feedSearchInput').value = '';
          renderFeedDetailPage();
          break;
        case 'btnClearMedFilters':
          if ($('medFilterDateFrom')) $('medFilterDateFrom').value = '';
          if ($('medFilterDateTo')) $('medFilterDateTo').value = '';
          if ($('medFilterLowOnly')) $('medFilterLowOnly').checked = false;
          if ($('medFilterOutOnly')) $('medFilterOutOnly').checked = false;
          if ($('medFilterExpiringOnly')) $('medFilterExpiringOnly').checked = false;
          if ($('medSearchInput')) $('medSearchInput').value = '';
          renderMedicineDetailPage();
          break;
        case 'btnClearFuelFilters':
          if ($('fuelFilterDateFrom')) $('fuelFilterDateFrom').value = '';
          if ($('fuelFilterDateTo')) $('fuelFilterDateTo').value = '';
          if ($('fuelFilterLowOnly')) $('fuelFilterLowOnly').checked = false;
          if ($('fuelFilterOutOnly')) $('fuelFilterOutOnly').checked = false;
          if ($('fuelSearchInput')) $('fuelSearchInput').value = '';
          renderFuelDetailPage();
          break;
      }
    });
  }

  // ── Bottom Navigation — event delegation on .bottom-nav ─────────────────
  // Replaces per-button onclick="" attributes removed from HTML.
  // Any nav button with data-page will trigger switchPage().
  const bottomNav = document.querySelector('.bottom-nav');
  if (bottomNav) {
    bottomNav.querySelectorAll('.nav-item, .nav-fab button').forEach(btn => {
      btn.addEventListener('click', (e) => {
        addNavRipple(btn, e);
        switchPage(btn.dataset.page);
      });
    });
  }

  document.addEventListener('pointerdown', (e) => {
    const target = e.target.closest('button, .icon-btn, .nav-item, .pond-action-btn, .abs-qa-btn, .tab-btn, .pill-btn, .nav-fab');
    if (!target) return;
    target.classList.add('pressed');
  });
  const removePress = () => document.querySelectorAll('.pressed').forEach(el => el.classList.remove('pressed'));
  document.addEventListener('pointerup', removePress);
  document.addEventListener('pointercancel', removePress);

  // ── See All Sessions → Reports ───────────────────────────────────────────
  const seeAllBtn = $('seeAllSessionsBtn');
  if (seeAllBtn) {
    seeAllBtn.addEventListener('click', () => switchPage('pageReports'));
  }

  // ── Active Batch Card Tap-to-Expand ──────────────────────────────────────
  const batchCard = $('batchSummaryCard');
  if (batchCard) {
    batchCard.addEventListener('click', (e) => {
      // Don't expand if click is on quick action buttons
      if (e.target.closest('.bsc-quick-actions') || e.target.closest('.abs-qa-btn') || e.target.closest('.bsc-add-weight-link')) {
        return;
      }
      
      const select = $('dashboardContextSelect');
      if (!select) return;
      const context = select.value;
      if (context && context.startsWith('batch_')) {
        const batchId = context.replace('batch_', '');
        const contentEl = $('batchDetailsContent');
        const indicator = $('batchDetailsIndicator');
        if (!contentEl) return;
        const isCollapsed = contentEl.classList.contains('collapsed');
        if (isCollapsed) {
          contentEl.classList.remove('collapsed');
          if (indicator) indicator.textContent = '⌃';
          sessionStorage.setItem(`aqualog_batch_expanded_${batchId}`, 'true');
          batchCard.setAttribute('aria-expanded', 'true');
        } else {
          contentEl.classList.add('collapsed');
          if (indicator) indicator.textContent = '⌄';
          sessionStorage.setItem(`aqualog_batch_expanded_${batchId}`, 'false');
          batchCard.setAttribute('aria-expanded', 'false');
        }
      }
    });
    batchCard.addEventListener('keydown', (e) => {
      if (e.target.closest('.bsc-quick-actions') || e.target.closest('.abs-qa-btn') || e.target.closest('.bsc-add-weight-link')) {
        return;
      }
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        batchCard.click();
      }
    });
  }

  // ── Dashboard context selector ──────────────────────────────────────────
  // Single, authoritative change handler. Routes directly to the appropriate
  // render function WITHOUT calling renderDashboard(), which would re-invoke
  // populateContextSelector() and potentially disturb the selection.
  const ctxSelect = $('dashboardContextSelect');
  if (ctxSelect) {
    ctxSelect.addEventListener('change', () => {
      const ctx = ctxSelect.value;
      if (ctx === 'farm') {
        updateBatchShortcut(null);
        showFarmView();
      } else if (ctx.startsWith('batch_')) {
        const batchId = ctx.replace('batch_', '');
        const batch   = batches.find(b => b.id === batchId);
        if (!batch) {
          // Batch no longer exists — fall back to Farm Overview.
          ctxSelect.value = 'farm';
          updateBatchShortcut(null);
          showFarmView();
          return;
        }
        updateBatchShortcut(batch);
        showBatchView(batch);
      }
    });
  }

  // ── Batch shortcut button (floating button above bottom nav) ──
  const batchShortcutBtn = $('batchShortcutBtn');
  if (batchShortcutBtn) {
    batchShortcutBtn.addEventListener('click', () => {
      // Switch to dashboard and select the batch
      switchPage('pageDashboard');
      const select = $('dashboardContextSelect');
      if (select && select.value && select.value.startsWith('batch_')) {
        // Already on a batch — just re-render
        const batchId = select.value.replace('batch_', '');
        const batch = batches.find(b => b.id === batchId);
        if (batch) showBatchView(batch);
      }
    });
  }

  window.addEventListener('online',  checkOnline);
  window.addEventListener('offline', checkOnline);

  // Active batch summary cards button click delegation
  const activeBatchWrap = $('activeBatchSummaryCards');
  if (activeBatchWrap) {
    activeBatchWrap.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn) return;
      const action = btn.dataset.action;
      const batchId = btn.dataset.batchId;
      const pondId = btn.dataset.pondId;

      if (action === 'openQuickAddFeed') {
        openQuickAddFeed(pondId);
      } else if (action === 'openLogWeightModal') {
        openLogWeightModal(batchId);
      } else if (action === 'openSamplingModal') {
        launchSampling(batchId);
      } else if (action === 'openHapaEntryModal') {
        openHapaEntryModal(batchId);
      }
    });
  }

  // Toggle Growth Analytics Panel
  $('toggleAnalyticsBtn')?.addEventListener('click', toggleAnalyticsPanel);

  // Warning Banner go-manage-link delegation
  $('noBatchWarning')?.addEventListener('click', (e) => {
    if (e.target.closest('.go-manage-link')) {
      switchPage('pageManage');
    }
  });

  // Weight Management (Growth Tracking) Card Click Delegation
  const growthTrackingCard = $('growthTrackingCard');
  if (growthTrackingCard) {
    growthTrackingCard.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn) return;
      const action = btn.dataset.action;
      const batchId = btn.dataset.batchId;

      if (action === 'openLogWeightModal') {
        openLogWeightModal(batchId);
      } else if (action === 'openSamplingModal') {
        launchSampling(batchId);
      } else if (action === 'deleteSamplingEntry') {
        deleteSamplingEntry(btn.dataset.samplingId);
      } else if (action === 'deleteGrowthEntry') {
        deleteGrowthEntry(btn.dataset.growthId);
      } else if (action === 'openEditGrowthEntry') {
        openEditGrowthEntry(btn.dataset.growthId);
      } else if (action === 'toggleWeightHistory') {
        toggleWeightHistory(batchId, btn);
      }
    });
  }

  // Sampling Card Click Delegation (fallback/safeguard if visible)
  const samplingCard = $('samplingCard');
  if (samplingCard) {
    samplingCard.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn) return;
      const action = btn.dataset.action;
      const batchId = btn.dataset.batchId;

      if (action === 'openSamplingModal') {
        launchSampling(batchId);
      } else if (action === 'deleteSamplingEntry') {
        deleteSamplingEntry(btn.dataset.samplingId);
      } else if (action === 'toggleSamplingHistory') {
        toggleSamplingHistory(batchId, btn);
      }
    });
  }
}
window.bindEvents = bindEvents;

function bindManageEvents() {
  // Confirm modal (custom replacement for browser confirm())
  $('confirmModalCancelBtn')?.addEventListener('click', _cancelConfirm);
  $('confirmModalConfirmBtn')?.addEventListener('click', _doConfirm);
  $('confirmModal')?.addEventListener('click', e => { if (e.target === $('confirmModal')) _cancelConfirm(); });

  // Completed Batches toggle
  const completedToggle = $('completedBatchesToggle');
  if (completedToggle) {
    completedToggle.addEventListener('click', () => {
      const body = $('completedBatchesBody');
      if (!body) return;
      const isOpen = body.classList.toggle('open');
      completedToggle.setAttribute('aria-expanded', isOpen);
      body.classList.remove('hidden');
    });
    completedToggle.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        completedToggle.click();
      }
    });
  }

  // Developer Tools toggle
  const devToolsToggle = $('devToolsToggle');
  if (devToolsToggle) {
    devToolsToggle.addEventListener('click', () => {
      const body  = $('devToolsBody');
      const arrow = $('devToolsArrow');
      if (!body || !arrow) return;
      const open  = !body.classList.contains('hidden');
      body.classList.toggle('hidden', open);
      arrow.classList.toggle('open', !open);
      devToolsToggle.setAttribute('aria-expanded', !open ? 'true' : 'false');
    });
    devToolsToggle.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        devToolsToggle.click();
      }
    });
  }
  $('loadDemoDataBtn')?.addEventListener('click', loadDemoData);

  // Create Pond
  $('openCreatePondBtn')?.addEventListener('click', openCreatePondModal);
  $('createPondCancel')?.addEventListener('click', () => closeModal('createPondModal'));
  $('createPondConfirm')?.addEventListener('click', doCreatePond);
  $('createPondModal')?.addEventListener('click', e => { if (e.target === $('createPondModal')) closeModal('createPondModal'); });

  // ── Manage page: primary action cards ─────────────────────────────
  // Issue #3: always-visible Manage Sites entry point
  $('manageSitesCardBtn')?.addEventListener('click', () => {
    toggleManageSitesSection(true);
  });
  // Ponds card scrolls to the pond pager
  $('managePondsCardBtn')?.addEventListener('click', () => {
    const pager = $('managePondPager');
    if (pager && !pager.classList.contains('hidden')) {
      pager.scrollIntoView({ behavior: 'smooth', block: 'start' });
    } else {
      // No active ponds → trigger create
      openCreatePondModal();
    }
  });
  // Batches card scrolls to the first active batch's View Batch modal trigger
  $('manageBatchesCardBtn')?.addEventListener('click', () => {
    const activePonds = ponds.filter(p => p.active);
    if (!activePonds.length) {
      showToast('ℹ️', 'No Ponds', 'Create a pond first to manage batches.');
      return;
    }
    const pager = $('managePondPager');
    if (pager) pager.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  // ── Manage page: Tools & Analytics collapsible ──
  const toolsToggle = $('manageToolsToggle');
  if (toolsToggle) {
    toolsToggle.addEventListener('click', () => {
      const body = $('manageToolsBody');
      const arrow = $('manageToolsArrow');
      if (!body) return;
      const isOpen = body.classList.toggle('open');
      toolsToggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
      body.classList.remove('hidden');
      if (arrow) arrow.style.transform = isOpen ? 'rotate(180deg)' : '';
    });
    toolsToggle.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        toolsToggle.click();
      }
    });
  }

  // Edit Pond
  $('editPondCancel')?.addEventListener('click', () => closeModal('editPondModal'));
  $('editPondConfirm')?.addEventListener('click', doEditPond);
  $('editPondModal')?.addEventListener('click', e => {
    if (e.target === $('editPondModal')) closeModal('editPondModal');
  });

  // Create Batch modal
  $('createBatchCancel')?.addEventListener('click', () => closeModal('createBatchModal'));
  $('createBatchConfirm')?.addEventListener('click', doCreateBatch);
  $('createBatchModal')?.addEventListener('click', e => { if (e.target === $('createBatchModal')) closeModal('createBatchModal'); });

  // View Batch modal
  $('viewBatchClose')?.addEventListener('click', () => closeModal('viewBatchModal'));
  $('viewBatchEdit')?.addEventListener('click', () => { if (viewBatchId) { closeModal('viewBatchModal'); openEditBatchModal(viewBatchId); } });
  $('viewBatchComplete')?.addEventListener('click', () => { if (viewBatchId) openCompleteBatchModal(viewBatchId); });
  $('viewBatchModal')?.addEventListener('click', e => { if (e.target === $('viewBatchModal')) closeModal('viewBatchModal'); });

  // Complete Batch modal
  $('completeBatchCancel')?.addEventListener('click', () => closeModal('completeBatchModal'));
  $('completeBatchConfirm')?.addEventListener('click', doCompleteBatch);
  $('completeBatchModal')?.addEventListener('click', e => {
    if (e.target === $('completeBatchModal')) closeModal('completeBatchModal');
  });

  // Delete feed entry modal
  $('deleteCancel')?.addEventListener('click', () => closeModal('deleteModal'));
  $('deleteConfirm')?.addEventListener('click', doDelete);
  $('deleteModal')?.addEventListener('click', e => { if (e.target === $('deleteModal')) closeModal('deleteModal'); });

  // Archive Pond modal
  $('archivePondCancel')?.addEventListener('click', () => closeModal('archivePondModal'));
  $('archivePondConfirm')?.addEventListener('click', doArchivePond);
  $('archivePondModal')?.addEventListener('click', e => { if (e.target === $('archivePondModal')) closeModal('archivePondModal'); });

  // Delete Pond modal
  $('deletePondCancel')?.addEventListener('click', () => closeModal('deletePondModal'));
  $('deletePondConfirm')?.addEventListener('click', doDeletePond);
  $('deletePondModal')?.addEventListener('click', e => { if (e.target === $('deletePondModal')) closeModal('deletePondModal'); });

  // Edit Feed modal
  $('editFeedCancel')?.addEventListener('click', () => closeModal('editFeedModal'));
  $('editFeedConfirm')?.addEventListener('click', doSaveEditFeed);
  $('editFeedModal')?.addEventListener('click', e => {
    if (e.target === $('editFeedModal')) closeModal('editFeedModal');
  });
  $('editFeedTime')?.addEventListener('change', function() {
    $('editCustomTimeGroup').style.display = this.value === 'Other' ? '' : 'none';
    $('errEditFeedTime')?.classList.remove('show');
  });

  // Edit Batch modal
  $('editBatchCancel')?.addEventListener('click', () => closeModal('editBatchModal'));
  $('editBatchConfirm')?.addEventListener('click', doSaveEditBatch);
  $('editBatchModal')?.addEventListener('click', e => {
    if (e.target === $('editBatchModal')) closeModal('editBatchModal');
  });

  // Batch Date Warning modal
  // Cancel = discard pending changes and reopen editBatchModal
  function _closeBatchDateWarn() {
    closeModal('batchDateWarnModal'); // resets editBatchPendingData via registry
    if (editBatchId) openEditBatchModal(editBatchId);
  }
  $('batchDateWarnCancel')?.addEventListener('click', _closeBatchDateWarn);
  $('batchDateWarnConfirm')?.addEventListener('click', () => {
    if (!editBatchId || !editBatchPendingData) return;
    const batch = batches.find(b => b.id === editBatchId);
    if (!batch) return;
    const { newCount, newDate, newTime, newNotes } = editBatchPendingData;
    applyBatchEdit(batch, newCount, newDate, newTime, newNotes);
  });
  $('batchDateWarnModal')?.addEventListener('click', e => {
    if (e.target === $('batchDateWarnModal')) _closeBatchDateWarn();
  });

  // Log Weight modal (Growth Tracking)
  $('logWeightCancel')?.addEventListener('click', () => closeModal('logWeightModal'));
  $('logWeightConfirm')?.addEventListener('click', doLogWeight);
  $('logWeightModal')?.addEventListener('click', e => { if (e.target === $('logWeightModal')) closeModal('logWeightModal'); });
  $('openLogWeightBtn')?.addEventListener('click', openLogWeightModal);
  $('growthDate')?.addEventListener('change', updateGrowthDocBadge);
  $('growthBatchSelect')?.addEventListener('change', updateGrowthDocBadge);

  // Sampling Entry modal
  $('samplingEntryCancel')?.addEventListener('click', () => closeModal('samplingEntryModal'));
  $('samplingEntryConfirm')?.addEventListener('click', doSaveSampling);
  $('samplingEntryModal')?.addEventListener('click', e => { if (e.target === $('samplingEntryModal')) closeModal('samplingEntryModal'); });
  $('samplingDate')?.addEventListener('change', updateSamplingDocDisplay);
  $('samplingTotalWeight')?.addEventListener('input', () => {
    clearFieldError('errSamplingTotalWeight', 'samplingTotalWeight', 'Required');
    updateSamplingLiveAbw();
  });
  $('samplingShrimpCount')?.addEventListener('input', () => {
    clearFieldError('errSamplingShrimpCount', 'samplingShrimpCount', 'Required');
    updateSamplingLiveAbw();
  });

  // Hapa Entry modal
  $('hapaEntryCancel')?.addEventListener('click', () => closeModal('hapaEntryModal'));
  $('hapaEntryConfirm')?.addEventListener('click', doSaveHapa);
  $('hapaEntryModal')?.addEventListener('click', e => { if (e.target === $('hapaEntryModal')) closeModal('hapaEntryModal'); });
  $('hapaAliveInput')?.addEventListener('input', () => {
    if (!hapaEntryBatchId) return;
    const batch = batches.find(b => b.id === hapaEntryBatchId);
    if (!batch) return;
    const stocked = Number(batch.hapaStocked || 100);
    const alive = numberFromField($('hapaAliveInput').value);
    if (alive !== null && alive >= 0 && alive <= stocked && stocked > 0) {
      const pct = (alive / stocked * 100).toFixed(1);
      $('hapaSurvivalValue').textContent = pct + '%';
      // Estimated survived from actual stocked shrimp count
      const shrimpCount = Number(batch.shrimpCount || 0);
      if (shrimpCount > 0) {
        const survived = Math.round(shrimpCount * (alive / stocked));
        $('hapaSurvivedCount').textContent = fmtShrimpCount(survived);
      } else {
        $('hapaSurvivedCount').textContent = '—';
      }
      $('hapaSurvivalPreview').classList.remove('hidden');
    } else {
      $('hapaSurvivalPreview').classList.add('hidden');
    }
  });
}
window.bindManageEvents = bindManageEvents;

async function postToSheets(rec, url) {
  try {
    const res = await fetch(url, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(rec) });
    return res.ok;
  } catch { return false; }
}
window.postToSheets = postToSheets;

async function syncQueue() {
  const api = AppStorage.getApiSettings();
  const sheetsUrl = AppStorage.getSheetsUrl();
  const apiUrl = api.url;

  if (!sheetsUrl && !apiUrl) {
    showToast('⚠️', 'No Sync Target', 'Configure Google Sheets or Custom REST API first.');
    return;
  }
  if (!navigator.onLine) {
    showToast('📶', 'Offline', 'Connect to internet first.');
    return;
  }

  $('syncBtn').textContent = 'Syncing…';
  const failed = [];

  for (const rec of offlineQ) {
    // 1. Google Sheets sync
    if (sheetsUrl && !rec._syncedSheets) {
      const ok = await postToSheets(rec, sheetsUrl);
      if (ok) rec._syncedSheets = true;
    }

    // 2. Custom REST API sync
    if (apiUrl && !rec._syncedApi) {
      const ok = await postToCustomApi(rec);
      if (ok) rec._syncedApi = true;
    }

    const sheetsSatisfied = !sheetsUrl || rec._syncedSheets;
    const apiSatisfied = !apiUrl || rec._syncedApi;

    if (!sheetsSatisfied || !apiSatisfied) {
      failed.push(rec);
    }
  }

  offlineQ = failed;
  AppStorage.saveQueue(offlineQ);
  updateQueueUI();
  showToast(failed.length ? '⚠️' : '✅', failed.length ? 'Partial Sync' : 'All Synced!', `${offlineQ.length} remaining`);
  $('syncBtn').textContent = 'Sync Now ↑';
}
window.syncQueue = syncQueue;

function saveSheetsUrl() {
  const url = $('sheetsUrl').value.trim();
  if (!url || !url.startsWith('http')) { showToast('⚠️','Invalid URL','Please check the URL.'); return; }
  AppStorage.saveSheetsUrl(url);
  showToast('✅','URL Saved','Google Sheets connected.');
}
window.saveSheetsUrl = saveSheetsUrl;

function loadSheetsUrl() {
  const url = AppStorage.getSheetsUrl();
  if (url) $('sheetsUrl').value = url;
}
window.loadSheetsUrl = loadSheetsUrl;

async function postToCustomApi(rec) {
  const s = AppStorage.getApiSettings();
  const url = s.url;
  if (!url) return false;

  const method     = s.method || 'POST';
  const auth       = s.auth   || '';
  const headersRaw = s.headers || '';

  const headers = {
    'Content-Type': 'application/json'
  };

  if (auth) {
    headers['Authorization'] = auth;
  }

  if (headersRaw) {
    try {
      const parsed = JSON.parse(headersRaw);
      Object.assign(headers, parsed);
    } catch (e) {
      console.error('[AquaLog] Failed to parse custom headers:', e);
    }
  }

  try {
    const res = await fetch(url, {
      method: method,
      headers: headers,
      body: JSON.stringify(rec)
    });
    return res.ok;
  } catch (err) {
    console.error('[AquaLog] API post failed:', err);
    return false;
  }
}
window.postToCustomApi = postToCustomApi;

function exportCSV() {
  if (!records.length) { showToast('⚠️','No Data','Log some entries first.'); return; }
  const headers = ['Date','Time','PondId','PondName','Pond','BatchId','BatchNumber','Feed Size 1 Gram','Feed Size 2 Gram','Feed Size 3 Gram','Feed Size 4 Gram','Feed Size 5 Gram','Other Feed Name','Other Feed Gram','Notes','Created Timestamp'];
  const rows    = records.map(r => headers.map(h => `"${(r[h]||'').toString().replace(/"/g,'""')}"`).join(','));
  const csv     = [headers.join(','), ...rows].join('\n');
  const a       = document.createElement('a');
  const _blobUrl = URL.createObjectURL(new Blob([csv], {type:'text/csv;charset=utf-8;'})); // M12 fix: track for cleanup
  a.href        = _blobUrl;
  a.download    = `aqualog_${fmt(new Date())}.csv`;
  a.click();
  URL.revokeObjectURL(_blobUrl); // M12 fix: revoke blob URL to prevent leak
}
window.exportCSV = exportCSV;

function updateExportCount() {
  const el = $('exportCountLbl');
  if (el) el.textContent = `${records.length} record${records.length!==1?'s':''}`;
}
window.updateExportCount = updateExportCount;

function checkOnline() {
  const on = navigator.onLine;
  $('statusDot').classList.toggle('offline', !on);
  $('statusLabel').textContent = on ? 'Online' : 'Offline';
  updateQueueUI();
}
window.checkOnline = checkOnline;

function updateQueueUI() {
  const strip = $('queueStrip');
  if (offlineQ.length) {
    strip.classList.remove('hidden');
    $('queueCount').textContent = offlineQ.length;
  } else {
    strip.classList.add('hidden');
  }
}
window.updateQueueUI = updateQueueUI;

function runBiomassSelfTests() {
  console.log('🧪 Starting Biomass Estimation Module self-tests...');
  let passed = 0;
  let failed = 0;

  const assert = (cond, msg) => {
    if (cond) {
      console.log(`✅ Passed: ${msg}`) // L2 fix: removed dead ternary (cond is always truthy here);
      passed++;
    } else {
      console.error(`❌ Failed: ${msg}`);
      failed++;
    }
  };

  // Mock batch
  const mockBatch = {
    id: 'test_batch_123',
    shrimpCount: 100000,
    stockingDate: '2026-04-01',
    batchNumber: 99,
    status: 'active'
  };

  // Save current state to restore later
  const oldHapa = hapaEntries;
  const oldSampling = samplingEntries;
  const oldGrowth = growthEntries;
  const oldBiomass = biomassEntries;

  try {
    // Test 1: Hapa missing
    hapaEntries = [];
    samplingEntries = [];
    growthEntries = [];
    biomassEntries = [];

    let res = updateBatchBiomassEstimation(mockBatch);
    assert(!res.success && res.status === 'HAPA_MISSING', 'Should reject when Hapa details are missing');

    // Test 2: Invalid stocked quantity (<= 0)
    hapaEntries = [{ batchId: mockBatch.id, survivalPercent: 82.0 }];
    const invalidBatch = { ...mockBatch, shrimpCount: 0 };
    res = updateBatchBiomassEstimation(invalidBatch);
    assert(!res.success && res.status === 'INVALID_INPUTS', 'Should reject when stocking quantity is 0');

    // Test 3: Invalid Hapa survival (<= 0)
    hapaEntries = [{ batchId: mockBatch.id, survivalPercent: 0 }];
    res = updateBatchBiomassEstimation(mockBatch);
    assert(!res.success && res.status === 'INVALID_INPUTS', 'Should reject when Hapa survival is 0');

    // Test 4: ABW missing (both sampling and growth missing)
    hapaEntries = [{ batchId: mockBatch.id, survivalPercent: 82.0 }];
    res = updateBatchBiomassEstimation(mockBatch);
    assert(!res.success && res.status === 'ABW_MISSING', 'Should reject when both Sampling ABW and Visual Estimation are missing');

    // Test 5: Fallback to Visual Estimation (Growth tracking)
    hapaEntries = [{ batchId: mockBatch.id, survivalPercent: 82.0 }];
    growthEntries = [{ batchId: mockBatch.id, doc: 10, weightGrams: 8.5, date: '2026-04-10' }];
    res = updateBatchBiomassEstimation(mockBatch);
    assert(res.success && res.abwSource === 'visual_estimation' && res.abw === 8.5 && res.estimatedPopulation === 82000 && res.biomassKg === 697,
      'Should fall back to Visual Estimation when Sampling is missing');

    // Test 6: Sampling ABW takes precedence over Visual Estimation
    samplingEntries = [{ batchId: mockBatch.id, abw: 9.0, date: '2026-04-12', createdAt: '2026-04-12T10:00:00' }];
    res = updateBatchBiomassEstimation(mockBatch);
    assert(res.success && res.abwSource === 'sampling' && res.abw === 9.0 && res.estimatedPopulation === 82000 && res.biomassKg === 738,
      'Sampling ABW should take precedence over Visual Estimation');

    // Test 7: Audit history logging
    assert(biomassEntries.length > 0, 'Should save entries to calculation audit log');
    const auditSizeBefore = biomassEntries.length;
    
    // Recalculating with same parameters should not add duplicates
    res = updateBatchBiomassEstimation(mockBatch);
    assert(biomassEntries.length === auditSizeBefore, 'Should not log duplicate audit entry if inputs are unchanged');

    // Recalculating with different parameters should log new audit entry
    samplingEntries = [{ batchId: mockBatch.id, abw: 10.0, date: '2026-04-15', createdAt: '2026-04-15T10:00:00' }];
    res = updateBatchBiomassEstimation(mockBatch);
    assert(biomassEntries.length === auditSizeBefore + 1, 'Should log new audit entry when parameters change');

  } catch (err) {
    console.error('Self-tests encountered an error:', err);
    failed++;
  } finally {
    // Restore original state
    hapaEntries = oldHapa;
    samplingEntries = oldSampling;
    growthEntries = oldGrowth;
    biomassEntries = oldBiomass;

    // C14 fix: re-save biomassEntries to localStorage after restoring the original
    // array. updateBatchBiomassEstimation() internally calls saveBiomassEntries()
    // which wrote the test entries (batchId: 'test_batch_123') to localStorage.
    // Without this re-save, the polluted entries persist across page reloads.
    try { saveBiomassEntries(); } catch (e) {
      console.error('[AquaLog Self-tests] Failed to restore biomassEntries to localStorage:', e);
    }
  }

  console.log(`🧪 Self-tests completed: ${passed} passed, ${failed} failed.`);
  return { passed, failed };
}
window.runBiomassSelfTests = runBiomassSelfTests;

function runWeightManagementSelfTests() {
  console.log('🧪 Starting Weight Management Module self-tests...');
  let passed = 0;
  let failed = 0;

  const assert = (cond, msg) => {
    if (cond) {
      console.log(`✅ Passed: ${msg}`) // L2 fix: removed dead ternary (cond is always truthy here);
      passed++;
    } else {
      console.error(`❌ Failed: ${msg}`);
      failed++;
    }
  };

  const mockBatch = {
    id: 'test_weight_batch_123',
    shrimpCount: 100000,
    stockingDate: '2026-04-01',
    batchNumber: 98,
    status: 'active'
  };

  const oldSampling = samplingEntries;
  const oldGrowth = growthEntries;

  try {
    // Test 1: No entries
    samplingEntries = [];
    growthEntries = [];
    let weight = getPrimaryBatchWeight(mockBatch);
    assert(weight === null, 'Should return null weight if no entries exist');

    // Test 2: Only visual growth entries exist
    growthEntries = [
      { id: 'v1', batchId: mockBatch.id, doc: 10, weightGrams: 5.5, date: '2026-04-10' },
      { id: 'v2', batchId: mockBatch.id, doc: 15, weightGrams: 6.8, date: '2026-04-15' }
    ];
    weight = getPrimaryBatchWeight(mockBatch);
    assert(weight !== null && weight.weightGrams === 6.8 && weight.source === 'visual_estimation', 'Should return latest visual weight if no sampling exists');

    // Test 3: Sampling weight exists (Sampling precedence)
    samplingEntries = [
      { id: 's1', batchId: mockBatch.id, doc: 20, abw: 8.5, date: '2026-04-20', createdAt: '2026-04-20T10:00:00' }
    ];
    weight = getPrimaryBatchWeight(mockBatch);
    assert(weight !== null && weight.weightGrams === 8.5 && weight.source === 'sampling', 'Should return sampling weight if it exists (takes precedence)');

    // Test 4: Multiple sampling entries, should return latest (first in sorted list)
    samplingEntries = [
      { id: 's2', batchId: mockBatch.id, doc: 25, abw: 10.2, date: '2026-04-25', createdAt: '2026-04-25T10:00:00' },
      { id: 's1', batchId: mockBatch.id, doc: 20, abw: 8.5, date: '2026-04-20', createdAt: '2026-04-20T10:00:00' }
    ];
    const sEntries = getSamplingForBatch(mockBatch.id);
    assert(sEntries.length === 2 && sEntries[0].abw === 10.2, 'getSamplingForBatch should return sampling sorted newest first');

    weight = getPrimaryBatchWeight(mockBatch);
    assert(weight !== null && weight.weightGrams === 10.2 && weight.source === 'sampling', 'Should return the latest sampling weight when multiple exist');

  } catch (err) {
    console.error('Weight Management Self-tests encountered an error:', err);
    failed++;
  } finally {
    samplingEntries = oldSampling;
    growthEntries = oldGrowth;
  }

  console.log(`🧪 Weight Management Self-tests completed: ${passed} passed, ${failed} failed.`);
  return { passed, failed };
}
window.runWeightManagementSelfTests = runWeightManagementSelfTests;

// --- Monkey Patch Hooks ---
/* ─── Hook into renderBatchDashboard ─── */
// Patch renderBatchDashboard to also call renderAnalyticsTabHeader
const _origRenderBatchDashboard = renderBatchDashboard;
renderBatchDashboard = function(batch) {
  _origRenderBatchDashboard(batch);
  renderAnalyticsTabHeader(batch);
};

/* ── Patch switchPage: render Settings when navigating to it ── */
const _origSwitchPageForSettings = switchPage;
switchPage = function(pageId) {
  _origSwitchPageForSettings(pageId);
  // renderSettingsPage removed — no Appearance section to re-render.
  // Settings-page rendering is now handled by renderSitesSettings() inside switchPage.
};

// Hook switchPage
const _origSwitchPageForInventory = switchPage;
switchPage = function(pageId) {
  _origSwitchPageForInventory(pageId);
  
  if (pageId === 'pageInventory') {
    const sites = window.SiteManager ? window.SiteManager.loadSites() : [];
    const activeSiteId = $('inventorySiteSelect')?.value || (sites[0]?.id);
    ['inventorySiteSelect', 'feedDetailSiteSelect', 'medDetailSiteSelect', 'fuelDetailSiteSelect', 'reportsSiteSelect'].forEach(id => {
      populateInventorySiteSelect(id, activeSiteId);
    });
    renderInventoryDashboard();
  } else if (pageId === 'pageFeedDetail') {
    const activeSiteId = $('feedDetailSiteSelect')?.value || $('inventorySiteSelect')?.value;
    populateInventorySiteSelect('feedDetailSiteSelect', activeSiteId);
    renderFeedDetailPage();
  } else if (pageId === 'pageMedicineDetail') {
    const activeSiteId = $('medDetailSiteSelect')?.value || $('inventorySiteSelect')?.value;
    populateInventorySiteSelect('medDetailSiteSelect', activeSiteId);
    renderMedicineDetailPage();
  } else if (pageId === 'pageFuelDetail') {
    const activeSiteId = $('fuelDetailSiteSelect')?.value || $('inventorySiteSelect')?.value;
    populateInventorySiteSelect('fuelDetailSiteSelect', activeSiteId);
    renderFuelDetailPage();
  } else if (pageId === 'pageInventoryReports') {
    const activeSiteId = $('reportsSiteSelect')?.value || $('inventorySiteSelect')?.value;
    populateInventorySiteSelect('reportsSiteSelect', activeSiteId);
    initReportsPage();
  }
};

// Hook feed log handlers
// C1/C2 fix: handleSubmit and doSaveEditFeed monkey-patches removed — logic moved
// directly into the function bodies so it actually executes. The old patches were
// either dead (handleSubmit's listener captured the IIFE-local, not window.handleSubmit)
// or broken (doSaveEditFeed checked editFeedIdx after the original had nulled it).

const _origDoDelete = doDelete;
doDelete = function() {
  const result = _origDoDelete();
  try { refreshActiveInventoryPage(); } catch(_) {}
  return result;
};


// Global Keyboard Shortcuts & Tooltip click delegates
window.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.code === 'KeyI') {
    e.preventDefault();
    switchPage('pageInventory');
  }
  if (e.key === 'Escape') {
    const openModals = document.querySelectorAll('.modal-overlay:not(.hidden)');
    if (openModals.length > 0) {
      e.preventDefault();
      const modalId = openModals[openModals.length - 1].id;
      closeModal(modalId);
    }
  }
});

document.addEventListener('click', (e) => {
  const trigger = e.target.closest('.inv-tooltip-trigger');
  if (trigger) {
    e.stopPropagation();
    const bubble = trigger.nextElementSibling;
    if (bubble && bubble.classList.contains('inv-tooltip-bubble')) {
      const isOpen = bubble.classList.contains('show');
      document.querySelectorAll('.inv-tooltip-bubble.show').forEach(b => b.classList.remove('show'));
      if (!isOpen) bubble.classList.add('show');
    }
  } else {
    document.querySelectorAll('.inv-tooltip-bubble.show').forEach(b => b.classList.remove('show'));
  }
});

// Auto boot on DOM load — wrapped in try/catch so inventory errors never freeze splash
function _safeBindInventoryModule() {
  try { bindInventoryEvents(); } catch(e) { console.error('[AquaLog] bindInventoryEvents error:', e); }
  try { bindReportsEvents(); } catch(e) { console.error('[AquaLog] bindReportsEvents error:', e); }
}
function _safeBindIntelligence() {
  try { bindAquaLogIntelligenceEvents(); } catch(e) { console.error('[AquaLog] bindAquaLogIntelligenceEvents error:', e); }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
  document.addEventListener('DOMContentLoaded', _safeBindInventoryModule);
  document.addEventListener('DOMContentLoaded', _safeBindIntelligence);
} else {
  initApp();
  _safeBindInventoryModule();
  _safeBindIntelligence();
}

// Expose handleReportHeaderSort globally for onclick handler execution
window.handleReportHeaderSort = handleReportHeaderSort;
})();
