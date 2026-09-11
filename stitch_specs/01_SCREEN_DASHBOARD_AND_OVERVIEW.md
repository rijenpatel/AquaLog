# 01 — Screen Specification: Overview / Dashboard

> **Screen ID**: `pageDashboard`  
> **Route / Navigation**: Bottom Nav "Overview" (`data-tab="overview"`) | Keyboard Shortcut `g` then `d`  
> **Target Component**: `<DashboardPage />`

---

## 1. Screen Objective & User Mental Model

The Dashboard is the central operational command bridge for the aquaculture farm. A shrimp farmer visits this screen multiple times per day to answer four critical questions in under five seconds:
1. *How much feed has been broadcast today across the farm, and are all scheduled sessions on track?*
2. *Are any ponds due for sampling or showing abnormal feed consumption?*
3. *What does the current weather dictate for today’s feeding volume (heat stress or rain risk)?*
4. *How is each batch performing regarding Days of Culture (DOC), Biomass, and Feed Conversion Ratio (FCR)?*

The screen employs a **Dual-Context Engine**:
- **Farm Overview Context**: Aggregates all ponds, farm-wide 7-day trends, daily task lists, weather alerts, and cross-cutting inventory warnings.
- **Batch-Specific Context**: Drills down into a single pond/batch cycle to display localized biomass calculations, growth curves, period-by-period FCR, and water quality parameters.

---

## 2. Visual Hierarchy & Component Tree

```
<DashboardPage>
  ├── <ContextSelectorCard> (Farm Overview vs Active/Completed Batches)
  │
  ├── [FARM OVERVIEW MODE]
  │     ├── <HeroCard>
  │     │     ├── <BilingualGreeting> (Good morning / नमस्ते किसान भाई!)
  │     │     ├── <TodayTotalFeedDisplay> (Big numeric counter in grams or kg)
  │     │     ├── <PondFeedChipsRow> (Feed breakdown per active pond)
  │     │     └── <SevenDayFeedTrendChart> (Chart.js bar/line canvas + summary box)
  │     │
  │     ├── <OperationsSection>
  │     │     ├── <SamplingAlertBanner> (Triggers if sampling > 7 days overdue)
  │     │     └── <ActiveBatchCardsGrid> (Cards showing DOC, lifecycle stage, feeds completed)
  │     │
  │     ├── <FinanceQuickAccessCard> (Direct link to Finance module with revenue/cost summary)
  │     │
  │     ├── <TodaySessionsSection> (Visible in both Farm and Batch modes)
  │     │     ├── <PondSelectorStrip> (Horizontal scrolling chips)
  │     │     ├── <DateNavigator> (Previous / Current / Next date controls)
  │     │     └── <DailyFeedTimeline> (Cards for 7AM, 11AM, 4PM, 7PM with check-tray pills)
  │     │
  │     └── <SmartDecisionWidgets>
  │           ├── <TodaysTasksWidget> (Checklist: pending feeds, sampling due, low stock)
  │           ├── <AIInsightsCard> (Trend anomaly analysis & feed adjustment recommendation)
  │           ├── <PondHealthScoreCard> (0-100 circular gauge with 4 pillar breakdown)
  │           ├── <WeatherFeedRecCard> (Live weather guidance: temperature, rain risk, humidity DO)
  │           ├── <FeedCostCalculator> (Daily feed spend vs cumulative batch feed spend)
  │           ├── <HarvestPredictorCard> (Days to harvest calculation from ADG)
  │           ├── <ActivityTimelineCard> (Chronological farm events audit stream)
  │           └── <BatchComparisonOverTime> (Growth curve overlay across multiple seasons)
  │
  └── [BATCH SPECIFIC MODE]
        ├── <BatchSummaryHeroCard>
        │     ├── <Header> (Pond name, Batch #, Active badge, expandable toggle)
        │     ├── <PrimaryMetricsGrid> (DOC, Biomass kg, Est. Population, ABW g, Survival %)
        │     └── <CollapsibleDetails> (Stocking density pcs/m², seed source, PL age)
        │
        ├── <FCRTrackerCard> (Period-by-period FCR gauge, cumulative FCR, target FCR line)
        ├── <WaterQualityTrendsCard> (DO & pH 7-day safe-band canvas chart)
        ├── <BatchMilestoneTimeline> (Visual stage progression: Stocking -> Nursery -> Harvest)
        └── <TodaySessionsSection> (Scoped strictly to the selected batch's pond)
```

---

## 3. UI Specifications & Styling Tokens

- **Card Styles**: Glassmorphism with deep navy background (`--bg-2: #080f1e`), $1\text{px}$ subtle border (`rgba(255,255,255,0.08)`), $20\text{px}$ border radius (`--r-lg`), and soft drop shadows (`--shadow-md: 0 8px 30px rgba(0,0,0,0.5)`).
- **Hero Card Blob Effects**: Background animated glowing blobs in cyan (`rgba(0,229,245,0.12)`) and indigo (`rgba(99,102,241,0.08)`) with `filter: blur(40px)`.
- **Primary Metric Typography**: `font-family: 'Outfit'`, font-weight 800, font-size $2.4\text{rem}$ to $3.0\text{rem}$, color `--teal: #00e5f5`.
- **Bilingual Subtitles**: `font-family: 'Noto Sans Devanagari'`, font-size $0.80\text{rem}$, color `--t2: #94a3b8`.
- **Floating Quick-Stats Pill**: Positioned at bottom right (`bottom: 120px; right: 16px; z-index: 90`), background `rgba(8,15,30,0.85)` with `backdrop-filter: blur(12px)`, border `1px solid var(--teal-dim)`, displaying today's total feed and active batch counter. Tap to expand popup.

---

## 4. State Machine & Data Models

### 4.1 Component State Variables
```typescript
interface DashboardState {
  contextMode: 'farm' | 'batch';
  selectedBatchId: string | null;  // null = Farm Overview
  selectedPondId: string | null;   // For sessions strip filtering
  sessionDate: string;             // "YYYY-MM-DD", defaults to todayStr()
  batchDetailsExpanded: boolean;   // Expandable toggle on batch hero card
  quickStatsExpanded: boolean;     // Floating widget toggle
  activeTab: string;
}
```

### 4.2 Required Data Subscriptions (IndexedDB / Zustand)
- `sites`: List of `FarmSite`
- `ponds`: List of `Pond` (filter: active ponds)
- `batches`: List of `Batch` (active and completed)
- `feedRecords`: Records where `Date === sessionDate` or within last 7 days
- `samplings`: Samplings for active batches
- `hapaChecks`: Hapa survival records for active batches
- `inventoryItems`: Check for items below `lowStockThreshold`
- `weatherCache`: Latest temperature, humidity, rain probability

---

## 5. Detailed Logic & Formulas

### 5.1 Context Switching Engine
1. Read `#dashboardContextSelect` value:
   - If value is `'farm'`, set `contextMode = 'farm'`, hide `#batchSummaryCard`, show `#farmOverviewContent`.
   - If value starts with `'batch_'`, extract `batchId = value.replace('batch_', '')`. Look up batch in `batches`. Find parent pond. Set `contextMode = 'batch'`. Hide `#farmOverviewContent`, show `#batchSummaryCard`.
2. Update shortcut button `#batchShortcutBtn` in bottom navigation: if in batch view, show pill *"🦐 View Batch"*; if in farm view, hide it.
3. Automatically refresh all attached intelligence widgets (`refreshAquaTasks`, `refreshAquaInsights`, `refreshAquaTimeline`) with a 120ms debounce.

### 5.2 Hero Section Feed Calculations (Farm Mode)
1. **Today's Total Feed**:
   $$\text{TodayTotalGrams} = \sum_{\text{rec} \in \text{Records}, \text{rec.Date} = \text{today}} \text{rec.TotalGrams}$$
   - If $\text{TodayTotalGrams} \ge 1,000$, display as $\frac{\text{TodayTotalGrams}}{1,000}\text{ kg}$ formatted to 1 decimal place (e.g. `24.5 kg`).
   - If $< 1,000$, display as grams (e.g. `750 g`).
2. **Session Count**:
   $$\text{SessionsLoggedCount} = |\{\text{rec} \in \text{Records} \mid \text{rec.Date} = \text{today}\}|$$
   Sub-label displays: *"X sessions logged today"*.
3. **Pond Breakdown Chips (`#heroChips`)**:
   - Loop through all active ponds.
   - For each pond, sum grams fed today.
   - Render chip: `[ Pond Name: X.X kg ]`. Tap chip to instantly filter the Today’s Sessions timeline below.

### 5.3 7-Day Feed Trend Chart
- Aggregates daily feed totals for the last 7 calendar days (from $T-6$ to $T_0$).
- Chart Type: Chart.js Bar Chart with subtle gradient fill (`rgba(0, 229, 245, 0.8)` to `rgba(0, 229, 245, 0.2)`).
- X-Axis: Short weekday + date (e.g. "Mon 01", "Tue 02").
- Y-Axis: Total feed in kg.
- Empty State: If no records exist in last 7 days, canvas is hidden, and `#farmTrendEmpty` renders *"No Records Available"*.

### 5.4 Sampling Reminder Engine
1. Iterate over all active batches.
2. For each batch, get latest sampling from `al_sampling`.
3. If no sampling exists:
   - Calculate batch DOC. If $DOC \ge 14$, trigger Warning: *"Pond [Name] (DOC [X]) has never been sampled! Sampling is overdue."*
4. If sampling exists:
   - Calculate days elapsed: $\Delta Days = \lfloor \frac{\text{Today} - \text{Latest Sampling Date}}{86,400,000} \rfloor$.
   - If $\Delta Days \ge 7$, trigger Reminder: *"Sampling Due: Pond [Name] was last sampled [X] days ago."*
5. Render banner with direct CTA button: `[ Add Sampling ]` which immediately launches `samplingEntryModal(batchId)`.

### 5.5 Active Batch Summary Cards Grid
For every active batch, render an interactive summary card displaying:
- **Pond Name & Batch #**: e.g. "Pond 1 · Batch #3"
- **Species**: e.g. *L. vannamei*
- **DOC**: Days of Culture calculated via start-of-day math.
- **Lifecycle Stage Badge**:
  - $DOC \le 25$: `🌱 Nursery` (Color: Sky Blue `#38bdf8`)
  - $DOC \le 60$: `🌿 Growout Early` (Color: Teal `#00e5f5`)
  - $DOC \le 90$: `🐟 Growout Mid` (Color: Emerald `#10b981`)
  - $DOC \le 120$: `⚖️ Finishing` (Color: Amber `#fbbf24`)
  - $DOC > 120$: `🎯 Harvest Ready` (Color: Rose `#f43f5e`)
- **Today's Feeding Progress**: Ratio of completed sessions (e.g. `3 / 4 Feeds Done`).
- **Latest ABW & Est. Biomass**: e.g. `ABW: 18.2g · Biomass: 1,840 kg`.
- **Tap Interaction**: Tapping the card switches the dashboard dropdown directly to this batch context.

### 5.6 Daily Feed Timeline & Pond Strip
1. **Pond Strip**: Renders horizontal scrollable chips for active ponds. Includes an "All Ponds" chip in Farm Mode.
2. **Date Navigation**:
   - `[ ‹ ]` moves date back 1 day.
   - `[ Date Label ]` shows formatted date (e.g. "Today, 6 Sep" or "Thu, 4 Sep").
   - `[ › ]` moves date forward 1 day (disabled if date equals today).
3. **Session Cards (Timeline)**:
   - Standard scheduled slots: 7:00 AM, 11:00 AM, 4:00 PM, 7:00 PM.
   - If an entry exists for that time slot:
     - Render **Completed Card**: Feed quantity (kg/g), pellet size mix breakdown, check-tray status badge (`Clean 0%`, `Normal 10%`, or `Leftover 25%`), time logged.
     - Action buttons: Edit (pencil icon opens `editFeedModal`), Delete (trash icon opens `deleteModal`).
   - If slot has passed and no entry exists:
     - Render **Missed / Pending Card** with amber border and CTA button: `＋ Log This Session`.

### 5.7 Batch Context View (When Batch Selected)
When user picks a specific batch from the selector:
1. **Batch Hero Card (`#batchSummaryCard`)**:
   - Calculates Estimated Population: $N_{est} = \text{Stocked} \times \left(\frac{\text{HapaSurvival}}{100}\right)$.
   - Calculates Biomass: $\text{BiomassKg} = \frac{N_{est} \times \text{ABW}}{1,000}$.
   - Displays KPIs:
     - **DOC**: e.g. `DOC 68`
     - **Estimated Biomass**: e.g. `2,140 kg`
     - **Estimated Population**: e.g. `114,000 pcs`
     - **Survival Rate**: e.g. `95.0%`
     - **Latest ABW**: e.g. `18.77 g`
     - **Current FCR**: Cumulative Feed / Biomass, e.g. `1.28`
2. **FCR Tracker Module**:
   - Renders period-by-period FCR evolution table and gauge chart.
   - Benchmarks against standard target FCR ($1.20 - 1.35$).
3. **Water Quality Trends Canvas**:
   - Line chart showing last 7 readings of Dissolved Oxygen (DO) and pH.
   - Safe bands shaded: DO green band ($5.0 - 8.0\text{ ppm}$), pH green band ($7.5 - 8.5$).
   - Critical threshold alerts if DO $< 4.0\text{ ppm}$ (triggers high-priority warning).

---

## 6. Smart Decision Widgets (Audited from extra-features.js)

### 6.1 Today's Tasks Widget (`initTodaysTasksWidget`)
A prioritized operational checklist that evaluates farm state in real time:
1. **Unlogged Feed Sessions**: Detects which scheduled feed times have passed today without a record.
2. **Sampling Due Alert**: Flags batches where $\Delta Days \ge 7$ since last sampling.
3. **Low Stock Supplies**: Warns if any feed bag or probiotic is below minimum threshold.
4. Each item includes a direct actionable button (`Log Feed`, `Sample Now`, `Order Stock`).

### 6.2 AI Insights & Anomaly Card (`initInsightsCard`)
Rule-based intelligence engine evaluating 7-day patterns:
- **Underfeeding / Overfeeding Anomaly**: Compares today’s feed against 3-day rolling average. If deviation $> 20\%$, alerts manager.
- **Growth Milestone**: Detects when shrimp cross size thresholds (e.g. *“Congratulations! Batch #2 reached 20g (50 count) average size.”*).
- **Feed Increment Suggestion**: Evaluates check-tray history; if trays have been clean for 3 consecutive sessions, recommends $+5\%$ feed increase.

### 6.3 Pond Health Score Card (`initPondHealthScore`)
Renders a 0-100 circular score based on the 4-pillar algorithm (Section 3.8 of Master Spec). Displays color-coded rating:
- **85 - 100**: `Excellent` (Emerald `#10b981`)
- **70 - 84**: `Good` (Cyan `#00e5f5`)
- **50 - 69**: `Fair / Attention Needed` (Amber `#fbbf24`)
- **< 50**: `Critical Risk` (Rose `#f43f5e`)

### 6.4 Weather-Adaptive Feed Guidance Card (`initWeatherFeedRec`)
Pulls current temperature, humidity, and precipitation probability. Displays:
- Weather condition icon and temperature (°C).
- Recommendation status badge (`Ideal Feeding`, `High Heat Alert`, `Rain Cut Alert`).
- Concrete action directives: e.g. *“Cut afternoon feed by 20% due to 35°C water temperature. Increase mechanical aeration during 1 PM - 4 PM.”*

### 6.5 Harvest Predictor (`initHarvestPredictor`)
- Inputs: Current ABW ($18.5\text{g}$), Target Harvest Weight ($25.0\text{g}$), Current ADG ($0.25\text{g/day}$).
- Formula: $\text{Days Remaining} = \frac{25.0 - 18.5}{0.25} = 26\text{ days}$.
- Displays predicted harvest calendar date and estimated final crop biomass.

---

## 7. User Interactions & Event Handlers

| Trigger Element | Event | Action & State Transition |
| :--- | :--- | :--- |
| `#dashboardContextSelect` | `change` | Swaps view mode (`farm` vs `batch`). Triggers 120ms debounced widget refresh. Updates `#batchShortcutBtn`. |
| Active Batch Card | `click` | Sets `#dashboardContextSelect` to `batch_[id]`, transitions to Batch View. |
| `#seeAllSessionsBtn` | `click` | Navigates to Reports History tab (`switchPage('pageReports')`). |
| `#dailyPrev` / `#dailyNext`| `click` | Decrements/increments `sessionDate` by 1 day. Re-renders daily timeline. |
| Pond Strip Chip | `click` | Filters timeline to display only the selected pond's feed entries. |
| Feed Entry Card Pencil Icon | `click` | Populates and opens `editFeedModal(recordId)`. |
| Feed Entry Card Trash Icon | `click` | Opens `deleteModal(recordId)` with confirmation prompt. |
| Floating Quick-Stats Pill | `click` | Toggles expanded modal popup showing farm-wide KPI snapshot. |
| `batchSummaryCard` Chevron | `click` | Toggles `batchDetailsExpanded` state (animates height of details drawer). |

---

## 8. Validation Rules, Edge Cases & Error States

1. **Zero Ponds / First Run Experience**:
   - If `ponds.length === 0`, hide hero cards and render clean onboarding card: *"Welcome to AquaLog! Start by creating your first pond in the Manage tab."* with direct CTA button.
2. **Pond Has No Active Batch**:
   - If user selects a pond that currently has no stocked batch, display inline banner: *"⚠️ Selected pond has no active batch. Stock a batch in Manage to enable feed logging."* Disable feed entry action buttons for that pond.
3. **Missing Weather Connection**:
   - If device is offline or location services are denied, Weather Widget renders fallback: *"Weather data unavailable — using standard feeding schedule."* without throwing errors.
4. **Negative or Zero Sampling Values**:
   - If user attempts to enter $0\text{g}$ weight or count, form rejects input with inline validation error.
5. **Future Date Navigation**:
   - Next Date button (`›`) is strictly disabled when viewing today’s date to prevent logging into the future.

---

## 9. Google Stitch Re-Creation Recommendations

1. **Component Modularization**: Break down into `<FarmDashboard />` and `<BatchDashboard />` subcomponents wrapped by a master context provider.
2. **Animation**: Use Framer Motion for:
   - Smooth layout transitions when toggling between Farm and Batch views (`layoutId`).
   - Staggered entry animation for active batch cards.
   - Spring physics on the circular Pond Health Score gauge.
3. **Real-time Live Queries**: Use Dexie.js `useLiveQuery` to automatically update the dashboard the exact millisecond a feed session is logged in another tab or modal.
