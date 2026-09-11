# 06 — Screen Specification: Medicine & Chemical Detail

> **Screen ID**: `pageMedicineDetail`  
> **Route / Navigation**: `pageInventory` ──> tap "View Details" on Medicine Card (`#btnViewDetailsMedicine`)  
> **Target Component**: `<MedicineDetailPage />`

---

## 1. Screen Objective & Mental Model

Aquaculture ponds are sensitive biological bioreactors. Managing water parameters and shrimp gut health requires timely application of specialized chemical, mineral, and biological compounds:
- **Probiotics (Microbial Consortia)**: Bacillus, Lactobacillus, Nitrosomonas to digest sludge and control ammonia.
- **Minerals & Salts**: Maintaining critical ionic ratios ($Ca:Mg:K \approx 1:3:1$) essential for regular exoskeleton molting.
- **Water Treatment / Liming**: Agricultural Lime ($\text{CaCO}_3$), Dolomite ($\text{CaMg(CO}_3)_2$), Zeolite to maintain alkalinity ($> 120\text{ ppm}$) and pH stability ($7.5 - 8.5$).
- **Disinfectants / Biosecurity**: BKC (Benzalkonium Chloride), Povidone-Iodine, Chlorine applied during pond prep or disease outbreaks.

The **Medicine & Chemical Detail Screen** manages inventory, tracks critical product expiry (biological probiotics have short shelf-lives), and features a built-in **Pond Volume Dosage Calculator** that converts treatment rates ($\text{ppm}$ or $\text{kg/ha}$) into exact kilograms or liters required for a specific pond.

---

## 2. Visual Hierarchy & Screen Structure

```
<MedicineDetailPage>
  ├── <DetailHeaderBar>
  │     ├── <BackButton id="btnBackMedicineDetail"> ("←" ──> returns to pageInventory)
  │     └── <TitleBlock>
  │           ├── <Title> ("Medicine & Consumables")
  │           └── <Subtitle id="medDetailSiteName"> ("Site 1 - Coastal Farm")
  │
  ├── <SiteSelectorCard> (Drop-down selector for site-scoped inventory)
  │
  ├── <SummaryKpiBar>
  │     ├── <KpiItem> (Total SKUs: "18 items")
  │     ├── <KpiItem> (Expiring Soon: "3 items" [Amber])
  │     ├── <KpiItem> (Low Stock: "2 items" [Amber])
  │     └── <KpiItem> (Out of Stock: "1 item" [Red])
  │
  ├── <SearchAndFilterCard>
  │     ├── <SearchInput id="medSearchInput"> ("Search medicine, category, supplier...")
  │     ├── <DateRangeGroup> (From [ Date ] · To [ Date ])
  │     ├── <FilterPillsGroup>
  │     │     ├── <LowStockToggle id="medFilterLowOnly"> ("Low Stock")
  │     │     ├── <OutOfStockToggle id="medFilterOutOnly"> ("Out of Stock")
  │     │     └── <ExpiringToggle id="medFilterExpiringOnly"> ("Expiring Soon (<30d)")
  │     └── <ClearFiltersButton id="btnClearMedFilters"> ("Clear Filters")
  │
  └── <MedicineItemsListSection id="medDetailItemsList">
        └── <MedicineItemCard> (Repeated per product)
              ├── <CardHeader>
              │     ├── <CategoryBadge> ("Probiotics" | "Minerals" | "Lime" | "Disinfectants")
              │     ├── <ProductNameAndBrand> ("BioGut Probiotic · AquaVet Labs")
              │     └── <ExpiryStatusBadge> ("⏳ Expires in 14 days" [Amber] | "Expired" [Red])
              ├── <StockMetricsRow>
              │     ├── <CurrentStock> ("18.5 kg")
              │     ├── <Threshold> ("Min Threshold: 5.0 kg")
              │     └── <Valuation> ("Value: ₹22,200")
              ├── <PondDosageCalculatorDrawer> (Collapsible Dosage Tool)
              │     ├── <PondSelector> (Select target pond: auto-fetches Area & Depth)
              │     ├── <DosageRateInput> (Enter recommended rate in ppm or kg/hectare)
              │     └── <CalculatedDoseBadge> ("Required Dose: 4.5 kg for Pond 1")
              └── <CardActionButtons>
                    ├── <LogApplicationBtn> ──> opens <LogTreatmentModal> (deducts stock)
                    ├── <AddPurchaseBtn> ────> opens <PurchaseMedicineModal(prefilled)>
                    ├── <EditThresholdBtn> ──> opens <EditThresholdModal>
                    └── <LedgerHistoryBtn> ──> opens <MedicineLedgerSheet>
```

---

## 3. Product Categories & Biological Classification

| Category | Primary Function | Typical Products | Standard Packaging / Unit | Expiry Sensitivity |
| :--- | :--- | :--- | :--- | :--- |
| **Probiotics** | Gut health & pond sludge digestion | *Bacillus subtilis*, *Lactobacillus*, Soil Probiotics | $1\text{ kg}$ foil packs, $1\text{ L}$ liquid bottles | **Extremely High** (Live microbes lose viability after 6-12 months) |
| **Minerals** | Molt support & ionic balance | Magnesium Chloride, Potassium Chloride, $\text{CaSO}_4$ | $25\text{ kg}$ / $50\text{ kg}$ sacks | Low (Stable salts; hygroscopic moisture risk) |
| **Lime / Dolomite** | pH buffer & alkalinity booster | Agricultural Lime, Dolomite, Quicklime ($\text{CaO}$) | $50\text{ kg}$ heavy bags | Very Low (Inert minerals) |
| **Disinfectants** | Biosecurity & pathogen knockdown | BKC $50\%$, Povidone Iodine, Bleaching powder | $5\text{ L}$ / $20\text{ L}$ carboys, $25\text{ kg}$ drums | Moderate (Volatile chlorine loss) |
| **Vitamins & Nutrients** | Stress reduction & shell hardening | Vitamin C coated, Beta-glucan immune stimulants | $500\text{ g}$ / $1\text{ kg}$ jars | High (Oxidation risk if unsealed) |
| **Water Treatment** | Toxin adsorption & flocculation | Zeolite powder, Yucca schidigera (ammonia binder) | $20\text{ kg}$ bags, $1\text{ L}$ bottles | Low |

---

## 4. Mathematical Models & The Dosage Calculator

Pond managers often struggle to translate chemical instructions (e.g. *"Apply 2.5 ppm to water body"*) into physical product weights. The built-in Dosage Engine eliminates human calculation error:

### 4.1 Water Volume Calculation
$$\text{Pond Area } (m^2) = \text{pond.areaSqMeters}$$
$$\text{Water Depth } (m) = \text{pond.waterDepthMeters}$$
$$\text{Water Volume } (m^3) = \text{Area } (m^2) \times \text{Depth } (m)$$
*Example: Pond 1 ($4,000\text{ m}^2$) at $1.5\text{ m}$ depth:*
$$\text{Volume} = 4,000 \times 1.5 = 6,000\text{ m}^3 = 6,000,000\text{ Liters}$$

### 4.2 Chemical Requirement Calculation (from PPM)
Since $1\text{ ppm} = 1\text{ g/m}^3 = 1\text{ mg/L}$:
$$\text{Required Product (kg)} = \frac{\text{Volume } (m^3) \times \text{Dosage Rate } (\text{ppm})}{1,000}$$
*Example: Recommended treatment of BKC at $2.0\text{ ppm}$ in Pond 1:*
$$\text{Required BKC} = \frac{6,000\text{ m}^3 \times 2.0\text{ ppm}}{1,000} = 12.0\text{ kg (or Liters)}$$

### 4.3 Chemical Requirement Calculation (from Area Rate e.g. kg / Hectare)
$$\text{Pond Area in Hectares} = \frac{\text{Area } (m^2)}{10,000}$$
$$\text{Required Product (kg)} = \text{Area (ha)} \times \text{Rate (kg/ha)}$$
*Example: Dolomite application at $150\text{ kg/ha}$ for a $0.4\text{ ha}$ pond:*
$$\text{Required Dolomite} = 0.4 \times 150 = 60.0\text{ kg}$$

---

## 5. Expiry Date Intelligence & Countdown Engine

For every medicine record:
$$\text{DaysToExpiry} = \lfloor \frac{\text{item.expiryDate} - \text{Today}}{86,400,000} \rfloor$$

- **State 1: Expired ($\text{DaysToExpiry} < 0$)**
  - Card Border turns Rose Red (`#f43f5e`).
  - Badge: `🔴 EXPIRED [X] days ago`.
  - Alert: *"Do not apply expired biologicals to active shrimp ponds."*
- **State 2: Expiring Soon ($0 \le \text{DaysToExpiry} \le 30$)**
  - Card Border turns Amber Gold (`#fbbf24`).
  - Badge: `⚠️ Expires in [X] days`.
  - Recommendation: *"Prioritize using this lot before opening fresh packages."*
- **State 3: Fresh / Good ($\text{DaysToExpiry} > 30$)**
  - Subtle slate badge with expiry date.

---

## 6. Treatment Logging & Stock Deductions (`LogTreatmentModal`)

When a chemical or probiotic treatment is applied to a pond:
1. User clicks `[ Log Application ]` on the product card.
2. Select target Pond & Active Batch.
3. Quantity applied (pre-filled from the Dosage Calculator if used).
4. Treatment Reason: Dropdown (*Routine Water Prep, High Ammonia Spike, Molting Failure, Vibrio Control, Black Gill, Turbid Water*).
5. On Submit:
   - Decrements `item.currentStock -= quantity`.
   - Records an outward transaction of type `'consumption'`.
   - Adds note to pond's activity feed.

---

## 7. Google Stitch Re-Creation Recommendations

1. **Interactive Slider for Dosage Calculator**: Allow farmers to drag a slider for depth ($1.0\text{m}$ to $2.0\text{m}$) and immediately watch the required kg amount adjust in real time.
2. **Color-Coded Category Badges**: Distinct visual identities for Probiotics (Purple), Minerals (Teal), Disinfectants (Rose), and Lime (Amber).
3. **Safety Warning Callouts**: Display chemical handling guidelines (e.g. *"⚠️ Apply BKC only during sunny daytime with mechanical aerators running"*).
