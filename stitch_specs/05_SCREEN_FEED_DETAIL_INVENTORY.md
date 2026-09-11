# 05 — Screen Specification: Feed Stock Detail & Lot Tracking

> **Screen ID**: `pageFeedDetail`  
> **Route / Navigation**: `pageInventory` ──> tap "View Details" on Feed Card (`#btnViewDetailsFeed`)  
> **Target Component**: `<FeedDetailPage />`

---

## 1. Screen Objective & Mental Model

In shrimp aquaculture, feed is not a single uniform commodity; it is a size-graded progression tailored to mouth-part morphology:
- **Crumbles / Starter (0.5mm – 1.0mm)**: DOC 1 to 25. High protein ($38\% - 42\%$).
- **Grower 1 (1.2mm)**: DOC 26 to 45. Fast juvenile growth.
- **Grower 2 (1.6mm)**: DOC 46 to 75. Peak daily volume consumption.
- **Finisher 1 (2.0mm)**: DOC 76 to 105. High biomass maintenance.
- **Finisher 2 (2.5mm)**: DOC 106 to harvest. Maximum pellet stability in water.

The **Feed Detail Screen** gives the farm manager granular, SKU-by-SKU inventory visibility. It answers:
- *How many bags of Grower 1.6mm remain in the store room?*
- *At current daily feeding rates, on which exact calendar date will Grower 1.2mm run out?*
- *Which feed supplier delivered Lot #4892, and what was the cost per bag?*
- *Has any feed bag suffered moisture spoilage or bag tear requiring a manual inventory adjustment?*

---

## 2. Visual Hierarchy & Screen Structure

```
<FeedDetailPage>
  ├── <DetailHeaderBar>
  │     ├── <BackButton id="btnBackFeedDetail"> ("←" ──> navigates back to pageInventory)
  │     └── <TitleBlock>
  │           ├── <Title> ("Feed Inventory")
  │           └── <Subtitle id="feedDetailSiteName"> ("Site 1 - Coastal Ponds")
  │
  ├── <SiteSelectorCard> (Drop-down selector for multi-site filtering)
  │
  ├── <SummaryKpiBar>
  │     ├── <KpiItem> (Total Stock: "4,250.0 kg")
  │     ├── <KpiItem> (Feed SKUs: "6 items")
  │     ├── <KpiItem> (Low Stock: "1 item" [Amber])
  │     └── <KpiItem> (Out of Stock: "0 items" [Red])
  │
  ├── <SearchAndFilterCard>
  │     ├── <SearchInput id="feedSearchInput"> ("Search brand, size, supplier...")
  │     ├── <DateRangeGroup> (From: [ Date ] · To: [ Date ])
  │     ├── <TogglePillsGroup>
  │     │     ├── <LowStockToggle id="feedFilterLowOnly"> ("Low Stock")
  │     │     └── <OutOfStockToggle id="feedFilterOutOnly"> ("Out of Stock")
  │     └── <ClearFiltersButton id="btnClearFeedFilters"> ("Clear Filters")
  │
  └── <FeedItemsListSection id="feedDetailItemsList">
        └── <FeedItemCard> (Repeated per SKU)
              ├── <ItemHeader>
              │     ├── <PelletSizeBadge> ("Grower 1.6mm")
              │     ├── <BrandAndSupplier> ("CP Classic · Coastal Feeds")
              │     └── <StockStatusPill> ("In Stock" | "Low Stock" | "Depleted")
              ├── <StockMetricsRow>
              │     ├── <TotalKgMetric> ("2,450.0 kg")
              │     ├── <BagsCountMetric> ("98 bags @ 25kg")
              │     └── <CostValueMetric> ("Value: ₹2,10,700")
              ├── <BurnRateAndDepletionForecast>
              │     ├── <DailyBurnRate> ("Consuming ~85 kg/day across 3 ponds")
              │     └── <DepletionDaysBadge> ("⏳ 28 days of feed remaining (Depletes Oct 4)")
              └── <ItemActionButtons>
                    ├── <AddPurchaseBtn> ──> opens <PurchaseFeedModal(prefilled)>
                    ├── <StockAdjustBtn> ──> opens <AdjustStockModal>
                    ├── <SetThresholdBtn> ─> opens <EditThresholdModal>
                    └── <LedgerHistoryBtn> ─> opens <TransactionLedgerSheet>
```

---

## 3. UI Specifications & Styling Tokens

- **Summary KPI Bar (`.detail-summary-bar`)**:
  - CSS Grid: `display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin: 10px 16px 14px`.
  - Surface: `background: rgba(255,255,255,0.03); border: 1px solid var(--border); border-radius: 14px; padding: 12px`.
  - KPI Values: Font-family `'Outfit'`, font-weight 700, font-size $1.2\text{rem}$, color `--teal: #00e5f5`.
- **Feed Item Cards**:
  - Elevated glass container (`background: var(--surface); border: 1px solid var(--border); border-radius: 16px; padding: 16px; margin: 0 16px 12px`).
  - Size Badge: Color-coded using the feed palette:
    - Starter 0.8mm: `--fs1: #38bdf8` (Sky Blue)
    - Grower 1.2mm: `--fs2: #00c6d4` (Teal Cyan)
    - Grower 1.6mm: `--fs3: #10b981` (Emerald)
    - Finisher 2.0mm: `--fs4: #f59e0b` (Amber)
    - Finisher 2.5mm: `--fs5: #a78bfa` (Purple)

---

## 4. State Management & Filtering Rules

### 4.1 State Interface
```typescript
interface FeedDetailState {
  siteId: string;                   // 'all' or FarmSite.id
  searchQuery: string;              // text query matching brand, size, supplier
  dateFrom?: string;                // "YYYY-MM-DD"
  dateTo?: string;                  // "YYYY-MM-DD"
  filterLowStockOnly: boolean;
  filterOutOfStockOnly: boolean;
  selectedItemId: string | null;    // For modal actions
}
```

### 4.2 Multi-Predicate Filter Logic
An item `item` is visible in `#feedDetailItemsList` if and only if all predicates pass:
1. **Site Match**: `siteId === 'all' || item.siteId === siteId`
2. **Category Match**: `item.category === 'feed'`
3. **Search Query Match**:
   $$\text{query} = \text{searchQuery.toLowerCase()}$$
   $$\text{item.name.toLowerCase().includes(query)} \lor \text{item.brand.toLowerCase().includes(query)} \lor \text{item.supplier.toLowerCase().includes(query)}$$
4. **Low Stock Toggle**: If `filterLowStockOnly === true`, requires `item.currentStock <= item.lowStockThreshold && item.currentStock > 0`.
5. **Out of Stock Toggle**: If `filterOutOfStockOnly === true`, requires `item.currentStock <= 0`.

---

## 5. Mathematical Models & Forecasting Algorithms

### 5.1 Bag Count Derivation
Feed is sold in commercial $25\text{ kg}$ multi-wall paper bags with plastic liners:
$$\text{Bags in Stock} = \frac{\text{item.currentStock}}{\text{item.bagWeightKg}}$$
- If $\text{item.currentStock} = 2,450\text{ kg}$ and bag weight $= 25\text{ kg}$:
  $$\text{Bags} = \frac{2,450}{25} = 98\text{ full bags}$$

### 5.2 Daily Burn Rate Calculation
Calculates the 7-day rolling average consumption for this specific feed SKU across all ponds:
$$\text{DailyBurnRate (kg/day)} = \frac{\sum_{\substack{\text{rec} \in \text{Records (last 7 days)} \\ \text{feedType} = \text{item.pelletSize}}} \text{rec.feedQuantity (kg)}}{7}$$
*Example: Total Grower 1.6mm consumed over the last 7 days is $595\text{ kg}$:*
$$\text{DailyBurnRate} = \frac{595}{7} = 85.0\text{ kg / day}$$

### 5.3 Depletion Date Forecast
$$\text{Days of Feed Remaining} = \lfloor \frac{\text{item.currentStock}}{\text{DailyBurnRate}} \rfloor$$
$$\text{Projected Depletion Date} = \text{Current Date} + \text{Days of Feed Remaining}$$
- *Example: Current stock $2,450\text{ kg}$, burn rate $85.0\text{ kg/day}$:*
  $$\text{Days Remaining} = \lfloor \frac{2,450}{85} \rfloor = 28\text{ days}$$
  UI badge renders: *"⏳ 28 days of feed remaining (Depletes Oct 4)"*.
- **Urgent Reorder Threshold**: If $\text{Days Remaining} \le 7$, badge turns glowing Amber. If $\le 3$, badge turns Crimson Rose with alert: *"REORDER NOW: Stock depleting in 3 days!"*

### 5.4 Total Feed Valuation
$$\text{Valuation (₹)} = \text{item.currentStock} \times \left( \frac{\text{Cost per Bag}}{\text{Bag Weight}} \right)$$

---

## 6. Action Workflows & Ledger Tracking

### 6.1 Manual Stock Adjustment Workflow (`AdjustStockModal`)
Shrimp feed in outdoor farm store-rooms can suffer damage:
- Spoilage from roof leaks or rain humidity.
- Bag tearing from handling or rodents.
- Reconciliation count discrepancy at end of month.

**Inputs**:
- Adjustment Type: `'damage'` | `'spoilage'` | `'recount'` | `'theft'`.
- Delta Quantity in kg (e.g. $-50\text{ kg}$).
- Notes / Justification: e.g. *"2 bags waterlogged due to heavy cyclone rain"*.
- On Confirm: Creates an adjustment transaction in `al_inventory`, decrements stock, logs non-cash inventory loss.

### 6.2 Transaction Ledger Sheet
Displays complete inward/outward history for the SKU:
| Date | Type | Reference | Delta (kg) | Balance (kg) | User / Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-09-06 | Consumption | Pond 1 · 7 AM | -5.0 kg | 2,450.0 kg | Auto-deduct |
| 2026-09-05 | Consumption | Pond 2 · 4 PM | -7.5 kg | 2,455.0 kg | Auto-deduct |
| 2026-09-01 | Purchase | Inv #4892 | +1,000.0 kg | 2,520.0 kg | Coastal Feeds |

---

## 7. Google Stitch Re-Creation Recommendations

1. **Visual Pellet Scale Indicator**: Render a small circular cross-section SVG next to the pellet name indicating relative diameter ($0.8\text{mm}$ tiny dot vs $2.5\text{mm}$ large dot).
2. **Reorder Drawer**: Direct one-tap button: `[ Reorder 40 Bags ]` that opens an automated purchase modal pre-filled with the vendor and typical lot size.
3. **Export CSV Button**: Include a quick export of the SKU’s inward/outward ledger for farm auditor review.
