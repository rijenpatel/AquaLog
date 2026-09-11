# 10 — Screen Specification: Analytics, Reports & History

> **Screen ID**: `pageReports`  
> **Route / Navigation**: Bottom Nav "Reports" (`data-tab="reports"`) | Keyboard Shortcut `g` then `r`  
> **Target Component**: `<ReportsAnalyticsPage />`

---

## 1. Screen Objective & Mental Model

Modern aquaculture is data-driven biology. Successful crop outcomes require analyzing feeding velocity, growth trajectories, and conversion ratios across multiple temporal horizons:
- **Daily View**: Granular verification that all daily meals (7AM, 11AM, 4PM, 7PM) were broadcast and check-trays inspected.
- **Weekly View**: Assessing 7-day feed acceleration, comparing current week burn rate against the prior week, and monitoring pellet size transition ratios.
- **Monthly View**: High-level crop progression, monthly feed tonnage, and cost reconciliation.
- **Historical Ledger**: Full searchable, filterable archive of every feeding session ever logged on the farm, with instant CSV data extraction.

---

## 2. Visual Hierarchy & Screen Layout

```
<ReportsAnalyticsPage>
  ├── <ScreenHeroHeader> ("📊 Reports" · "रिपोर्ट और इतिहास · Analytics & History")
  │
  ├── <PeriodTabBar id="reportTabs">
  │     ├── <TabBtn data-tab="daily"> ("Daily") [Active]
  │     ├── <TabBtn data-tab="weekly"> ("Weekly")
  │     ├── <TabBtn data-tab="monthly"> ("Monthly")
  │     └── <TabBtn data-tab="history"> ("History")
  │
  ├── [TAB 1: DAILY id="tabDaily"]
  │     ├── <DateNavigatorRow> (‹ Previous · Date Label · Next ›)
  │     ├── <DailyStatStrip id="dailyStats"> (Total Feed Today, Sessions Logged, Active Ponds Fed)
  │     ├── <SessionsListSection> (Cards showing meal times, pellet mix, and check-tray scores)
  │     └── <PondBreakdownSection id="dailyPondList"> (Horizontal bar cards showing kg fed per pond)
  │
  ├── [TAB 2: WEEKLY id="tabWeekly"]
  │     ├── <DateNavigatorRow> (‹ Previous Week · Week Range · Next Week ›)
  │     ├── <WeeklyStatStrip id="weeklyStats"> (7-Day Total kg, Daily Average kg/day, Delta vs Last Week %)
  │     ├── <WeeklyBarChartCard>
  │     │     ├── <ChartHeader> ("Daily Feed (grams)")
  │     │     └── <Canvas id="chartWeeklyBar" height="160" />
  │     ├── <WeeklyPondBreakdown id="weeklyPondList">
  │     └── <WeeklyFeedSizeBreakdown id="weeklyFeedList"> (Starter vs Grower vs Finisher distribution)
  │
  ├── [TAB 3: MONTHLY id="tabMonthly"]
  │     ├── <DateNavigatorRow> (‹ Previous Month · Month/Year · Next Month ›)
  │     ├── <MonthlyStatStrip id="monthlyStats"> (30-Day Total kg, Daily Average)
  │     ├── <MonthlyBarChartCard>
  │     │     ├── <ChartHeader> ("Weekly Feed Totals (grams)")
  │     │     └── <Canvas id="chartMonthlyBar" height="160" />
  │     ├── <MonthlyPondBreakdown id="monthlyPondList">
  │     └── <TrendCompareCard id="trendCompare"> (Percentage growth/decline vs previous month)
  │
  └── [TAB 4: HISTORY id="tabHistory"]
        ├── <SearchRow>
        │     └── <SearchInput id="historySearch"> ("Search pond, date, feed, notes...")
        ├── <FilterChipsStrip id="historyFilters"> ("All Ponds", "Pond 1", "Pond 2", ...)
        ├── <HistoryRecordsList id="historyList"> (Chronological cards with edit/delete actions)
        └── <ExportRow>
              ├── <CsvExportBtn id="csvExportBtn"> ("⬇ Export CSV")
              └── <ExportCountLabel id="exportCountLbl"> ("245 records")
```

---

## 3. Visual Specifications & Styling Tokens

- **Period Tabs (`#reportTabs`)**:
  - Horizontal pill segment container (`background: rgba(255,255,255,0.03); border: 1px solid var(--border); border-radius: 12px; padding: 4px; display: flex; gap: 4px; margin: 0 16px 14px`).
  - Active Tab Button: `background: rgba(0,229,245,0.12); color: var(--teal); border: 1px solid var(--teal)`.
- **Date Navigation Controls (`.report-date-nav`)**:
  - Centered navigation pill with chevron arrow buttons (`#dailyPrev`, `#dailyNext`) and clean typography label (`font-family: 'Outfit'`, font-weight 700).
- **Stat Strips (`.stat-strip`)**:
  - 3-column KPI card strip displaying: Primary Value (large cyan font), Sub-label (slate 400), and comparison delta pill (green $\uparrow$ or red $\downarrow$).
- **Bar Charts (`#chartWeeklyBar`, `#chartMonthlyBar`)**:
  - Rendered via Chart.js with responsive canvas heights ($160\text{px} - 200\text{px}$).
  - Rounded bar corners (`borderRadius: 6`).
  - Neon cyan/teal gradient fills.

---

## 4. Mathematical Models & Temporal Aggregations

### 4.1 Daily Aggregations (`#tabDaily`)
For the selected date $D$:
$$\text{DailyTotalGrams} = \sum_{\substack{\text{rec} \in \text{Records} \\ \text{rec.Date} = D}} \text{rec.TotalGrams}$$
$$\text{DailyTotalKg} = \frac{\text{DailyTotalGrams}}{1,000}$$
- **Pond Breakdown**:
  $$\text{PondFeedKg}(P) = \frac{\sum_{\substack{\text{rec} \in \text{Records} \\ \text{rec.Date} = D \\ \text{rec.PondId} = P}} \text{rec.TotalGrams}}{1,000}$$
  Renders horizontal percentage bar: $\text{Width \%} = \left( \frac{\text{PondFeedKg}(P)}{\text{DailyTotalKg}} \right) \times 100$.

### 4.2 Weekly Aggregations (`#tabWeekly`)
For a 7-day calendar window $W = [D_{\text{start}}, D_{\text{end}}]$:
$$\text{WeeklyTotalGrams} = \sum_{\substack{\text{rec} \in \text{Records} \\ \text{rec.Date} \in W}} \text{rec.TotalGrams}$$
$$\text{DailyAverageKg} = \frac{\text{WeeklyTotalGrams}}{7 \times 1,000}$$

- **Delta vs Prior Week**:
  $$\Delta \text{Week \%} = \left( \frac{\text{WeeklyTotal}_{\text{current}} - \text{WeeklyTotal}_{\text{prior}}}{\text{WeeklyTotal}_{\text{prior}}} \right) \times 100$$
  - In normal grow-out, feed increases by $+8\% \text{ to } +15\%$ weekly as shrimp biomass expands.
  - A negative delta ($\Delta < 0$) triggers an alert: *"Feed dropped by X% this week. Investigate water quality or disease."*

- **Feed Pellet Size Distribution**:
  $$\text{FeedSize \%}(S) = \left( \frac{\sum \text{Grams of Size } S}{\text{WeeklyTotalGrams}} \right) \times 100$$
  Visualizes transition curves (e.g. Starter dropping from $80\% \rightarrow 20\%$ while Grower 1.2mm rises from $20\% \rightarrow 80\%$).

### 4.3 Monthly Aggregations (`#tabMonthly`)
For a calendar month $M$:
$$\text{MonthlyTotalGrams} = \sum_{\substack{\text{rec} \in \text{Records} \\ \text{rec.Date} \in M}} \text{rec.TotalGrams}$$
$$\text{DailyAverageKg} = \frac{\text{MonthlyTotalGrams}}{\text{DaysInMonth} \times 1,000}$$

---

## 5. History Search & Export Engine (`#tabHistory`)

### 5.1 Multi-Field Fuzzy Search
The search input `#historySearch` evaluates every record in real time across four fields:
1. **Pond Name**: Searches resolved pond name (e.g. "Pond 1").
2. **Date String**: Searches formatted date (e.g. "2026-09-06" or "Sep 6").
3. **Feed Types**: Searches names of feeds mixed in that session.
4. **Notes**: Searches free-form farm observations (e.g. "cloudy water", "high molt", "heavy rain").

### 5.2 Filter Chips
Presents chips for `[ All Ponds ]` followed by individual chips for each active and archived pond. Selecting a chip filters the list instantly without reloading.

### 5.3 Complete RFC 4180 CSV Export Generator
Clicking `#csvExportBtn`:
1. Gathers all records passing the active search and pond filter.
2. Formats tabular export with headers:
   ```csv
   Record ID, Date, Time, Pond Name, Batch Number, Starter (g), Grower 1.2mm (g), Grower 1.6mm (g), Finisher 2.0mm (g), Finisher 2.5mm (g), Other Feed (g), Total Feed (g), Total Feed (kg), Tray Leftover %, Notes, Synced
   ```
3. Dynamically triggers browser download: `AquaLog_Feed_History_YYYY-MM-DD.csv`.
4. Displays confirmation toast with total record count.

---

## 6. Analytical Modals Specification

### 6.1 Bar Detail Modal (`#barDetailModal`)
- **Trigger**: User taps any individual day bar in the Weekly or Monthly Chart.js canvas.
- **Content**:
  - Title: *"Feed Detail — [Selected Date]"*.
  - Total feed broadcast on that day.
  - Granular meal-by-meal table: Time, Pond, Feed types mixed, Tray leftover score.
  - Weather summary for that date (if cached in `al_weather_history`).

### 6.2 Analytics Growth Point Modal (`#analyticsPointModal`)
- **Trigger**: User taps a sampling point on the growth curve.
- **Content**:
  - Title: *"Growth Detail — DOC [X]"*.
  - Sample total weight and sample count.
  - Calculated ABW in grams.
  - Growth gain since prior sampling ($\Delta\text{g}$).
  - Calculated Average Daily Growth ($ADG$ in g/day).

---

## 7. Google Stitch Re-Creation Recommendations

1. **Interactive Chart Tooltips**: Replace HTML canvas tooltips with custom HTML/Tailwind floating tooltip cards rendering meal icons and exact weights.
2. **Virtual Scrolling for History Ledger**: Use TanStack Virtual (`@tanstack/react-virtual`) to render thousands of historical feed records with 60fps scrolling performance and near-zero memory footprint.
3. **PDF Farm Report Generation**: Add a button `[ 📄 Export PDF Report ]` that uses `@react-pdf/renderer` to generate a branded 3-page monthly farm performance summary including charts, FCR milestones, and pond health rankings.
