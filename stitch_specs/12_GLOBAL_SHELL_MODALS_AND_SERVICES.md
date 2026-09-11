# 12 — Global Shell, Navigation Dock, Modals & Ambient Services

> **Scope**: Application Shell, Suspended Navigation Dock, Top Status Bar, Global Search, Command Palette, Ambient Particle Canvas, Shared Modals, and Service Worker PWA Engine.  
> **Target Components**: `<AppShell />`, `<BottomDock />`, `<TopStatusBar />`, `<CommandPalette />`, `<GlobalSearch />`, `<AmbientCanvas />`, `<ToastManager />`

---

## 1. Executive Overview

AquaLog is engineered with the tactile responsiveness of a native mobile operating system. Rather than treating screens as isolated web pages, the **Global Shell** provides an ambient, reactive container that wraps all 11 application screens with:
1. **Persistent Atmospheric Aesthetics**: Ambient underwater light mesh and responsive micro-bubble physics.
2. **Suspended Bottom Dock**: Ergonomic 7-slot thumb navigation with a prominent center Floating Action Button (FAB).
3. **Omnibar Intelligence**: Full-system search (`Ctrl+/`) and command execution palette (`Ctrl+K`).
4. **Resilient Network & Clock Services**: Real-time status bar monitoring digital time, online/offline transitions, and offline queue flush state.
5. **Universal Modals & Toast Dispatcher**: Consistent bottom-sheet dialogs with backdrop blur and touch swipe dismiss gestures.

---

## 2. Visual Hierarchy & Shell Architecture

```
<AppRoot id="app">
  │
  ├── <SplashScreen id="splash"> (Animated logo ring, bilingual title, pulsing dots)
  │
  ├── <AmbientBackgroundLayer>
  │     ├── <AmbientMeshGradients> (Teal, Cyan, Indigo ambient lights)
  │     └── <AmbientCanvas id="ambientCanvas"> (Floating bubbles and touch ripples)
  │
  ├── <TopStatusBar class="status-bar">
  │     ├── <LiveDigitalClock id="statusTime"> ("08:45 AM")
  │     └── <NetworkStatusPill>
  │           ├── <StatusDot id="statusDot"> (Green = Online, Amber = Offline)
  │           └── <StatusLabel id="statusLabel"> ("Online" | "Offline (3 pending)")
  │
  ├── <MainPageContainer id="pages" role="main">
  │     └── [Screen Components 01 to 11 rendered here]
  │
  ├── <SuspendedBottomDockContainer class="bottom-nav-wrap">
  │     ├── <DynamicBatchShortcutBtn id="batchShortcutBtn"> ("🦐 View Batch")
  │     └── <BottomNavGrid class="bottom-nav">
  │           ├── <NavItem Overview> (data-page="pageDashboard")
  │           ├── <NavItem Manage> (data-page="pageManage")
  │           ├── <NavItem Stock> (data-page="pageInventory")
  │           ├── <NavFab CenterQuickAdd> (data-page="pageLog") [Elevated + Button]
  │           ├── <NavItem Finance> (data-page="pageFinance")
  │           ├── <NavItem Reports> (data-page="pageReports")
  │           └── <NavItem Settings> (data-page="pageSettings")
  │
  ├── <GlobalOverlaysLayer>
  │     ├── <CommandPalette id="aqCmdPalette" role="dialog"> (Ctrl+K)
  │     ├── <GlobalSearchOverlay id="aqSearchOverlay" role="dialog"> (Ctrl+/)
  │     ├── <KeyboardShortcutsHelpModal> (?)
  │     ├── <ToastContainer id="toastContainer" />
  │     └── <SharedModalsContainer>
  │           ├── <DatePickerModal id="appDatePickerModal">
  │           ├── <GenericConfirmModal id="confirmModal">
  │           └── [All Domain Modals 01 to 11]
  │
  └── <ServiceWorkerWorkerLayer id="sw"> (Cache-first offline PWA engine)
```

---

## 3. Component Specifications & Micro-Logic

### 3.1 Splash Screen & Startup Sequence (`#splash`)
1. On initial HTML load, `#splash` is visible with `z-index: 99999`.
2. Displays pulsing logo ring with shrimp emoji `🦐`, animated title *"AquaLog"* / *"एक्वालॉग"*, and 3 bouncing dots.
3. Boot procedure executes in parallel:
   - Reads LocalStorage / IndexedDB caches.
   - Initializes `LocationService` and `WeatherService`.
   - Checks Service Worker registration.
4. After $1,200\text{ ms}$ (or DOMContentLoaded), `#splash` animates `opacity: 0` and `transform: scale(1.05)` over $350\text{ ms}$, then applies `display: none`.
5. Removes class `.hidden` from `#app`, triggering smooth fade-in of the active screen.

### 3.2 Top Status Bar (`.status-bar`)
Positioned at very top (`height: 38px; display: flex; justify-content: space-between; align-items: center; padding: 0 16px; background: rgba(4,9,20,0.6); backdrop-filter: blur(8px)`).
- **Digital Real-Time Clock (`#statusTime`)**:
  - Updates every $1,000\text{ ms}$ via `setInterval`.
  - Formats as `HH:MM:SS AM/PM` (or 12-hour format with local timezone).
- **Network Status Listener (`#statusDot`, `#statusLabel`)**:
  - Listens to `window.addEventListener('online')` and `'offline'`.
  - When Online: Dot turns Emerald (`#10b981`), Label displays *"Online"*. Triggers offline queue sync.
  - When Offline: Dot turns Amber (`#fbbf24`), Label displays *"Offline"*. If items exist in `al_queue`, displays *"Offline ([N] pending sync)"*.

### 3.3 Suspended Bottom Navigation Dock (`.bottom-nav`)
Positioned fixed at bottom center (`bottom: 12px; left: 16px; right: 16px; max-width: 500px; margin: 0 auto; z-index: 100`):
- **Glassmorphism Spec**: `background: rgba(8,15,30,0.85); backdrop-filter: blur(16px); border: 1px solid rgba(255,255,255,0.08); border-radius: 28px; box-shadow: 0 12px 40px rgba(0,0,0,0.6)`.
- **7-Item Responsive Grid**:
  1. Overview (`pageDashboard`): Grid icon
  2. Manage (`pageManage`): Water wave icon
  3. Stock (`pageInventory`): Cube package icon
  4. **Center Quick-Add FAB (`pageLog`)**:
     - Elevated circular button protruding $16\text{px}$ above the dock.
     - Dimensions: $54\text{px} \times 54\text{px}$, border-radius $50\%$.
     - Gradient: `linear-gradient(135deg, var(--teal), #0097a7)`.
     - Icon: Bold `+` line icon.
     - Shadow: Neon glowing halo (`box-shadow: 0 4px 20px rgba(0,229,245,0.4)`).
  5. Finance (`pageFinance`): Currency Rupee / Coin icon
  6. Reports (`pageReports`): Bar chart icon
  7. Settings (`pageSettings`): Gear icon
- **Active Tab Indicator**:
  - Active item icon lights up in `--teal: #00e5f5`.
  - Subtle glowing teal dot appears directly beneath the active label.

### 3.4 Dynamic Batch Shortcut Pill (`#batchShortcutBtn`)
Positioned floating directly above the bottom nav dock:
- Appears when user selects a specific batch from the dashboard context selector.
- Pill displays: `🦐 View Batch #2 · Pond 1`.
- Clicking smoothly scrolls or navigates directly to that batch’s management details.

### 3.5 Command Palette (`.aq-cmd`, `Ctrl+K`)
Provides instant power-user keyboard navigation:
- Triggered by `Ctrl+K` or `Cmd+K`.
- Search input with fuzzy matching against registered command dictionary:
  - *"Go to Dashboard"* $\rightarrow$ `switchPage('pageDashboard')`
  - *"Go to Manage"* $\rightarrow$ `switchPage('pageManage')`
  - *"Go to Stock / Inventory"* $\rightarrow$ `switchPage('pageInventory')`
  - *"Go to Finance"* $\rightarrow$ `switchPage('pageFinance')`
  - *"Go to Reports"* $\rightarrow$ `switchPage('pageReports')`
  - *"Log New Feed"* $\rightarrow$ `switchPage('pageLog')`
  - *"Create New Pond"* $\rightarrow$ `openCreatePondModal()`
  - *"Export JSON Backup"* $\rightarrow$ `exportFullBackup()`
  - *"Global Search"* $\rightarrow$ `openGlobalSearch()`
- Keyboard navigation: Arrow Up / Arrow Down to highlight, Enter to execute, Escape to dismiss.

### 3.6 Global Search Engine (`.aq-search-overlay`, `Ctrl+/`)
Full-text omnibar search engine across all domain collections:
- Triggered by `Ctrl+/` or search icon in top status bar.
- Queries simultaneously across:
  1. **Ponds**: Matches pond names.
  2. **Batches**: Matches batch numbers, stocked species, PL codes.
  3. **Feed Records**: Matches notes, dates, and feed mixes.
  4. **Inventory Items**: Matches brands, sizes, chemical names, suppliers.
- Results categorized in real-time sections with instant jump navigation.

### 3.7 Ambient Bubble Particle Physics (`ambient.js`)
Creates an atmospheric, organic feeling of looking into an illuminated aquaculture pond:
- Throttled particle count based on screen viewport:
  - Small phones ($< 200,000\text{ px}^2$): $8\text{ bubbles}$.
  - Large phones ($< 500,000\text{ px}^2$): $12\text{ bubbles}$.
  - Desktop / Tablets: $16\text{ bubbles}$.
- Bubble Physics:
  - Radii: $1.0\text{px} \text{ to } 2.6\text{px}$.
  - Vertical drift: Gentle upward velocity $v_y \approx -0.15\text{ px/frame}$.
  - Horizontal sway: Sinusoidal wobble phase $w = \sin(t) \times 0.15$.
  - Colors: Subtle cyan (`#38bdf8`), ocean teal (`#00e5f5`), and deep teal.
  - Opacity: Barely-visible translucent alpha ($0.05 \text{ to } 0.18$).
- Touch / Pointer Ripples:
  - Tapping screen spawns expanding circular wave ripples: $r_{\text{max}} = 60\text{px} - 110\text{px}$, fading out smoothly over $40\text{ frames}$.
- Accessibility: Automatically disables animation if user prefers reduced motion (`window.matchMedia('(prefers-reduced-motion: reduce)')`).

### 3.8 Shared Universal Modals
1. **Universal Calendar Date Picker (`#appDatePickerModal`)**:
   - Custom touch-friendly calendar sheet with large date numbers and month swipe controls, designed for rural users whose devices lack reliable native HTML5 pickers.
2. **Generic Confirmation Dialog (`#confirmModal`)**:
   - Standard reusable prompt: Title (`#confirmModalTitle`), Message (`#confirmModalMsg`), Cancel button, and Destructive Confirm button.
3. **Toast Dispatcher (`showToast`)**:
   - Floating notification cards appearing at top right:
     - Success (`#10b981`): Icon `✓`
     - Error (`#f43f5e`): Icon `✕`
     - Warning (`#fbbf24`): Icon `⚠️`
     - Info (`#00e5f5`): Icon `ℹ️`
   - Auto-dismisses after $3,500\text{ ms}$ with slide-up exit animation.

### 3.9 Service Worker & PWA Offline Engine (`sw.js`, `manifest.json`)
- **PWA Manifest (`manifest.json`)**:
  - Name: *"AquaLog — Shrimp Feed Manager"*.
  - Short Name: *"AquaLog"*.
  - Display: `standalone` (full-screen mobile app experience without browser chrome).
  - Background Color: `#0d1117`.
  - Theme Color: `#0d1117`.
- **Caching Strategy (`sw.js`)**:
  - `APP_SHELL` pre-caches HTML, CSS, JS, Chart.js, and font stylesheets.
  - Same-origin assets: **Cache-First** strategy.
  - API / External calls: **Network-First** strategy with graceful offline fallback.
  - Navigation requests fallback to cached `index.html` when offline.

---

## 4. Google Stitch Re-Creation Recommendations

1. **Modern Layout Architecture**:
   - Structure the application with a master Next.js `layout.tsx` holding `<TopStatusBar />`, `<AmbientCanvas />`, `<BottomDock />`, and `<ToastContainer />`.
2. **Framer Motion Page Transitions**:
   - Wrap screen navigation in an `<AnimatePresence mode="wait">` with subtle vertical opacity slide (`initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }}`).
3. **Radix UI Dialog & Sheet Primitives**:
   - Recreate all 12 modals using Radix UI (`@radix-ui/react-dialog`) for full accessibility, focus trapping, Escape-to-close, and smooth backdrop blur overlays.
