# 02 — Screen Specification: Feed Logging & Check-Tray Management

> **Screen ID**: `pageLog`  
> **Route / Navigation**: Center Bottom Nav Floating Action Button (FAB `+`) | Quick Add buttons | Keyboard Shortcut `Ctrl+N` or `g` then `l`  
> **Target Component**: `<FeedLoggingPage />` / `<FeedEntryDrawer />`

---

## 1. Screen Objective & User Mental Model

Feeding represents $55\% \text{ to } 65\%$ of the total operating expenditure in commercial shrimp farming. Overfeeding causes catastrophic water quality degradation (ammonia spikes, DO collapse, vibrio outbreaks) and financial loss; underfeeding results in shrimp cannibalism, uneven sizing, and stunted growth.

The **Log Feed Screen** is the most frequently accessed workflow in AquaLog (used 4 to 5 times daily per pond). Its design priorities are:
1. **Ultra-Fast Outdoor Entry**: Maximum 3 to 4 taps from open to submit. Large touch targets operable with wet or gloved hands.
2. **Precision Multi-Feed Sizing**: Commercial farms mix multiple pellet sizes (e.g. $40\%$ Grower 1.2mm + $60\%$ Grower 1.6mm) during size transitions.
3. **Integrated Check-Tray Intelligence**: Closing the feedback loop between feed broadcast and leftover tray observations.
4. **Instant Inventory Deduction**: Every logged bag/gram immediately decrements farm stock and alerts on replenishment needs.
5. **Zero-Loss Offline Safety**: Instant local persistence with two-tap duplicate prevention.

---

## 2. Visual Hierarchy & Form Layout

```
<FeedLoggingPage>
  ├── <ScreenHeader>
  │     ├── <Title> ("🦐 Log Feed")
  │     └── <BilingualSubtitle> ("खाना दर्ज करें · Record a Feeding Session")
  │
  └── <FeedForm id="feedForm">
        │
        ├── <WhenCard> (DateTime Capsule)
        │     ├── <DateCapsule> (Calendar picker + display badge)
        │     ├── <Divider />
        │     ├── <TimeCapsule> (Dropdown: 7:00 AM, 11:00 AM, 4:00 PM, 7:00 PM, Other)
        │     └── <CustomTimeSlideGroup> (HTML5 time input, slides down if "Other" chosen)
        │
        ├── <WhereCard> (Pond Selection)
        │     ├── <PondDropdownSelector> (Lists all active ponds with batch badges)
        │     └── <NoBatchInlineAlert> ("⚠️ Selected pond has no active batch. [Go to Manage →]")
        │
        ├── <FeedTypesCard> (Multi-Feed Grid & Quantities)
        │     ├── <FeedGridPills> (Starter, Grower 1, Grower 2, Finisher 1, Finisher 2, Other)
        │     ├── <DynamicQuantityInputs> (Number inputs for each active feed pill)
        │     ├── <LiveTotalFeedBadge> (Dynamic sum: "Total: 12.5 kg")
        │     └── <OtherFeedSlideGroup> (Custom feed name and custom quantity)
        │
        ├── <CheckTrayMonitoringCard> (Feed Consumption Feedback Loop)
        │     ├── <TrayInspectionTimeBadge> ("Inspect tray at: 9:00 AM (2 hrs post feed)")
        │     ├── <LeftoverPercentageSelector> (Segmented pills: 0% Clean, 10%, 25%, 50%+)
        │     └── <AutoAdjustmentGuidanceBox> (Live recommendation: "+5% next feed", etc.)
        │
        ├── <MedicineSupplementDrawer> (Collapsible Co-Feeding Entry)
        │     ├── <DrawerHeaderToggle> ("💊 Medicine / Supplement Entry" · Optional badge)
        │     └── <DrawerBody>
        │           ├── <StockPickerRow> (Item dropdown, stock badge, qty input, unit, "+ Add")
        │           ├── <CustomItemOption> (Optional custom name input)
        │           └── <MedicineEntryTable> (List of items added with delete action)
        │
        ├── <NotesCard> (Environmental & Shrimp Behavior Observations)
        │     └── <Textarea> ("Water color, turbidity, shrimp swimming vigor, weather notes...")
        │
        ├── <SubmitActionBar>
        │     ├── <SubmitButton> ("✓ Log Feed Entry · फीड दर्ज करें")
        │     ├── <LoadingSpinner> ("Saving… · सहेज रहे हैं…")
        │     └── <DuplicateWarningBanner> ("⚠️ Similar entry already submitted. Tap again to confirm.")
        │
        └── <ExternalSyncCards> (Collapsible Third-Party Integrations)
              ├── <GoogleSheetsSyncCard> (Apps Script Web App URL config)
              └── <CustomRestApiSyncCard> (API Endpoint, HTTP Method, Auth Token, JSON Headers)
```

---

## 3. UI Specifications & Design Tokens

- **Form Container**: Padded mobile column (`max-width: 600px; margin: 0 auto; padding: 12px 16px`).
- **Capsule Date/Time Picker**: Seamless pill container (`border: 1px solid var(--border); border-radius: var(--r-md); background: var(--surface)`), divided by a vertical line, combining native HTML5 pickers with custom formatted display labels (`#feedDateDisplay`, `#feedTimeDisplay`).
- **Feed Type Grid**: 3-column responsive grid (`grid-template-columns: repeat(3, 1fr); gap: 8px`). Each pill:
  - Default: `background: rgba(255,255,255,0.03); border: 1px solid var(--border)`.
  - Active / Selected: `background: rgba(0,229,245,0.12); border: 1.5px solid var(--teal); color: var(--teal)`.
- **Check-Tray Segmented Control**: 4 distinct color-coded buttons:
  - `0% Clean`: Emerald Green (`#10b981`)
  - `10% Normal`: Cyan (`#38bdf8`)
  - `25% Moderate`: Amber (`#fbbf24`)
  - `> 50% Heavy`: Crimson Rose (`#f43f5e`)
- **Submit Button**: High-prominence action button (`height: 52px; background: linear-gradient(135deg, var(--teal), #0097a7); color: #040914; font-weight: 700; border-radius: 14px; box-shadow: 0 4px 20px var(--teal-glow)`).

---

## 4. State Machine & Data Models

### 4.1 Form State Interface
```typescript
interface FeedFormState {
  date: string;                     // "YYYY-MM-DD", defaults to todayStr()
  timeSlot: string;                 // "7:00 AM" | "11:00 AM" | "4:00 PM" | "7:00 PM" | "Other"
  customTime: string;               // "HH:MM", required if timeSlot === "Other"
  pondId: string;                   // Selected Pond ID
  batchId: string;                  // Resolved active Batch ID
  activeFeedTypes: Set<string>;     // Set of keys, e.g. {'feed1', 'feed3'}
  quantities: Record<string, number>; // { feed1: 2500, feed3: 5000 } in grams
  otherFeedName: string;
  otherFeedQty: number;
  
  // Tray Assessment
  trayChecked: boolean;
  trayLeftoverPct: number;          // 0, 10, 25, 50
  
  // Co-fed medicines
  medicines: Array<{
    id: string;
    itemId?: string;
    name: string;
    qty: number;
    unit: string;
    stockRemaining: number;
  }>;
  
  notes: string;
  isSubmitting: boolean;
  duplicateWarningActive: boolean;
  errors: Record<string, string>;
}
```

---

## 5. Micro-Level Business Logic & Algorithms

### 5.1 Time Slot Logic & Default Selection
- When the screen loads, the system inspects current local device time:
  - `05:00 - 09:30` $\rightarrow$ Auto-selects `7:00 AM`
  - `09:31 - 13:30` $\rightarrow$ Auto-selects `11:00 AM`
  - `13:31 - 17:30` $\rightarrow$ Auto-selects `4:00 PM`
  - `17:31 - 22:00` $\rightarrow$ Auto-selects `7:00 PM`
  - `22:01 - 04:59` $\rightarrow$ Defaults to `7:00 AM` next day or `Other`
- If user selects `"Other"` from `#feedTime`, remove class `slide-hide` on `#customTimeGroup`, set focus to `#customTime`.

### 5.2 Active Batch Validation on Pond Select
When `#pondSelect` changes:
1. Lookup selected pond in `ponds`.
2. Find active batch where `batch.pondId === selectedPond.id && batch.status === 'active'`.
3. **If NO active batch exists**:
   - Reveal `#noBatchWarning`: *"⚠️ Selected pond has no active batch. Go to Manage →"*.
   - Disable `#submitBtn`.
   - Prevent quantity input interactions.
4. **If active batch exists**:
   - Hide `#noBatchWarning`.
   - Enable `#submitBtn`.
   - Display small context chip showing batch number, stocking species, and current DOC (e.g. `Batch #2 · DOC 45`).

### 5.3 Multi-Feed Calculation & Units
1. Users toggle feed buttons in `#feedGrid`:
   - `Feed 1`: Starter 0.8mm (Nursery)
   - `Feed 2`: Grower 1.2mm
   - `Feed 3`: Grower 1.6mm
   - `Feed 4`: Finisher 2.0mm
   - `Feed 5`: Finisher 2.5mm
   - `Other`: Special mix / custom
2. For each active feed, render a quantity field with:
   - Numerical input (`inputmode="decimal"`).
   - Grams / Kilograms switch toggle.
   - Standard conversion formula: $\text{Grams} = \text{Kg} \times 1,000$.
3. **Live Total Feed Display**:
   $$\text{TotalGrams} = \sum \text{feedQty}_i + \text{otherFeedQty}$$
   Updated on every keystroke (`input` event).

### 5.4 Check-Tray Leftover Scoring Engine
Shrimp farmers place check trays (mesh nets with $1-2\%$ of total feed) submerged at fixed pond stations. Trays are checked $1.5\text{ to }2.0\text{ hours}$ post feeding.

The screen implements an automatic feedback calculator:
- **Case 1: 0% Leftover (Clean Tray)**
  - Shrimp consumed everything rapidly.
  - Calculated recommendation: $\text{Adjustment} = +5\% \text{ to } +10\%$.
  - UI Output: Emerald Badge *"Trays clean! Shrimp feeding aggressively. Recommend increasing next meal by +5%."*
- **Case 2: 1% - 10% Leftover (Normal Tray)**
  - Calculated recommendation: $\text{Adjustment} = 0\%$.
  - UI Output: Cyan Badge *"Optimal feeding rate. Maintain current feeding quantities."*
- **Case 3: 11% - 25% Leftover (Moderate)**
  - Calculated recommendation: $\text{Adjustment} = -10\% \text{ to } -15\%$.
  - UI Output: Amber Badge *"Feed leftover detected. Cut next meal by 10-15% to protect pond bottom."*
- **Case 4: > 25% Leftover (Heavy / Critical)**
  - Calculated recommendation: $\text{Adjustment} = -30\% \text{ to } -50\%$.
  - UI Output: Red Badge *"CRITICAL OVERFEED: Immediately cut next feed by 30-50%. Check DO, ammonia, and water temperature!"*

### 5.5 Medicine & Supplement Co-Feeding Engine
When farmers top-dress feed with probiotics, vitamins, or gut binders:
1. User expands `#medicineToggle`.
2. `#medicineItemSelect` dropdown queries `al_inventory` where `category === 'medicine'`.
3. Selecting an item displays `#medStockBadge` showing current available stock (e.g. `Stock: 850 g`).
4. User inputs dose `#medicineQty`.
5. Tapping `#addMedicineBtn`:
   - Validates quantity $> 0$.
   - Validates quantity $\le \text{available stock}$ (warns if insufficient stock).
   - Inserts row into `#medicineTableBody` with: Item Name, Quantity + Unit, Projected Stock Left, Delete button.
   - Clears selection for next item.

### 5.6 Automatic Inventory Stock Deduction (`syncFeedConsumption`)
When the form is submitted and saved:
1. For each feed type logged:
   - Identify corresponding `InventoryItem` in `al_inventory`.
   - Create an `InventoryTransaction`:
     ```json
     {
       "id": "tx_feed_1709726400000",
       "itemId": "inv_feed_grower_16",
       "type": "consumption",
       "quantity": -5.0,
       "date": "2026-09-06",
       "referenceRecordId": "rec_1709726400000",
       "notes": "Pond 1 - 7:00 AM feed"
     }
     ```
   - Decrement `item.currentStock = item.currentStock - quantity`.
   - If `item.currentStock <= item.lowStockThreshold`, trigger background low-stock notification.
2. For all co-fed medicines:
   - Deduct medicine stock similarly.

### 5.7 Two-Tap Duplicate Detection Pattern
To prevent farmers from accidentally submitting the same meal twice (e.g. double-tapping under poor sunlight):
1. On Submit, check existing records:
   $$\text{isDuplicate} = \exists \text{rec} \in \text{Records} \text{ s.t. } \text{rec.PondId} = \text{pondId} \land \text{rec.Date} = \text{date} \land \text{rec.Time} = \text{time}$$
2. If duplicate detected and `!duplicateWarningActive`:
   - Prevent form submission.
   - Set `duplicateWarningActive = true`.
   - Reveal `#dupWarn`: *"⚠️ Similar entry already submitted for this pond and time. Tap again to confirm."*
   - Flash submit button in amber.
3. If user taps Submit a second time while `duplicateWarningActive === true`:
   - Bypass duplicate check and persist record.

### 5.8 Background Cloud Sync (Google Sheets & Custom REST API)
1. **Google Sheets Apps Script Integration**:
   - If `#sheetsUrl` is configured in `al_sheets_url`:
   - Constructs payload:
     ```json
     {
       "date": "2026-09-06",
       "time": "7:00 AM",
       "pond": "Pond 1",
       "batch": "Batch #2",
       "starter": 0,
       "grower12": 2500,
       "grower16": 5000,
       "finisher20": 0,
       "finisher25": 0,
       "otherName": "",
       "otherQty": 0,
       "totalGrams": 7500,
       "notes": "Water clear, shrimp feeding well"
     }
     ```
   - Dispatches non-blocking `fetch(sheetsUrl, { method: 'POST', mode: 'no-cors', body: JSON.stringify(payload) })`.
2. **Custom REST API Endpoint**:
   - If `#apiUrl` is configured:
   - Dispatches `fetch(apiUrl, { method: apiMethod, headers: customHeaders, body: JSON.stringify(fullRecord) })`.
   - If offline, pushes job to `al_queue` for retry.

---

## 6. Edit & Delete Modals Specification

### 6.1 Edit Feed Modal (`#editFeedModal`)
- Triggered by pencil icon on Dashboard or Reports timeline.
- Pre-fills all fields: Date, Time, Feed Types, Quantities, Notes.
- **Critical Inventory Adjustment on Edit**:
  - When saving edits, calculate delta: $\Delta = \text{newQuantity} - \text{oldQuantity}$.
  - If $\Delta > 0$, deduct additional stock from inventory.
  - If $\Delta < 0$, refund surplus back to inventory stock!

### 6.2 Delete Feed Modal (`#deleteModal`)
- Displays confirmation: *"Delete Feed Entry? This action cannot be undone."*
- **Critical Inventory Refund on Delete**:
  - Automatically queries `al_inventory` for transactions where `referenceRecordId === record.Id`.
  - Reverses every transaction, refunding the exact feed and medicine amounts back to farm inventory!

---

## 7. Validation Rules & Error Messages

| Field | Validation Rule | Error ID | Display Message |
| :--- | :--- | :--- | :--- |
| Date (`#feedDate`) | Required. Valid ISO format. Not future date. | `#errDate` | *"Required. Select a valid date."* |
| Time (`#feedTime`) | Required. Must select slot or provide custom time. | `#errTime` | *"Required. Select feeding time."* |
| Custom Time (`#customTime`) | Required if `#feedTime === 'Other'`. | `#errCustomTime` | *"Enter custom time."* |
| Pond (`#pondSelect`) | Required. Pond must have an active batch. | `#errPond` | *"Please select a pond."* |
| Feed Types (`#feedGrid`)| At least one feed type or Other must be selected. | `#errFeed` | *"Select at least one feed type."* |
| Quantities | Active feed quantities must be $> 0$ and valid numbers. | Dynamic | *"Enter valid quantity in grams."* |
| Other Feed Name | Required if Other feed is toggled on. | `#errOtherName`| *"Enter custom feed name."* |
| Other Feed Qty | Required if Other feed is toggled on ($> 0$). | `#errOtherQty` | *"Enter valid quantity."* |

---

## 8. Google Stitch Re-Creation Recommendations

1. **Mobile Stepper / Quick Add Interface**:
   - Build a quick-stepper numerical keypad component with preset weight increments (`+500g`, `+1kg`, `+5kg`, `+10kg`) for rapid input in wet field conditions.
2. **Haptic Feedback**:
   - Integrate Web Haptics API (`navigator.vibrate([30])`) when selecting feed types or submitting successfully.
3. **Optimistic UI with Undo Toast**:
   - Immediately update local state, close drawer, and display toast: *"Feed logged: 12.5 kg [Undo]"* (with 5-second cancel window).
