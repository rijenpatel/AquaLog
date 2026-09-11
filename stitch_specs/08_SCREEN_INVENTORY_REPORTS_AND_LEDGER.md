# 08 — Screen Specification: Inventory Reports & Ledger

> **Screen ID**: `pageInventoryReports`  
> **Route / Navigation**: `pageInventory` ──> tap "Reports" (`#btnGoToInventoryReports`)  
> **Target Component**: `<InventoryReportsPage />`

---

## 1. Screen Objective & Mental Model

At the conclusion of a shrimp crop cycle or during monthly farm audits, the business owner and farm manager must perform inventory reconciliation:
- *What was the total tonnage of feed purchased this season versus total biomass harvested?*
- *Are there unaccounted inventory leakages, bag breakages, or unlogged feeding sessions?*
- *Which feed vendor offered the lowest price per kilogram over the last 12 months?*
- *What is the total monetary valuation of chemical, mineral, and probiotic stock currently sitting in the warehouse?*

The **Inventory Reports Screen** is the audit and analytical engine for all farm supplies. It provides 6 distinct multi-dimensional reports, complete double-entry transaction ledgers, pagination, and clean CSV export capabilities.

---

## 2. Visual Hierarchy & Screen Structure

```
<InventoryReportsPage>
  ├── <DetailHeaderBar>
  │     ├── <BackButton id="btnBackInventoryReports"> ("←" ──> returns to pageInventory)
  │     └── <TitleBlock>
  │           ├── <Title> ("Inventory Reports")
  │           └── <Subtitle id="reportsSiteName"> ("Site 1 - Coastal Farm")
  │
  ├── <SiteSelectorCard> (Drop-down selector for site-scoped reporting)
  │
  ├── <ReportTypeSelectorCard>
  │     ├── <Label> ("Select Report Type · रिपोर्ट का प्रकार")
  │     └── <DropdownSelect id="inventoryReportTypeSelect">
  │           ├── "Feed Purchase History" (default)
  │           ├── "Medicine Purchase History"
  │           ├── "Fuel Purchase History"
  │           ├── "Current Inventory Status & Valuation"
  │           ├── "Low Stock Alerts & Shortfalls"
  │           └── "Stock Movement Ledger"
  │
  ├── <SearchAndFilterControlsCard>
  │     ├── <SearchInput id="reportSearchInput"> ("Search...")
  │     ├── <DateRangeFilter> (From [ Date ] · To [ Date ])
  │     ├── <DynamicCategoryFilter id="reportCategoryFilterGroup"> (Visible for medicine reports)
  │     ├── <DynamicFuelFilter id="reportFuelTypeFilterGroup"> (Visible for fuel reports)
  │     ├── <DynamicTxTypeFilter id="reportTxTypeFilterGroup"> (Purchase, Consumption, Adjustment, Damaged)
  │     ├── <DynamicTogglesRow> (Low Stock, Out of Stock, Expiring Soon)
  │     └── <ActionButtonsRow>
  │           ├── <ClearFiltersBtn id="btnClearReportFilters"> ("Clear Filters")
  │           └── <ExportCsvBtn id="btnExportReportCSV"> ("📥 Export CSV")
  │
  └── <ReportTableViewSection>
        ├── <LoadingStateIndicator id="reportLoadingState"> ("Generating Report...")
        ├── <ResponsiveTableWrapper id="reportTableWrapper">
        │     └── <DynamicReportTable> (Headers and rows adjust based on report type)
        └── <PaginationBar id="reportPaginationBar">
              ├── <PrevPageBtn id="btnReportPrevPage"> ("◀")
              ├── <PaginationLabel id="reportPaginationLabel"> ("Page 1 of 5")
              └── <NextPageBtn id="btnReportNextPage"> ("▶")
```

---

## 3. The 6 Standard Report Specifications

### 3.1 Report 1: Feed Purchase History (`feed_purchase`)
- **Objective**: Audit all commercial feed purchases, lot numbers, bag counts, and supplier invoices.
- **Table Columns**:
  1. Date (`tx.date`)
  2. Brand (`item.brand`)
  3. Pellet Size (`item.pelletSize`)
  4. Bags (`tx.quantity / item.bagWeightKg`)
  5. Total Weight kg (`tx.quantity`)
  6. Rate per Bag ₹ (`tx.unitPrice`)
  7. Total Invoiced ₹ (`tx.totalCost`)
  8. Supplier (`item.supplier`)
  9. Lot / Batch # (`item.batchLotNumber`)
- **Summary Row**: Total Bags Purchased, Total Metric Tons, Total Spend ₹.

### 3.2 Report 2: Medicine Purchase History (`medicine_purchase`)
- **Objective**: Audit biologicals, probiotics, minerals, and chemicals purchased.
- **Table Columns**:
  1. Date
  2. Category (Probiotic, Mineral, Disinfectant, Lime)
  3. Product Name
  4. Quantity & Unit (e.g. `25 kg`, `10 L`)
  5. Unit Cost ₹
  6. Total Amount ₹
  7. Expiry Date
  8. Supplier
- **Summary Row**: Total Units Purchased, Total Chemical Spend ₹.

### 3.3 Report 3: Fuel Purchase History (`fuel_purchase`)
- **Objective**: Audit energy purchases for backup generators and pumps.
- **Table Columns**:
  1. Date
  2. Fuel Type (Diesel, Petrol, Lubricant)
  3. Liters Purchased
  4. Price per Liter ₹
  5. Total Amount ₹
  6. Vendor / Pump Station
- **Summary Row**: Total Liters, Total Fuel Spend ₹.

### 3.4 Report 4: Current Inventory Status & Valuation (`current_inventory`)
- **Objective**: Complete balance sheet of all supplies in farm storage.
- **Table Columns**:
  1. Pillar (Feed / Medicine / Fuel)
  2. Item Description & Brand
  3. Current Stock Balance
  4. Packaging / Units
  5. Valuation Rate ₹/unit
  6. Total Value ₹ (`currentStock * costPerUnit`)
  7. Threshold Alert Status (Normal / Low / Empty)
- **Summary Row**: Total Farm Inventory Value in ₹.

### 3.5 Report 5: Low Stock Alerts & Shortfalls (`low_stock`)
- **Objective**: Exception report identifying supplies at risk of immediate stock-out.
- **Table Columns**:
  1. Item Name
  2. Pillar Category
  3. Current Stock
  4. Minimum Threshold
  5. Deficit / Shortfall Quantity (`threshold - currentStock`)
  6. Estimated Days of Stock Left
  7. Recommended Reorder Quantity
  8. Supplier Contact

### 3.6 Report 6: Stock Movement Ledger (`stock_movement`)
- **Objective**: Full double-entry audit trail accounting for every single kilogram or liter entering or leaving the farm.
- **Table Columns**:
  1. Timestamp / Date
  2. Transaction Type (`PURCHASE`, `FEEDING_CONSUMPTION`, `TREATMENT`, `SPOILAGE`, `ADJUSTMENT`)
  3. Item Name & Size
  4. Target Pond / Reference (e.g. "Pond 1 - 7:00 AM Feed")
  5. Inward Qty (+)
  6. Outward Qty (-)
  7. Running Balance
  8. Notes / Staff Attribution

---

## 4. Analytical Metrics & Audit Formulas

### 4.1 Stock Turnover Ratio (STR)
Measures how efficiently inventory is utilized during a culture cycle:
$$\text{Average Inventory Value (₹)} = \frac{\text{Beginning Inventory Value} + \text{Ending Inventory Value}}{2}$$
$$\text{Cost of Goods Used (₹)} = \sum \text{Consumption Transactions Cost}$$
$$STR = \frac{\text{Cost of Goods Used}}{\text{Average Inventory Value}}$$
- A higher STR ($> 4.0\text{ per crop}$) indicates lean, efficient inventory turnover without tied-up working capital.

### 4.2 Feed Wastage & Shrinkage Percentage
$$\text{Feed Shrinkage \%} = \left( \frac{\sum \text{Spoilage \& Damaged Feed (kg)}}{\sum \text{Purchased Feed (kg)}} \right) \times 100$$
- Commercial benchmark: Must remain below $1.5\%$. If $> 3.0\%$, indicates high humidity in storage room or rodent damage.

### 4.3 Supplier Cost Inflation Trend Index
Tracks price changes per bag over sequential months:
$$\text{Inflation Index} = \left( \frac{\text{Current Month Bag Price} - \text{Baseline Bag Price}}{\text{Baseline Bag Price}} \right) \times 100$$

---

## 5. Pagination & Export Mechanics

### 5.1 Pagination Engine
- Default page size: $25\text{ rows per page}$.
- Total pages: $\text{TotalPages} = \lceil \frac{\text{FilteredRows.length}}{25} \rceil$.
- UI elements `#btnReportPrevPage` and `#btnReportNextPage` enable/disable dynamically based on `currentPage === 1` and `currentPage === totalPages`.

### 5.2 CSV Export Generator (`#btnExportReportCSV`)
1. Filters data using the active criteria.
2. Generates standard RFC 4180 CSV string:
   - Includes header row matching active report columns.
   - Escapes commas, quotes, and newline characters in notes or names.
3. Creates a downloadable Blob:
   ```typescript
   const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
   const url = URL.createObjectURL(blob);
   const link = document.createElement('a');
   link.href = url;
   link.download = `AquaLog_${reportType}_${todayStr()}.csv`;
   link.click();
   ```

---

## 6. Google Stitch Re-Creation Recommendations

1. **Sticky Header Data Table**: Wrap the table in a container with `sticky top-0` headers and alternating zebra row striping (`odd:bg-surface even:bg-surface-2`).
2. **Column Sorting**: Allow clicking table column headers (Date, Qty, Amount) to toggle ascending/descending order.
3. **Print-Friendly CSS**: Include `@media print` rules that hide navigation bars, dark background blobs, and render a clean, black-and-white formal audit table for bank loans or insurance claims.
