# 07 — Screen Specification: Fuel & Energy Detail

> **Screen ID**: `pageFuelDetail`  
> **Route / Navigation**: `pageInventory` ──> tap "View Details" on Fuel Card (`#btnViewDetailsFuel`)  
> **Target Component**: `<FuelDetailPage />`

---

## 1. Screen Objective & Mental Model

Aeration and pumping are the mechanical lungs of an aquaculture farm. In intensive shrimp farming, failure of aeration for as little as $30 \text{ to } 45 \text{ minutes}$ during a midnight dissolved oxygen (DO) dip can result in $100\%$ crop mortality ("oxygen crash").

Because coastal power grids suffer frequent blackouts, farms rely heavily on backup diesel generator sets (DG sets), tractor-driven pump engines, and portable gasoline aerators. Energy (electricity + diesel) constitutes $12\% \text{ to } 20\%$ of total crop operating expenses.

The **Fuel & Energy Detail Screen** tracks:
1. **Bulk Fuel Reserves**: Diesel, Petrol, and 2-Stroke / 4-Stroke Engine Oils.
2. **Machinery Run-Hours**: Generator and pump runtime logs.
3. **Burn Rate & Efficiency**: Liters per run-hour ($L/\text{hr}$).
4. **Energy Cost Allocation**: Distributing total farm electricity and fuel bills across individual ponds based on aerator horsepower-hours.

---

## 2. Visual Hierarchy & Screen Structure

```
<FuelDetailPage>
  ├── <DetailHeaderBar>
  │     ├── <BackButton id="btnBackFuelDetail"> ("←" ──> returns to pageInventory)
  │     └── <TitleBlock>
  │           ├── <Title> ("Fuel Inventory")
  │           └── <Subtitle id="fuelDetailSiteName"> ("Site 1 - Coastal Farm")
  │
  ├── <SiteSelectorCard> (Drop-down selector for site-scoped fuel reserves)
  │
  ├── <SummaryKpiBar>
  │     ├── <KpiItem> (Total Fuel: "850.0 L")
  │     ├── <KpiItem> (Fuel Types: "3 types")
  │     ├── <KpiItem> (Low Stock: "1 item" [Amber])
  │     └── <KpiItem> (Out of Stock: "0 items" [Red])
  │
  ├── <SearchAndFilterCard>
  │     ├── <SearchInput id="fuelSearchInput"> ("Search fuel type, supplier...")
  │     ├── <DateRangeGroup> (From [ Date ] · To [ Date ])
  │     ├── <FilterPillsGroup>
  │     │     ├── <LowStockToggle id="fuelFilterLowOnly"> ("Low Stock")
  │     │     └── <OutOfStockToggle id="fuelFilterOutOnly"> ("Out of Stock")
  │     └── <ClearFiltersButton id="btnClearFuelFilters"> ("Clear Filters")
  │
  └── <FuelSuppliesListSection id="fuelDetailItemsList">
        └── <FuelItemCard> (Repeated per fuel SKU)
              ├── <CardHeader>
              │     ├── <FuelTypeBadge> (⛽ "Diesel" | "Petrol" | "Engine Oil")
              │     ├── <SupplierAndVendor> ("HPCL Pump Outlet · Main Road")
              │     └── <StockStatusPill> ("Normal Reserve" | "Low Fuel Alert")
              ├── <StockMetricsRow>
              │     ├── <CurrentStockLiters> ("650.0 L")
              │     ├── <Threshold> ("Min Reserve: 150.0 L")
              │     └── <StockValuation> ("Value: ₹61,425")
              ├── <MachineryRuntimeSection> (Generator & Pump Log)
              │     ├── <ActiveMachinesRow> ("DG Set 1 (62.5 kVA) · Tractor Pump A")
              │     ├── <EfficiencyRateMetric> ("Efficiency: ~7.5 L / hr")
              │     └── <EstimatedHoursRemaining> ("⏳ ~86 hours of continuous backup runtime")
              └── <CardActionButtons>
                    ├── <LogRuntimeBtn> ────> opens <LogMachineRuntimeModal> (deducts fuel)
                    ├── <AddPurchaseBtn> ───> opens <PurchaseFuelModal(prefilled)>
                    ├── <EditThresholdBtn> ─> opens <EditThresholdModal>
                    └── <LedgerHistoryBtn> ─> opens <FuelLedgerSheet>
```

---

## 3. Fuel Types & Machinery Mapping

| Fuel Item | Equipment Used In | Typical Farm Storage | Refill Trigger / Threshold |
| :--- | :--- | :--- | :--- |
| **Diesel (HSD)** | Heavy DG generators (30 kVA – 125 kVA), Tractor PTO water pump engines | $500\text{L} - 2,000\text{L}$ on-site tank drums | $150\text{ L}$ (guarantees at least 20 hours emergency runtime) |
| **Petrol (Gasoline)**| Portable floating splash aerators, 4-stroke handheld pumps | $20\text{L} - 50\text{L}$ safety jerrycans | $10\text{ L}$ |
| **Engine Lubricant (15W-40)** | Generator oil changes, tractor sump maintenance | $5\text{L} - 20\text{L}$ sealed buckets | $5\text{ L}$ |
| **Grease / Gear Oil (EP-90)** | Aerator bevel gearboxes and pedestal bearings | $5\text{ kg}$ tubs | $2\text{ kg}$ |

---

## 4. Mathematical Models & Efficiency Calculations

### 4.1 Engine Runtime Fuel Deduction
When farm staff log machinery runtime:
1. **Inputs**:
   - `startHourMeter`: e.g. $1,420.5\text{ hrs}$
   - `endHourMeter`: e.g. $1,428.5\text{ hrs}$
   - `hoursRun`: $\Delta\text{Hours} = 1,428.5 - 1,420.5 = 8.0\text{ hours}$
   - `fuelConsumptionRate`: e.g. $7.5\text{ L/hr}$ (based on generator load)
2. **Calculated Fuel Consumed**:
   $$\text{FuelConsumed (Liters)} = \text{hoursRun} \times \text{fuelConsumptionRate} = 8.0 \times 7.5 = 60.0\text{ Liters}$$
3. On Submit:
   - Decrements `dieselItem.currentStock -= 60.0`.
   - Records transaction of type `'consumption'` in `al_inventory`.
   - Automatically logs machine expense in Finance!

### 4.2 Backup Hours Remaining Forecast
$$\text{Backup Hours Remaining} = \lfloor \frac{\text{Current Diesel Stock (L)}}{\text{Average Generator Burn Rate (L/hr)}} \rfloor$$
*Example: $650.0\text{ L}$ diesel in stock, DG set burns $7.5\text{ L/hr}$:*
$$\text{Hours Remaining} = \lfloor \frac{650}{7.5} \rfloor = 86\text{ hours}$$
UI Badge: *"⏳ ~86 hours of continuous backup runtime available"*.
- **Alert Trigger**: If $\text{Backup Hours} < 24\text{ hours}$, turns glowing Amber with warning: *"Low Fuel: Order diesel delivery before weekend power cuts."*

### 4.3 Energy Cost Allocation Across Active Ponds
Total monthly electricity and diesel costs are apportioned across ponds proportional to each pond's aerator capacity:
$$\text{Pond Aerator HP} = \text{pond.totalAeratorHp}$$
$$\text{Total Farm Aerator HP} = \sum_{\text{active ponds}} \text{pond.totalAeratorHp}$$
$$\text{Pond Energy Cost (₹)} = \text{Total Farm Energy Expense} \times \left( \frac{\text{Pond Aerator HP}}{\text{Total Farm Aerator HP}} \right)$$

*Example: Farm electricity + diesel bill is ₹$120,000$. Total farm aerator capacity across 4 ponds is $60\text{ HP}$. Pond 1 has $20\text{ HP}$ aerators:*
$$\text{Pond 1 Energy Cost} = 120,000 \times \left( \frac{20}{60} \right) = ₹40,000$$

---

## 5. User Workflows & Modal Specifications

### 5.1 Log Engine Runtime Modal (`LogMachineRuntimeModal`)
- **Fields**:
  - Machine Dropdown: "DG Set 1 (62.5 kVA)", "DG Set 2 (30 kVA)", "Tractor Pump A".
  - Date & Time: Operation timestamp.
  - Runtime Mode:
    - Option A: Enter Start and End hour-meter reading (auto-calculates hours).
    - Option B: Enter total elapsed hours directly.
  - Reason for Run: "Grid Power Outage", "Pre-dawn DO boost", "Pond Water Exchange".
  - Auto-Deduct Checkbox: Checked by default. Automatically deducts calculated liters from fuel inventory.

### 5.2 Purchase Fuel Modal (`purchaseFuelModal`)
- Pre-filled for rapid entry from the Fuel Detail screen.
- Fields: Fuel Type, Quantity (L), Price/L, Vendor, Date.
- Automatically generates an expense record in `al_finance_expenses` under category `fuel`.

---

## 6. Google Stitch Re-Creation Recommendations

1. **Circular Tank Gauge UI**: Design an animated SVG fuel tank level gauge displaying liquid fill level with waving surface effect.
2. **One-Tap Quick Log**: Add a quick-log button on the card: `[ +20L Daily Top-Up ]` for routine morning diesel refills.
3. **Power Outage Tracker**: Correlate generator run-hours with local grid outage history to provide monthly power reliability metrics.
