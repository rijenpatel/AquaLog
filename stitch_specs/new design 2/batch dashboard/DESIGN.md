---
name: AquaLog Android
colors:
  surface: '#f2fbfd'
  surface-dim: '#d3dcde'
  surface-bright: '#f2fbfd'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#ecf5f7'
  surface-container: '#e6eff1'
  surface-container-high: '#e1eaec'
  surface-container-highest: '#dbe4e6'
  on-surface: '#151d1f'
  on-surface-variant: '#3f484b'
  inverse-surface: '#293234'
  inverse-on-surface: '#e9f2f4'
  outline: '#6f797b'
  outline-variant: '#bec8cb'
  surface-tint: '#006876'
  primary: '#004e59'
  on-primary: '#ffffff'
  primary-container: '#006876'
  on-primary-container: '#97e4f4'
  inverse-primary: '#85d2e2'
  secondary: '#4a6267'
  on-secondary: '#ffffff'
  secondary-container: '#cde7ed'
  on-secondary-container: '#50686d'
  tertiary: '#3a4664'
  on-tertiary: '#ffffff'
  tertiary-container: '#525e7d'
  on-tertiary-container: '#ccd8fd'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a2efff'
  primary-fixed-dim: '#85d2e2'
  on-primary-fixed: '#001f25'
  on-primary-fixed-variant: '#004e59'
  secondary-fixed: '#cde7ed'
  secondary-fixed-dim: '#b1cbd1'
  on-secondary-fixed: '#051f23'
  on-secondary-fixed-variant: '#334b4f'
  tertiary-fixed: '#d9e2ff'
  tertiary-fixed-dim: '#bac6ea'
  on-tertiary-fixed: '#0e1b36'
  on-tertiary-fixed-variant: '#3a4664'
  background: '#f2fbfd'
  on-background: '#151d1f'
  surface-variant: '#dbe4e6'
typography:
  display-large:
    fontFamily: Roboto Flex
    fontSize: 57px
    fontWeight: '400'
    lineHeight: 64px
    letterSpacing: -0.25px
  display-medium:
    fontFamily: Roboto Flex
    fontSize: 45px
    fontWeight: '400'
    lineHeight: 52px
    letterSpacing: 0px
  display-small:
    fontFamily: Roboto Flex
    fontSize: 36px
    fontWeight: '400'
    lineHeight: 44px
    letterSpacing: 0px
  headline-large:
    fontFamily: Roboto Flex
    fontSize: 32px
    fontWeight: '400'
    lineHeight: 40px
    letterSpacing: 0px
  headline-medium:
    fontFamily: Roboto Flex
    fontSize: 28px
    fontWeight: '400'
    lineHeight: 36px
    letterSpacing: 0px
  headline-small:
    fontFamily: Roboto Flex
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 32px
    letterSpacing: 0px
  title-large:
    fontFamily: Roboto Flex
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
    letterSpacing: 0px
  title-medium:
    fontFamily: Roboto Flex
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: 0.15px
  title-small:
    fontFamily: Roboto Flex
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  body-large:
    fontFamily: Roboto Flex
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-medium:
    fontFamily: Roboto Flex
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  body-small:
    fontFamily: Roboto Flex
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.4px
  label-large:
    fontFamily: Roboto Flex
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-medium:
    fontFamily: Roboto Flex
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
  label-small:
    fontFamily: Roboto Flex
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  spacing-4: 4px
  spacing-8: 8px
  spacing-12: 12px
  spacing-16: 16px
  spacing-24: 24px
  spacing-32: 32px
  margin-compact: 16px
  margin-medium: 24px
  margin-expanded: 32px
  gutter-compact: 8px
  gutter-medium: 16px
  touch-target-min: 48px
---

## Brand & Style
The design system delivers an authentic Material Design 3 (Material You) experience tailored for mission-critical aquaculture operations on Android devices. It balances field-ready utility with the refined, modern poise of modern Google core applications (such as Google Home, Files by Google, and Google Fit).

### Visual Aesthetic & Persona
- **Stock Android Native:** Rooted in systematic Material Design 3 guidelines—tonal surfaces, dynamic color roles, standardized 48dp touch targets, and tactile state layers.
- **Precision Agritech:** Clean, data-dense, and utilitarian. It eliminates ornamental clutter in favor of high-contrast readability under direct outdoor sunlight on fish farms and hatchery stations.
- **Tone:** Methodical, calm, highly dependable, and scientifically precise.

## Colors
The color architecture strictly implements Material Design 3 tonal palette algorithms:
- **Primary (`#006876` / `#A1EFFF` container):** Pure aquatic deep teal, symbolizing biological water management, oxygenation status, and verified pond telemetry.
- **Secondary (`#4A6267`):** Slate-teal muted hue used for functional grouping, auxiliary data chips, and passive device statuses.
- **Tertiary (`#525E7D`):** Deep oceanic indigo reserved for analytical trend lines, biological sampling logs, and batch growth indices.
- **Surfaces:** Clean light neutral `#FAFDFD` and true dark neutral `#0E1415`, employing M3 `surface-container-*` tiers in place of arbitrary gray ramps.

### Semantic Aquaculture Tokens
- **Health / Water Quality:** `status-optimal` (dissolved oxygen, pH, temperature nominal), `status-warning` (elevated ammonia/nitrite, borderline salinity), and `status-critical` (anoxia, mortality spike).
- **Check-Tray Telemetry:** Explicit tokens for shrimp/fish feeding evaluation:
  - `status-tray-empty`: Underfed or high-consumption rate (feed rate increase indicator).
  - `status-tray-normal`: Optimal consumption rate matched to biomass.
  - `status-tray-surplus`: Overfed/uneaten feed present (immediate alert to stop feed blowers).

## Typography
The system uses Roboto Flex across all type scales, aligned with the canonical Material 3 type matrix.

### Operational Guidance
- **Telemetry Readouts:** Use `headline-medium` or `headline-small` for live pond sensor telemetry (e.g., `6.8 mg/L DO`), paired with a `label-small` suffix.
- **Tabular Data:** Use proportional tabular figures (`font-variant-numeric: tabular-nums`) inside pond log tables, sampling records, and feed weight breakdowns to avoid horizontal layout jitter during live Bluetooth telemetry updates.
- **Letter Spacing:** Maintain positive letter spacing for `label-*` roles to enhance outdoor legibility on handheld devices.

## Layout & Spacing
Built on the standard Android 8dp grid system (with a 4dp micro-step for compact icon and tag paddings).

### Grid & Responsiveness
- **Compact (Phones, &lt;600dp):** 4-column fluid layout with 16dp outer margins and 8dp to 16dp gutters. Bottom Navigation Bar anchors primary workflow destinations (Ponds, Feed, Sampling, Alerts).
- **Medium (Foldables & Tablets, 600dp - 839dp):** 8-column layout with 24dp margins. Introduces a persistent Navigation Rail.
- **Expanded (Landscape Tablets & Terminals, ≥840dp):** 12-column layout with 32dp margins. Supports master-detail split views (Pond listing on left 4 columns, real-time sensor metrics and check-tray input on right 8 columns).

### Field Accessibility
All interactive elements—including filter chips, table rows, and sensor action triggers—enforce the mandatory 48x48dp minimum accessible touch target.

## Elevation & Depth
In line with Material Design 3, spatial depth is communicated primarily through **tonal surface container color mapping** rather than cast shadows alone.

### Surface Hierarchy
- **Level 0 (Base canvas):** `surface` (Light: `#FAFDFD`, Dark: `#0E1415`). Flat, no shadow.
- **Level 1 (Resting cards, search bars):** `surface-container-low` with subtle shadow (`0px 1px 2px rgba(0, 0, 0, 0.08), 0px 1px 3px 1px rgba(0, 0, 0, 0.05)`).
- **Level 2 (Hover/Focus cards, active tray items):** `surface-container` with elevation shadow (`0px 1px 2px rgba(0, 0, 0, 0.15), 0px 2px 6px 2px rgba(0, 0, 0, 0.08)`).
- **Level 3 (Floating Action Buttons, Top App Bars on scroll):** `surface-container-high` (`0px 1px 3px rgba(0,0,0,0.2), 0px 4px 8px 3px rgba(0,0,0,0.1)`).
- **Level 4 & 5 (Dialogs, Bottom Sheets):** `surface-container-highest` with modal scrim (`rgba(0, 31, 37, 0.32)` light, `rgba(0, 0, 0, 0.6)` dark).

### State Layers
State variations apply standard Material opacity overlays of the `on-*` color:
- **Hover:** 8% opacity overlay
- **Focus:** 10% opacity overlay
- **Pressed:** 10% opacity overlay
- **Dragged:** 16% opacity overlay

## Shapes
Shapes define the component scale and match Google system app conventions:
- **Cards & Surfaces:** Strict **16dp** (`shape-corner-large`) border radius, establishing the signature Google Home / Files container silhouette.
- **Text Fields & Inputs:** Strict **8dp** (`shape-corner-small`) for outlined and filled M3 text boxes.
- **Action Buttons & Badges:** Fully rounded **9999dp** (`shape-corner-full`) for filled/tonal/outlined buttons, suggestion chips, and check-tray status pills.
- **Dialogs & Bottom Sheets:** **28dp** (`shape-corner-extra-large`) for modal surfaces and alert sheets.

## Components

### Buttons
- **Filled Button:** Reserved for primary actions (e.g., "Confirm Feeding", "Sync Sensors"). Background `primary`, label `on-primary`. Height 40dp, pill-shaped (`shape-corner-full`).
- **Tonal Button:** Secondary actions within cards (e.g., "Add Check Tray"). Background `secondary-container`, text/icon `on-secondary-container`.
- **Outlined Button:** Neutral actions (e.g., "Export Log"). Border 1dp `outline`, label `primary`.

### Cards (Ponds, Telemetry, and Sampling)
- **Container Radius:** Strict 16dp.
- **Elevated / Filled Card:** Base fill `surface-container-low` in light mode, `surface-container` in dark mode. No harsh border; separation handled by tonal steps.
- **Card Padding:** 16dp internal padding. Top section hosts pond ID + quick status indicator badge; middle displays primary telemetric stats; footer contains quick action buttons or time stamps.

### Input Fields
- **Container Radius:** Strict 8dp corner radius.
- **Outlined Text Field:** Default for field data entry. 1dp border using `outline-variant`; transitions to 2dp `primary` on focus. Height 56dp. Floating label utilizes `body-small` on focus. Supporting text uses `body-small` with `on-surface-variant`.
- **Check-Tray Numeric Stepper:** Integrated within an 8dp container with prominent decrement/increment tap areas conforming to the 48dp minimum hit box.

### Chips
- **Assist / Filter Chips:** 8dp or 9999dp radius, 32dp height. Active state uses `secondary-container` fill with `on-secondary-container` text. Unselected state uses transparent fill with 1dp `outline-variant` border.
- **Input Chips:** For active filters (e.g., "Pond 04", "DO &lt; 4.0 mg/L") featuring a trailing remove icon.

### Check-Tray Status Indicators
- **Empty Tray Pill:** `status-tray-empty` container with appropriate on-container text. Indicates feed was consumed rapidly.
- **Normal Tray Pill:** `status-tray-normal` container. Feed consumption matches target curve.
- **Surplus Tray Pill:** `status-tray-surplus` container with warning iconography. Directs operator to decrease upcoming ration.

### Lists & Tables
- **List Items:** Single-line (56dp), two-line (72dp), and three-line (88dp). Inset 16dp padding. Divider lines use `outline-variant` at 1dp thickness when explicit separation is required.