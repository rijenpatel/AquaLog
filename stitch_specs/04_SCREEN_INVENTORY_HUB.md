# 04 — Screen Specification: Inventory Hub & Supplies Management

> **Screen ID**: `pageInventory`  
> **Route / Navigation**: Bottom Nav "Stock" (`data-tab="inventory"`) | Keyboard Shortcut `g` then `s`  
> **Target Component**: `<InventoryHubPage />`

---

## 1. Screen Objective & Mental Model

Aquaculture supply chains in rural coastal areas require vigilant stock management. Running out of feed during peak culture (DOC 60-90) forces emergency purchases at inflated spot prices or causes sudden feeding stops that trigger cannibalism.

The **Inventory Hub** organizes the farm’s physical supplies into three core operational pillars:
1. **Feed (Biomass Nutrition)**: Pelleted feeds categorized by size (Starter to Finisher).
2. **Medicines & Biosecurity**: Water conditioners, probiotics, minerals, disinfectants, and molting supplements.
3. **Fuel & Energy**: Diesel for generators and tractor pumps, petrol for aerator engines, and machinery lubricants.

This screen acts as the executive cockpit for inventory, tracking current stock levels, monthly burn rates vs purchases, low-stock thresholds, and impending medicine expirations, while serving as the gateway to granular detail ledgers.

---

## 2. Visual Hierarchy & Layout Structure

```
<InventoryHubPage>
  ├── <ScreenHeader>
  │     ├── <Title> ("📦 Inventory")
  │     └── <BilingualSubtitle> ("सामग्री प्रबंधन · Manage Farm Supplies")
  │
  ├── <ControlsRow>
  │     ├── <SiteSelectorCard> (Drop-down filter: All Sites vs Specific Farm Site)
  │     └── <InventoryReportsButton> (Direct CTA: "📊 Reports" ──> navigates to pageInventoryReports)
  │
  ├── <InventoryPillarsGrid> (Responsive 3-column card grid)
  │     │
  │     ├── <FeedPillarCard>
  │     │     ├── <Header> (🫧 "Feed" · <LowStockBadge id="feedLowStockCount" />)
  │     │     ├── <MetricsList>
  │     │     │     ├── <CurrentStockRow> (e.g. "4,250.0 kg")
  │     │     │     ├── <PurchasedMonthRow> (e.g. "6,000.0 kg")
  │     │     │     └── <ConsumedMonthRow> (e.g. "3,820.0 kg")
  │     │     ├── <StockLevelProgressBar> (Percentage bar against 30-day capacity)
  │     │     └── <CardActions>
  │     │           ├── <QuickAddBtn id="btnQuickAddFeed"> ──> opens <PurchaseFeedModal>
  │     │           └── <ViewDetailsBtn id="btnViewDetailsFeed"> ─> navigates to <pageFeedDetail>
  │     │
  │     ├── <MedicinePillarCard>
  │     │     ├── <Header> (💊 "Medicine & Consumables" · <LowStockBadge id="medLowStockCount" />)
  │     │     ├── <MetricsList>
  │     │     │     ├── <CurrentStockRow> (e.g. "145 units")
  │     │     │     └── <ExpiringSoonRow> (Amber count: "3 items expiring in <30 days")
  │     │     ├── <CategoryBreakdownBars> (Probiotics, Minerals, Lime, Disinfectants)
  │     │     └── <CardActions>
  │     │           ├── <QuickAddBtn id="btnQuickAddMedicine"> ──> opens <PurchaseMedicineModal>
  │     │           └── <ViewDetailsBtn id="btnViewDetailsMedicine"> ─> navigates to <pageMedicineDetail>
  │     │
  │     └── <FuelPillarCard>
  │           ├── <Header> (⛽ "Fuel & Energy")
  │           ├── <MetricsList>
  │           │     ├── <CurrentStockRow> (e.g. "850.0 L")
  │           │     ├── <PurchasedMonthRow> (e.g. "1,200.0 L")
  │           │     └── <ConsumedMonthRow> (e.g. "940.0 L")
  │           ├── <StockLevelProgressBar> (Visual fuel gauge)
  │           └── <CardActions>
  │                 ├── <QuickAddBtn id="btnQuickAddFuel"> ──> opens <PurchaseFuelModal>
  │                 └── <ViewDetailsBtn id="btnViewDetailsFuel"> ─> navigates to <pageFuelDetail>
  │
  └── <ModalsLayer>
        ├── <PurchaseFeedModal>
        ├── <PurchaseMedicineModal>
        ├── <PurchaseFuelModal>
        └── <EditThresholdModal>
```

---

## 3. UI Specifications & Styling Tokens

- **Controls Row**: Flex layout with high-contrast site selector (`#inventorySiteSelect`) and prominent Reports button with Tabler icon `ti-file-analytics`.
- **Pillar Cards Grid (`.inventory-grid`)**:
  - CSS Grid: `display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; padding: 0 16px`.
  - Card Surface: Deep navy glassmorphism (`background: var(--surface); border: 1px solid var(--border); border-radius: 18px; padding: 18px`).
- **Low Stock Badges (`.orange-badge`)**: High-visibility glowing amber pill (`background: rgba(251,191,36,0.15); color: var(--amber); border: 1px solid rgba(251,191,36,0.3); font-weight: 700; padding: 2px 8px; border-radius: 100px`).
- **Stock Progress Bar (`.db-progress-container`)**: $8\text{px}$ rounded track with gradient fill:
  - Green (`#10b981`) when stock $> 30\%$.
  - Amber (`#fbbf24`) when stock $15\% - 30\%$.
  - Rose Red (`#f43f5e`) when stock $< 15\%$ or below low threshold.

---

## 4. State Management & Data Flow

### 4.1 State Interface
```typescript
interface InventoryHubState {
  selectedSiteId: string;           // 'all' or specific FarmSite.id
  feedSummary: {
    currentStockKg: number;
    purchasedThisMonthKg: number;
    consumedThisMonthKg: number;
    lowStockCount: number;
  };
  medicineSummary: {
    currentStockUnits: number;
    expiringSoonCount: number;      // Expiry within 30 days
    lowStockCount: number;
    categoryCounts: Record<string, number>;
  };
  fuelSummary: {
    currentStockLiters: number;
    purchasedThisMonthLiters: number;
    consumedThisMonthLiters: number;
    lowStockCount: number;
  };
}
```

---

## 5. Micro-Level Business Logic & Mathematical Formulas

### 5.1 Monthly Purchase & Consumption Aggregations
For any category $C \in \{\text{'feed'}, \text{'medicine'}, \text{'fuel'}\}$ and month $M$ (current calendar month):

$$\text{PurchasedThisMonth} = \sum_{\substack{\text{tx} \in \text{Transactions} \\ \text{tx.type} = \text{'purchase'} \\ \text{item.category} = C \\ \text{tx.date} \in M}} \text{tx.quantity}$$

$$\text{ConsumedThisMonth} = \sum_{\substack{\text{tx} \in \text{Transactions} \\ \text{tx.type} = \text{'consumption'} \\ \text{item.category} = C \\ \text{tx.date} \in M}} |\text{tx.quantity}|$$

### 5.2 Low Stock Threshold Algorithm
1. Every inventory item carries a configurable `lowStockThreshold`.
   - Default thresholds: Feed $= 50\text{ kg}$ (or 2 bags); Medicine $= 5\text{ units}$; Fuel $= 20\text{ L}$.
2. Low stock condition:
   $$\text{isLowStock} = \text{item.currentStock} \le \text{item.lowStockThreshold}$$
3. Count of low-stock items updates the pill badge on the respective pillar card.

### 5.3 Medicine Expiry Intelligence Engine
1. For every medicine item in `al_inventory`:
   - Inspect `item.expiryDate` ("YYYY-MM-DD").
   - Calculate days until expiry:
     $$\text{DaysToExpiry} = \lfloor \frac{\text{expiryDate} - \text{Today}}{86,400,000} \rfloor$$
2. **Classification**:
   - $\text{DaysToExpiry} < 0$: `EXPIRED` (Red badge).
   - $0 \le \text{DaysToExpiry} \le 30$: `EXPIRING_SOON` (Amber badge). Increments `#medExpiringSoon`.
   - $\text{DaysToExpiry} > 30$: `GOOD` (Subtle grey).

### 5.4 Automatic Finance Integration (Cross-Module Sync)
Whenever a purchase is recorded via `#purchaseFeedModal`, `#purchaseMedicineModal`, or `#purchaseFuelModal`:
1. Save transaction in `al_inventory`.
2. Update item stock: `item.currentStock += quantity`.
3. **Automatically generate an Expense in Finance (`al_finance_expenses`)**:
   ```typescript
   const expense: FinanceExpense = {
     id: genId('exp'),
     date: purchaseDate,
     category: category, // 'feed' | 'medicine' | 'fuel'
     amount: totalCost,
     description: `Inventory Purchase: ${itemName} (${quantity} ${unit} @ ₹${costPerUnit}/${unit})`,
     siteId: siteId,
     inventoryTxId: tx.id,
     createdAt: new Date().toISOString()
   };
   window.AppStorage.addFinanceExpense(expense);
   ```
4. This ensures that farm expenses are never double-entered or forgotten.

---

## 6. Detailed Modals Specifications

### 6.1 Purchase Feed Modal (`#purchaseFeedModal`)
- **Fields**:
  - Farm Site: Dropdown.
  - Feed Brand: Dropdown or text (CP, Avanti, Grobest, Waterbase, Nexus, Cargill).
  - Pellet Size: Dropdown (Starter 0.8mm, Grower 1.2mm, Grower 1.6mm, Finisher 2.0mm, Finisher 2.5mm).
  - Quantity of Bags: Numerical input (e.g. `40`).
  - Bag Weight (kg): Defaults to $25\text{ kg}$.
  - Total Net Weight: Auto-calculated $\text{Total Kg} = \text{Bags} \times \text{BagWeight}$ (e.g. $1,000\text{ kg}$).
  - Cost per Bag (₹): e.g. ₹$2,150$.
  - Total Cost (₹): Auto-calculated $\text{Bags} \times \text{CostPerBag}$ (e.g. ₹$86,000$).
  - Supplier / Dealer: e.g. "Coastal Feeds Agency".
  - Batch / Lot Number: For traceability.
  - Expiry Date: Calendar date.
- **On Save**: Creates or updates feed item, records inward transaction, adds finance expense, refreshes UI.

### 6.2 Purchase Medicine Modal (`#purchaseMedicineModal`)
- **Fields**:
  - Category: Probiotics, Minerals, Lime, Disinfectants, Salt, Molasses, Zeolite, Vitamins, Water Treatment.
  - Product Name: e.g. "Vannamin Micro-Minerals", "PondCare Gut Probiotic".
  - Quantity & Unit: e.g. `20` `kg` (or `bottles`, `packs`, `liters`).
  - Unit Cost (₹): Cost per package/unit.
  - Total Cost (₹): Auto-calculated.
  - Expiry Date: Date input (critical for biologicals/probiotics).
  - Supplier: e.g. "AquaVet Pharma".

### 6.3 Purchase Fuel Modal (`#purchaseFuelModal`)
- **Fields**:
  - Fuel Type: Diesel, Petrol, Engine Oil.
  - Quantity (Liters): e.g. `200`.
  - Price per Liter (₹): e.g. `94.50`.
  - Total Cost (₹): Auto-calculated (e.g. ₹`18,900`).
  - Vendor / Filling Station: e.g. "HPCL Pump Outlet".

### 6.4 Edit Threshold Modal (`#editThresholdModal`)
- Allows the farm manager to customize low-stock trigger points per item.
- Displays item name, current threshold, and unit.
- Inputs new numerical threshold (e.g. raise Grower 1.6mm threshold from 50kg to 250kg during peak DOC).

---

## 7. Google Stitch Re-Creation Recommendations

1. **Category Filter Tabs**: Add a segmented chip bar above the cards (`[ All ] [ Feeds ] [ Medicines ] [ Fuel ]`) for quick filtering on mobile.
2. **Animated Bar Fillers**: Use Framer Motion to animate progress bars on first render (`initial={{ width: 0 }} animate={{ width: percentage }}`).
3. **Visual Reorder Alert**: When an item breaches its threshold, pulse the card icon with a subtle amber glow animation.
