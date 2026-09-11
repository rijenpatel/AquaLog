# AquaLog — Navigation / Layout / KPI & Dashboard Usability Overhaul
## Developer Handoff Document

**Scope**: Everything needed to port this phase into the production codebase.
**Baseline**: post-P0-fix tree (analyzer clean, 164/164 tests passing).
**Result after this phase**: analyzer 0 issues · 168/168 tests (164 pre-existing + 4 new).
**Apply method**: `git apply aqualog-navigation-usability.patch` from the repo root (patch paths are prefixed `aqualog/` — strip or adjust with `git apply -p2` if your repo root IS the flutter project), or copy the 11 files listed in §9 and reconcile manually.

---

## 0. THE PROBLEM THIS PHASE SOLVES

The original shell had **7 bottom-nav tabs** (Overview · Manage · Stock · Log Feed · Finance · Reports · Settings):

1. **Too many tabs.** Material 3 guidance is 3–5 destinations. With 7 items on a 390px phone, labels truncated and touch targets shrank — worse in Hindi (Devanagari strings run ~30% wider).
2. **Tasks mixed with destinations.** "Log Feed" is a *task* (something you do 2–5×/day), not a *place*. Making it a tab meant: to log feed you switched context to a whole page, lost your dashboard place, then had to navigate back.
3. **Settings is not a daily destination.** It occupied 1/7 of the most valuable screen real estate but is used ~once a month.
4. **KPIs were buried.** Farm-level status (how many active batches, today's feed, sampling due) required scrolling past hero cards. Batch-level: a 15-section single scroll view with no wayfinding — reaching "Harvest Outlook" meant 8+ swipe-scrolls.
5. **State loss on tab switch.** The `IndexedStack` children list was rebuilt on every `setState`, so each tab's scroll position and in-progress form state reset when you switched away and back.
6. **Overflow at accessibility font scales.** At large text scale (≥1.6, common for the target 45+ farmer demographic), multiple `RenderFlex overflow` pixels appeared: dashboard hero, batch card headers, chart headers, settings rows, finance break-even row, first-pond guide.

---

## 1. NAVIGATION RESTRUCTURE — 7 TABS → 5 TABS

### 1.1 `lib/app/app.dart` — `AppMainNavigation` (rewritten)

**What changed:**

```dart
// OLD: 7 pages, list rebuilt every build:
//   [Dashboard, Manage, Inventory, FeedLogging, Finance, Reports, Settings]

// NEW: 5 pages, built once and memoized:
late final List<Widget> _pages = [
  DashboardPage(
    // No onLogFeedTap: batch-context feed logging is handled by the view's
    // own fallback + the global Quick Actions FAB covers context-free logging.
    onManageTap: () => setState(() => _currentIndex = 1),
    onInventoryTap: () => setState(() => _currentIndex = 2),
  ),
  const ManagePage(),
  const InventoryHubPage(),
  const FinancePage(),
  const ReportsPage(),
];
```

**What it does:**
- `late final` = the five page widgets are constructed **exactly once** for the lifetime of the shell. `IndexedStack(index: _currentIndex, children: _pages)` keeps all 5 alive but shows only the selected one.
- Because the instances never change identity, Flutter's element tree (and thus each page's `ScrollController` positions, expanded cards, half-filled forms) survives tab switches.

**Why it's useful:** Switching Overview → Finance → Overview no longer resets your dashboard scroll. Previously the list literal inside `build` created new widget instances each `setState`, and `IndexedStack` diffing treated them as replaced → state loss.

**Second change — Settings becomes a pushed route:**

```dart
void _openSettings() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(ref.read(appSettingsProvider).tr('settings'))),
        body: const SettingsPage(),
      ),
    ),
  );
}
```

Settings now slides over the shell with a working back button, instead of being tab #7. The SettingsPage itself keeps working because it only needs a body slot (its layout was already a scrollable column; the P0 version had leftover "return to overview" logic which is no longer reachable and can be deleted).

**Third change — FAB wiring:** `_openQuickActions() => AquaQuickActions.show(context, ref)` passed to `AquaScaffold.onQuickActionsTap` (see §2).

### 1.2 `lib/core/widgets/aqua_scaffold.dart` — the shell (rewritten)

**What changed:**

A) **Destination lists** — `_bottomDestinations()` and `_railDestinations()` now return exactly 5 entries: Overview (`dashboard` icons), Manage (`water`), Stock (`inventory_2`), Finance (`account_balance_wallet`), Reports (`bar_chart`). All labels via `settings.tr(...)` so EN/HI both fit in 5 slots.

B) **New constructor params:** `onSettingsTap`, `onQuickActionsTap` (plus existing `onSearchTap`). The scaffold is now the single owner of the gear + FAB affordances.

C) **Quick Actions FAB** (compact layout):

```dart
floatingActionButton: widget.onQuickActionsTap != null
    ? _buildQuickActionsFab(theme) : null,
floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
```

The FAB is a transparent `FloatingActionButton` wrapping an `Ink` with the app's teal gradient (`0xFF006876 → 0xFF00A2B8`) and a ⚡ `bolt_rounded` icon. Tooltip = localized "Quick Actions". It only renders when a callback is supplied — pages that don't want it simply omit `onQuickActionsTap`.

D) **Tablet/desktop (≥600px) layout:** the FAB moves to `NavigationRail.leading` (a smaller 56px variant — `_buildQuickActionsFab(theme, small: true)`), and the settings gear becomes `NavigationRail.trailing` pinned to the bottom. So on tablets: rail = [⚡, 5 destinations…, gear-at-bottom].

E) **Settings gear in the app bar (all sizes):**

```dart
IconButton(
  tooltip: settings.tr('open_settings'),
  icon: const Icon(Icons.settings_outlined),
  onPressed: widget.onSettingsTap,
),
```

F) **Defensive hardening:**
- `selectedIndex: widget.selectedIndex.clamp(0, 4)` — a stale index >4 (e.g. old saved state referencing tab 6) can no longer crash `NavigationBar`/`NavigationRail` (they assert on out-of-range).
- `HapticFeedback.selectionClick()` on every destination tap — tactile confirmation for outdoor use (farm hands, gloves, bright sun).
- App-bar title wrapped in `Flexible` with `overflow: TextOverflow.ellipsis` — long Hindi titles can no longer push the clock/actions row off-screen.
- Existing behaviors kept: 1s-tick live clock, "Synced" status pill with glow dot, global search icon, logo when no custom title.

---

## 2. NEW FILE — `lib/core/widgets/aqua_quick_actions.dart` (389 lines)

**The headline feature.** A single static entry point:

```dart
AquaQuickActions.show(context, ref);
```

**What it does (flow):**

1. `HapticFeedback.lightImpact()` — touch feedback on open.
2. **Resolves the target batch/pond in 3 fallback tiers (all synchronous `ref.read`, no async gap before context use):**
   - Tier 1: if the dashboard is currently scoped to a batch (`ref.read(dashboardContextProvider) is BatchDashboardContext`) → load THAT batch (must still be `status == 'active'`, else fall through);
   - Tier 2: otherwise query the **most recently stocked active batch** (`b.status == 'active'`, `ORDER BY stockingDate DESC LIMIT 1`);
   - Tier 3: no active batch → fall back to the **first active pond by name** (alphabetical) so water tests remain loggable during pond conditioning before stocking; if no pond either, `pond == null`.
3. Shows a rounded modal bottom sheet (transparent background + custom container, `SafeArea`-aware, drag handle) with a 2×2 grid of the four highest-frequency field tasks:

| Tile | Icon | Accent | Requires | Disabled hint |
|---|---|---|---|---|
| Log Feed Session | `restaurant_rounded` | `AquaColors.primary` | batch | "Needs an active stocked batch" |
| Log Water Test | `water_drop_rounded` | `0xFF0288D1` | pond only | "Create a pond first" |
| Add Sampling | `scale_rounded` | `0xFF7B1FA2` | batch | "Needs an active stocked batch" |
| Log Mortality | `heart_broken_rounded` | `AquaColors.statusCritical` | batch | "Needs an active stocked batch" |

4. Header subtitle tells the user exactly where data will land: `"Pond name · Batch #N"` (or `"Pond name · needs active batch"` in the pond-only case) — **no silent wrong-pond logging**.
5. Disabled tiles: 55% opacity, grey accent, `lock_outline` icon in the corner, subtitle replaced by the disabled hint, `onTap: null`. Always-visible-and-explained beats hidden.
6. **Invocation (`_invoke`) reuses existing entry points — zero new data paths:**
   - Feed → `Navigator.push(FeedLoggingPage(initialPondId: ctx.pond.id))`
   - Water → `WaterQualityEntryPage.show(context, pondId: ctx.pond.id)`
   - Sampling → `SamplingDialog.show(context, batch: ctx.batch!, pond: ctx.pond!)`
   - Mortality → `MortalityLoggingDialog.show(context, batchId:, pondId:)`

**Why it's useful:** Before, logging a feed session from the Reports tab took 4+ hops (Reports → Overview → tap batch → scroll a 15-section page to bottom → Log Feed). Now: **1 tap on the ⚡ FAB from ANY screen, 1 tap on the tile = 2 taps total**, with the correct pond/batch pre-resolved. This matches the app's core field workflow (feed 2–5×/day, water test daily).

**Implementation notes for the porting agent:**
- `childAspectRatio: 1.4` on the 2×2 grid is deliberate — leaves room for title + 2-line subtitle at accessibility font scales.
- DB reads use Drift selectors directly (`db.select(db.batches)..where(...)`) — no new providers needed.
- The sheet pops itself before invoking (`Navigator.of(sheetContext).pop()` then `_invoke`) so routes pushed inside don't stack on the sheet.

---

## 3. FARM PULSE KPI STRIP — `lib/features/dashboard/dashboard_page.dart`

**New widget method** `_buildFarmPulse(...)` inserted directly under the farm-overview context switcher, above the hero card — visible without scrolling on first paint.

**Four compact tiles in a Row** (each `Expanded` so they share width equally):

| Tile | Value | Source |
|---|---|---|
| Active Batches | count | batches with `status == 'active'` |
| Today's Feed | `12.4 kg` / `850 g` | sum of today's `FeedRecord.totalGrams` (g-format when < 1 kg — feed starts tiny) |
| Sampling Due | count of batches overdue | accent = `theme.colorScheme.error` when > 0, else `AquaColors.statusOptimal` |
| Stocked Pcs | `4.5L pcs` / `120k pcs` | sum of `shrimpStockedCount`, compact-formatted (lakh 'L' / thousand 'k' — Indian farm convention) |

**Behavioral details:**
- Section header: `monitor_heart_rounded` icon + localized "Farm Pulse" label.
- The Sampling-Due tile is **self-alerting**: red accent + glowing dot when any batch is overdue, green otherwise. It answers "am I late on anything?" without opening anything.
- Values use `FontFeature.tabularFigures()` — digits don't jitter as numbers change.
- Tile internals: icon row (13px) → value (`titleMedium`, w700) → label (`labelSmall`, 9.5px), all `maxLines: 1` + ellipsis.
- KPI data is computed from the streams the dashboard page already watches — **no new providers or queries were added**; it reuses `activeBatches`, feed records, and the existing sampling-status calculator.

**Why it's useful:** The user's core ask was "KPIs and dashboard more usable". Farm Pulse puts the four numbers a shrimp farmer checks every morning into the first viewport, replacing scroll-hunting through hero + weather + alerts.

---

## 4. BATCH CARD CYCLE PROGRESS — `dashboard_page.dart` (active batch list)

Each active-batch card (in the farm overview's "Active Batches" section) now shows **how far through its crop cycle the batch is**:

```dart
// cyclePct = doc / targetDoc * 100, clamped to 100
Row(children: [
  Expanded(child: ClipRRect(
    borderRadius: BorderRadius.circular(100),
    child: LinearProgressIndicator(
      value: cyclePct / 100.0,
      minHeight: 4,
      valueColor: const AlwaysStoppedAnimation(AquaColors.primary),
    ),
  )),
  const SizedBox(width: 8),
  Text('${cyclePct.toStringAsFixed(0)}%'), // tabular figures, primary color
]);
```

- The percentage sits right of a thin 4dp rounded progress bar; DOC-vs-target math comes from existing dashboard data (`doc` and `targetDoc` were already computed).
- Card header was also re-wrapped in `Wrap` (title + DOC chip + Sampling-Due/Up-To-Date chips flow to a second line at narrow widths instead of overflowing).

**Why it's useful:** "Batch #4 is 62% through its cycle" was previously visible only ~6 sections deep inside the batch dashboard. Now farm overview doubles as a cycle tracker: which ponds are close to harvest is glanceable.

---

## 5. BATCH DASHBOARD — STICKY SECTION JUMP RAIL (`batch_dashboard_view.dart`)

The batch dashboard is a single `SingleChildScrollView` with **15+ stacked sections**. The change adds a **pinned chip rail** above the scroll body (outside the `ScrollView`, inside the column → never scrolls away):

**New state (6 GlobalKeys):**

```dart
final GlobalKey _healthSectionKey = GlobalKey();
final GlobalKey _feedSectionKey = GlobalKey();
final GlobalKey _growthSectionKey = GlobalKey();
final GlobalKey _fcrSectionKey = GlobalKey();
final GlobalKey _harvestSectionKey = GlobalKey();
final GlobalKey _financeSectionKey = GlobalKey();
```

**Scroll mechanism:**

```dart
void _jumpToSection(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return;
  Scrollable.ensureVisible(
    ctx,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    alignment: 0.05, // target lands near top, small offset under the rail
  );
}
```

**Anchors:** the relevant existing sections are wrapped in `KeyedSubtree(key: _xxxSectionKey, child: …)` — sections 2B (PondHealth), 7 (Feed Ledger), 9 (Growth chart), 11 (FCR card), 12 (Harvest outlook), 13 (Financial overview).

**Rail UI:** full-width container, bottom hairline border, horizontal `SingleChildScrollView` of `ActionChip`s (icon 15px + 11.5px w600 label): **Health · Feed · Growth · Harvest · Finance**. Each chip = one `_jumpToSection` call.

**Why it's useful:** Reaching Harvest Outlook previously cost ~8 swipe-scrolls through charts; now it's 1 tap, and the rail is *always visible* (sticky). This is the classic long-page wayfinding pattern (same idea as README anchors / settings sub-nav).

---

## 6. BATCH DASHBOARD — TAPPABLE KPI CARDS (`_buildPrimaryKpiGrid`)

The 4 primary KPI cards were display-only. Each now carries an `onTap` that opens the **evidence behind the number**:

| KPI card | Tap action |
|---|---|
| Average Weight (`abw g` + ADG chip) | opens `SamplingHistorySheet.show(context, batch:, pond:)` — the ABW evidence trail |
| Current Count (`pcs/kg` + grade chip) | `_jumpToSection(_growthSectionKey)` — growth/ABW trend chart |
| Standing Biomass (`tons`) | `_jumpToSection(_harvestSectionKey)` — harvest outlook scenario center |
| Survival & FCR (`%` + FCR chip) | `_jumpToSection(_fcrSectionKey)` — FCR performance & range card |

Supporting changes in `_buildKpiCard`: `InkWell` wrapper (ripple), `HapticFeedback.lightImpact()` on tap, and an "open-in-full" affordance icon (`open_in_full_rounded`, 14px, ~40% opacity) top-right so tappability is discoverable, not hidden.

Supporting change in **`lib/core/widgets/aqua_metric_card.dart`** (shared widget): added optional `onTap` param → wraps card in `Material`+`InkWell` with `borderRadius` matching the card (18px) + light haptic when tapped; title and value now `Flexible` + ellipsis. Fully backward-compatible — all existing call sites without `onTap` render exactly as before (InkWell with `onTap: null` is inert).

**Why it's useful:** KPI numbers invite "where did this come from?" questions. Linking each KPI to its evidence (sampling records) or its decision context (harvest scenarios) turns a passive dashboard into an interactive one, with zero new screens built — pure re-wiring of existing widgets.

---

## 7. OVERFLOW / ACCESSIBILITY HARDENING (multiple files)

Found by testing at 390px width with the widget-test Ahem font (glyphs ≈ 2× real widths ≈ fontScale 2.0). All were `RenderFlex overflowed by N pixels` errors:

| File / location | Fix |
|---|---|
| `dashboard_page.dart` hero card | value + unit + sessions pill re-flowed with `Wrap` |
| `dashboard_page.dart` 7-day chart header | title & avg label wrapped in `Flexible` + ellipsis |
| `dashboard_page.dart` active-batches header | converted to `Wrap` |
| `dashboard_page.dart` batch card header | title + DOC + status chips → `Wrap(spacing:6, runSpacing:4)` |
| `aqua_scaffold.dart` app-bar title | `Flexible` + ellipsis (Hindi titles) |
| `aqua_quick_actions.dart` tiles | `childAspectRatio: 1.4`; title 1-line, subtitle 2-line ellipsis |
| `settings_page.dart` setting rows | label + description **stacked in a Column above** the `SegmentedButton` (was a spaceBetween Row — SegmentedButtons can't shrink); numeric segment labels |
| `finance_page.dart` break-even row | wrapped, formatted |
| `first_pond_user_guide.dart` header + presets | title in `Flexible` + ellipsis; presets row re-flowed |
| `aqua_metric_card.dart` title/value | `Flexible` + ellipsis |

**Why it's useful:** The target demographic (farmers, 40+, outdoor glare) uses large font scales. Yellow-strip overflow errors look broken and can hide content; these fixes make every touched surface safe to ~2× text scale.

---

## 8. LOCALIZATION — `lib/core/localization/translations.dart`

**29 new keys, EN + HI both** (3-level `tr()` fallback already resolves them):

| Key | EN | HI (Devanagari) |
|---|---|---|
| `quick_actions` | Quick Actions | त्वरित क्रियाएं |
| `qa_log_feed` / `_sub` | Log Feed Session / Record ration & tray check | दाना सत्र दर्ज करें / मात्रा और ट्रे जांच |
| `qa_water_test` / `_sub` | Log Water Test / pH, DO, ammonia readings | पानी परीक्षण दर्ज करें / pH, DO, अमोनिया रीडिंग |
| `qa_sampling` / `_sub` | Add Sampling / Cast-net ABW measurement | सैंपलिंग जोड़ें / कास्ट-नेट ABW माप |
| `qa_mortality` / `_sub` | Log Mortality / Dead shrimp count entry | मृत्यु दर्ज करें / मृत झींगा गिनती |
| `qa_needs_batch` | Needs an active stocked batch | सक्रिय बैच आवश्यक है |
| `qa_needs_pond` | Create a pond first | पहले तालाब बनाएं |
| `open_settings` | Open Settings | सेटिंग्स खोलें |
| `farm_pulse` | Farm Pulse | फार्म सारांश |
| `kpi_active_batches` | Active Batches | सक्रिय बैच |
| `kpi_today_feed` | Today's Feed | आज का दाना |
| `kpi_sampling_due` | Sampling Due | सैंपलिंग बाकी |
| `kpi_stocked` | Stocked Pcs | कुल बीज पीसी |
| `kpi_cycle_progress` | Cycle | चक्र |
| `jump_to_section` | Jump to section | अनुभाग पर जाएं |
| `section_health/feed/growth/harvest/finance` | Health / Feed / Growth / Harvest / Finance | स्वास्थ्य / आहार / वृद्धि / फसल / वित्त |

---

## 9. FILE MAP & APPLY ORDER

| # | File | Status | Depends on |
|---|---|---|---|
| 1 | `lib/core/localization/translations.dart` | modified (+29 keys ×2 languages) | — |
| 2 | `lib/core/widgets/aqua_metric_card.dart` | modified (`onTap`, haptics, ellipsis) | — |
| 3 | `lib/core/widgets/aqua_quick_actions.dart` | **NEW** (389 lines) | #1 |
| 4 | `lib/core/widgets/aqua_scaffold.dart` | rewritten (5 dest, FAB, gear, clamp) | #1 |
| 5 | `lib/features/dashboard/dashboard_page.dart` | modified (Farm Pulse, cycle bar, Wraps) | #1 |
| 6 | `lib/features/dashboard/batch_dashboard_view.dart` | modified (jump rail, anchors, KPI taps) | #1 |
| 7 | `lib/app/app.dart` | rewritten (5-tab shell, memoized stack, settings push) | #3 #4 |
| 8 | `lib/features/settings/settings_page.dart` | modified (stacked rows + format) | — |
| 9 | `lib/features/finance/finance_page.dart` | modified (overflow + format) | — |
| 10 | `lib/features/manage/widgets/first_pond_user_guide.dart` | modified (overflow) | — |
| 11 | `test/navigation_usability_test.dart` | **NEW** (4 tests) | #1–#7 |

**Regressions to expect & verify:**
- Old callers that constructed `AquaScaffold` with 7-index values must clamp (the scaffold now clamps defensively anyway).
- `widget_test.dart` (pre-existing) asserts `'Overview'` / `'Manage'` text — still passes because both labels survive in the 5-tab design.
- `SettingsPage` previously reachable as tab 7; anything deep-linking to it must push the new route instead.
- If your production `dashboardContextProvider` API differs, adjust the Tier-1 read in `aqua_quick_actions.dart` (it only needs the selected batch id).

## 10. NEW TESTS — `test/navigation_usability_test.dart` (4 tests)

Boots the real app (in-memory Drift DB + demo data + mocked SharedPreferences) on a 390×844 surface:

1. **5 destinations exactly** — `NavigationBar` + 5 `NavigationDestination`s, all five labels found, `'Log Feed'` findsNothing (the task is no longer a tab).
2. **Quick Actions sheet** — FAB tap → sheet shows all four tiles; tapping "Log Water Test" pushes the water-quality entry page.
3. **Settings as pushed route** — gear tap → `'Settings & Configuration'` header appears; `pageBack()` → gone (push, not tab).
4. **Tab switch + Farm Pulse persistence** — taps destination index 3 (Finance), back to 0 (Overview), `'Farm Pulse'` still renders (IndexedStack memoization works).
