# 09 — Screen Specification: Finance, Cost & Profitability

> **Screen ID**: `pageFinance`  
> **Route / Navigation**: Bottom Nav "Finance" (`data-tab="finance"`) | Keyboard Shortcut `g` then `f`  
> **Target Component**: `<FinancePage />`

---

## 1. Screen Objective & Mental Model

Aquaculture is a high-capital, high-risk, high-reward agribusiness. A commercial shrimp farm may invest ₹15 to ₹25 Lakhs per hectare per crop cycle. Profitability hinges on three interrelated variables:
1. **Input Cost Control**: Minimizing Feed Conversion Ratio (FCR), energy burn, and chemical wastage.
2. **Biomass Maximization**: Maintaining high survival ($> 85\%$) and rapid growth ($ADG > 0.25\text{g/day}$).
3. **Mandi Market Timing**: Timing harvest to align with peak export prices for specific count sizes (e.g. harvesting at 30 count vs 40 count).

The **Finance Screen** is the chief financial dashboard of the farm. It aggregates all costs (automated inventory purchases + manual overheads), tracks harvest sales revenue, displays real-time Mandi market price trends, and provides interactive break-even calculators and crop profit projections.

---

## 2. Visual Hierarchy & Screen Structure

```
<FinancePage>
  ├── <ScreenHeroHeader> ("💰 Finance" · "लाभ और लागत · Profit & Cost Tracking")
  │
  ├── <FinanceTabBar id="financeTabs">
  │     ├── <TabBtn data-tab="overview"> ("Overview") [Active]
  │     ├── <TabBtn data-tab="expenses"> ("Expenses")
  │     ├── <TabBtn data-tab="revenue"> ("Revenue")
  │     └── <TabBtn data-tab="prices"> ("Market Prices")
  │
  ├── [TAB 1: OVERVIEW id="financeOverviewTab"]
  │     ├── <FinancialKpiGrid>
  │     │     ├── <KpiCard NetProfit> (Net Profit/Loss: "₹4,12,000" · Margin: "31.2%")
  │     │     ├── <KpiCard TotalRevenue> (Realized + Projected: "₹13,20,000")
  │     │     └── <KpiCard TotalCosts> (Total Incurred: "₹9,08,000")
  │     ├── <CostBreakdownChartCard> (Donut / horizontal stacked bar of 10 expense categories)
  │     ├── <BreakEvenCalculatorCard> (Break-even price benchmark ₹/kg vs current market price)
  │     ├── <BatchProfitabilityCardsGrid> (Per-crop P&L summary cards for active & past batches)
  │     └── <MarketPriceTickerBanner> (Live shrimp prices by count: 30c, 40c, 60c, 100c)
  │
  ├── [TAB 2: EXPENSES id="financeExpensesTab"]
  │     ├── <ExpensesHeaderRow>
  │     │     ├── <SectionTitle> ("Expense Ledger")
  │     │     └── <AddExpenseBtn> ("＋ Add Expense" ──> opens <AddExpenseModal>)
  │     ├── <ExpenseFilterBar> (Category filter, Batch filter, Date filter)
  │     └── <ExpensesListTable> (Date, Category, Batch, Description, Amount ₹, Action)
  │
  ├── [TAB 3: REVENUE id="financeRevenueTab"]
  │     ├── <RevenueHeaderRow>
  │     │     ├── <SectionTitle> ("Harvest Sales & Revenue")
  │     │     └── <RecordSaleBtn> ("＋ Record Sale" ──> opens <AddRevenueModal>)
  │     └── <RevenueSalesTable> (Date, Batch, Harvest Kg, Price/kg ₹, Total ₹, Buyer, Status)
  │
  └── [TAB 4: MARKET PRICES id="financePricesTab"]
        ├── <PricesHeaderRow>
        │     ├── <SectionTitle> ("Mandi Price Intelligence")
        │     └── <AddPriceBtn> ("＋ Add Market Price" ──> opens <AddPriceModal>)
        ├── <MarketPriceTrendsChart> (Historical price chart over time by count size)
        └── <RecentPricesTable> (Date, Count Size, Price/kg ₹, Market Location)
```

---

## 3. UI Specifications & Styling Tokens

- **Financial KPI Cards (`.fin-kpi-card`)**:
  - Positive Profit Card: Emerald glow (`border: 1px solid rgba(16,185,129,0.3); background: rgba(16,185,129,0.06)`), value `--green: #10b981`.
  - Negative Profit Card: Rose glow (`border: 1px solid rgba(244,63,94,0.3); background: rgba(244,63,94,0.06)`), value `--red: #f43f5e`.
  - Font: `font-family: 'Outfit'`, font-weight 800, font-size $1.8\text{rem}$ to $2.2\text{rem}$.
- **Currency Formatter**: Indian Rupee format standard (`en-IN` numbering):
  - Values $\ge 1,00,000$ render in Lakhs (e.g. `₹4.12L`).
  - Values $\ge 1,000$ render in Thousands (e.g. `₹45.0K`).
  - Full display: `₹4,12,000`.
- **Expense Category Badges**:
  - `Feed`: Cyan (`#38bdf8`)
  - `Seed`: Sky Blue (`#00e5f5`)
  - `Electricity / Fuel`: Amber (`#fbbf24`)
  - `Labor`: Purple (`#a78bfa`)
  - `Medicine`: Teal (`#00c6d4`)
  - `Maintenance`: Slate (`#94a3b8`)
  - `Rent / Lease`: Indigo (`#6366f1`)

---

## 4. Complete Mathematical & Economic Models

### 4.1 Total Batch Cost Model
$$\text{Total Batch Cost} = \text{Inventory Costs} + \text{Manual Operating Expenses}$$
$$\text{Total Cost} = C_{\text{feed}} + C_{\text{seed}} + C_{\text{power}} + C_{\text{medicine}} + C_{\text{labor}} + C_{\text{lease}} + C_{\text{maint}} + C_{\text{misc}}$$

- **Automated Inventory Costs**:
  - $C_{\text{feed}}$: Automatically aggregated from `al_inventory` consumption records linked to this batch.
  - $C_{\text{medicine}}$: Aggregated from co-fed medicines and logged pond water treatments.
  - $C_{\text{fuel}}$: Proportionally allocated based on aerator HP-hours.
- **Manual Operating Expenses**:
  - Aggregated from `al_finance_expenses` matching `expense.batchId === batch.id`.

### 4.2 Total Revenue Model
$$\text{Realized Revenue (₹)} = \sum_{\substack{\text{rev} \in \text{al\_finance\_revenue} \\ \text{rev.batchId} = \text{batch.id}}} (\text{rev.weightKg} \times \text{rev.pricePerKg})$$

### 4.3 Projected Revenue Model (For Active Batches)
Estimates expected gross income if the current standing crop were harvested today:
$$\text{Current Biomass (kg)} = \text{updateBatchBiomassEstimation(batch).biomassKg}$$
$$\text{Latest Market Price (₹/kg)} = \text{getLatestMarketPrice().pricePerKg}$$
$$\text{Projected Revenue (₹)} = \text{Current Biomass} \times \text{Latest Market Price}$$

### 4.4 Net Crop Profit & Profit Margin
$$\text{Net Profit (₹)} = \text{Total Revenue} - \text{Total Batch Costs}$$
$$\text{Profit Margin \%} = \left( \frac{\text{Net Profit}}{\text{Total Revenue}} \right) \times 100$$
- If Revenue $= ₹1,320,000$ and Costs $= ₹908,000$:
  $$\text{Net Profit} = 1,320,000 - 908,000 = ₹412,000$$
  $$\text{Margin} = \left( \frac{412,000}{1,320,000} \right) \times 100 = 31.2\%$$

### 4.5 Break-Even Shrimp Sale Price Benchmark
The absolute minimum price per kilogram the farmer must negotiate with buyers to avoid a net loss:
$$\text{Break-Even Price (₹/kg)} = \frac{\text{Total Batch Expenses (₹)}}{\text{Harvested Weight or Estimated Biomass (kg)}}$$
*Example: Total batch expense is ₹$908,000$ and current biomass is $2,800\text{ kg}$:*
$$\text{Break-Even Price} = \frac{908,000}{2,800} = ₹324.28 / \text{kg}$$
- **Decision Support Guidance**:
  - If buyer offers ₹$420/\text{kg}$: Net profit is $+₹95.72/\text{kg}$ ($\checkmark$ **Favorable harvest window**).
  - If buyer offers ₹$310/\text{kg}$: Below break-even ($\times$ **Hold crop for weight gain or seek alternative processor**).

---

## 5. Mandi Market Price Intelligence & Size Categories

Indian and global shrimp trade prices are indexed by "Count" (number of headless or whole shrimp per kilogram):

| Count Size | Individual Shrimp Weight (g) | Typical Commercial DOC | Relative Market Demand |
| :--- | :--- | :--- | :--- |
| **30 count** | $33.3\text{ grams}$ | DOC 110 – 130 | Premium Export (Highest price: ₹$480 - ₹540/\text{kg}$) |
| **40 count** | $25.0\text{ grams}$ | DOC 90 – 105 | Standard Commercial Harvest (₹$400 - ₹450/\text{kg}$) |
| **60 count** | $16.6\text{ grams}$ | DOC 65 – 80 | Partial Netting / Thinning size (₹$320 - ₹360/\text{kg}$) |
| **100 count** | $10.0\text{ grams}$ | DOC 40 – 50 | Juvenile emergency harvest (Lowest price: ₹$220 - ₹260/\text{kg}$) |

---

## 6. Detailed Modals Specifications

### 6.1 Add Expense Modal (`#addExpenseModal`)
- **Fields**:
  - Date (`#expenseDate`): required.
  - Category (`#expenseCategory`): dropdown (Seed, Labor, Electricity, Maintenance, Rent, Equipment, Other).
  - Amount in ₹ (`#expenseAmount`): required, numerical $> 0$.
  - Batch Attribution (`#expenseBatch`): optional dropdown listing active batches. If left blank, recorded as general farm overhead.
  - Description (`#expenseDescription`): text (e.g. *"Monthly diesel fuel for backup generator"*).
- **On Submit**: Generates `id = "exp_" + Date.now()`, stores in `al_finance_expenses`, updates overview KPIs.

### 6.2 Add Revenue Modal (`#addRevenueModal`)
- **Fields**:
  - Date (`#revenueDate`): required.
  - Batch (`#revenueBatch`): required dropdown of batches.
  - Weight Sold in kg (`#revenueWeightKg`): required, $> 0$.
  - Price per kg in ₹ (`#revenuePricePerKg`): pre-filled with latest market price, editable.
  - Buyer Name (`#revenueBuyer`): text (e.g. *"Nekkanti Sea Foods"*).
- **On Submit**: Calculates `totalAmount = weightKg * pricePerKg`, stores in `al_finance_revenue`, refreshes profit margin.

### 6.3 Add Market Price Modal (`#addPriceModal`)
- **Fields**:
  - Date (`#priceDate`): required.
  - Price per kg in ₹ (`#pricePerKg`): required.
  - Size Category (`#priceSizeCategory`): e.g. "30 count", "40 count".
  - Mandi / Location (`#priceLocation`): e.g. "Bhimavaram Mandi", "Nellore".
- **On Submit**: Stores in `al_finance_prices`, updates price trend chart and projected revenue calculations.

---

## 7. Google Stitch Re-Creation Recommendations

1. **Interactive Profit Simulation Slider**: Create a "What-If" simulator slider on the Overview tab where farmers can drag target market price (₹350 to ₹550) or survival rate ($70\%$ to $95\%$) and immediately watch projected net profit adjust.
2. **Category Cost Donut Chart**: Render an interactive Recharts Donut chart with smooth hover slice expansion and center total cost label.
3. **P&L Export to PDF**: Provide a one-click executive financial report generator formatted for agricultural banks and crop insurance auditors.
