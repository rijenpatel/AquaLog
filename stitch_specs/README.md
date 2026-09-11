# AquaLog — Google Stitch Re-Creation Blueprint & Audit Suite

> **Comprehensive System Audit & Screen-by-Screen Technical Specifications for Google Stitch**  
> *Target Architecture: Next.js 15 / React 19 / TypeScript / Tailwind CSS v4 / TanStack Query / Zustand / PWA*

---

## 📌 Overview

This directory contains the exhaustive technical audit and re-creation specifications for **AquaLog** (Shrimp Feed Manager & Aquaculture Operating System). Every screen, component, mathematical model, state transition, and business rule has been reverse-engineered and documented in microscopic detail.

These files serve as direct context and prompt blueprints for **Google Stitch** (or any modern generative UI agent / senior engineering team) to recreate AquaLog as an ultra-premium, production-grade, offline-first aquaculture management platform.

---

## 🗂 Specification Index

| File | Screen / Scope | Primary Features & Logic Audited |
| :--- | :--- | :--- |
| [**COMPLETE_BUSINESS_LOGIC_COMPENDIUM.md**](./COMPLETE_BUSINESS_LOGIC_COMPENDIUM.md) | **End-to-End Master Logic Compendium** | **Complete end-to-end logic specification**: 15 chapters detailing every single calculation, formula, state machine, boot lifecycle, background periodic interval, weather engine, FCR tracking, and inventory transaction. |
| [**00_MASTER_ARCHITECTURE_AND_SYSTEM_AUDIT.md**](./00_MASTER_ARCHITECTURE_AND_SYSTEM_AUDIT.md) | **System Architecture** | Domain model, 18+ LocalStorage schemas, offline-first sync queue, weather intelligence, math algorithms, design tokens, Google Stitch target architecture. |
| [**01_SCREEN_DASHBOARD_AND_OVERVIEW.md**](./01_SCREEN_DASHBOARD_AND_OVERVIEW.md) | **Overview / Dashboard** (`pageDashboard`) | Farm vs Batch dual context, 7-day trend canvas, operations & sampling alerts, Today's feed timeline, Pond health score (0-100), AI insights, harvest predictor, weather feed engine. |
| [**02_SCREEN_FEED_LOGGING_AND_TRAY_MANAGEMENT.md**](./02_SCREEN_FEED_LOGGING_AND_TRAY_MANAGEMENT.md) | **Log Feed** (`pageLog` / Quick FAB) | Time slot scheduling (7AM, 11AM, 4PM, 7PM), multi-feed pellet grid, check-tray scoring (0%-100%), auto-adjust recommendation loop, medicine co-feeding, auto-inventory deduction, webhook sync. |
| [**03_SCREEN_MANAGE_PONDS_BATCHES_AND_SITES.md**](./03_SCREEN_MANAGE_PONDS_BATCHES_AND_SITES.md) | **Manage Ponds & Batches** (`pageManage`) | Multi-site hierarchy, pond cards carousel, 5 lifecycle stages, stocking & PL seed logic, cast net sampling, ABW calculation, hapa survival check, harvest completion & P/L calculation. |
| [**04_SCREEN_INVENTORY_HUB.md**](./04_SCREEN_INVENTORY_HUB.md) | **Inventory Hub** (`pageInventory`) | 3-pillar stock overview (Feed, Medicine, Fuel), monthly purchase vs burn rates, low-stock threshold engine, quick purchase modals with auto-finance posting. |
| [**05_SCREEN_FEED_DETAIL_INVENTORY.md**](./05_SCREEN_FEED_DETAIL_INVENTORY.md) | **Feed Stock Detail** (`pageFeedDetail`) | Pellet size SKU breakdown (0.8mm-2.5mm), bags vs net kg, transaction ledger, daily burn rate & days of feed remaining forecast, stock adjustment. |
| [**06_SCREEN_MEDICINE_AND_CHEMICAL_DETAIL.md**](./06_SCREEN_MEDICINE_AND_CHEMICAL_DETAIL.md) | **Medicine & Treatments** (`pageMedicineDetail`) | Chemical classification (probiotics, minerals, disinfectants), water volume dosage calculator ($V = Area \times Depth$), 30-day expiry tracker, pond application logs. |
| [**07_SCREEN_FUEL_AND_ENERGY_DETAIL.md**](./07_SCREEN_FUEL_AND_ENERGY_DETAIL.md) | **Fuel & Energy Detail** (`pageFuelDetail`) | Diesel/petrol stock levels, generator & aerator run-hour loggers, $L/hr$ consumption rate, electricity kWh tracking, energy cost allocation per crop. |
| [**08_SCREEN_INVENTORY_REPORTS_AND_LEDGER.md**](./08_SCREEN_INVENTORY_REPORTS_AND_LEDGER.md) | **Inventory Reports** (`pageInventoryReports`) | 6 report types, double-entry stock ledger, stock turnover ratio ($STR$), feed wastage %, supplier cost inflation trend, interactive filtering & CSV export. |
| [**09_SCREEN_FINANCE_AND_PROFITABILITY.md**](./09_SCREEN_FINANCE_AND_PROFITABILITY.md) | **Finance & Profit** (`pageFinance`) | Cost-revenue-profit KPIs, 7 expense categories, harvest revenue tracking, Mandi market shrimp price intelligence (30-100 count), break-even price calculator & profit simulator. |
| [**10_SCREEN_REPORTS_AND_DEEP_ANALYTICS.md**](./10_SCREEN_REPORTS_AND_DEEP_ANALYTICS.md) | **Reports & Analytics** (`pageReports`) | Daily/Weekly/Monthly/History tabs, Chart.js feed trajectory, ADG growth vs benchmark curve, period-by-period FCR evolution, meal time slot distribution, PDF export. |
| [**11_SCREEN_SETTINGS_BACKUP_AND_TOOLS.md**](./11_SCREEN_SETTINGS_BACKUP_AND_TOOLS.md) | **Settings & Tools** (`pageSettings`) | Bilingual English/Hindi toggle, high-contrast outdoor sunlight mode, full JSON atomic backup & restore, demo data generator, browser feed reminders, webhook sync configuration. |
| [**12_GLOBAL_SHELL_MODALS_AND_SERVICES.md**](./12_GLOBAL_SHELL_MODALS_AND_SERVICES.md) | **Global Shell & Services** | Splash animation, top live status bar, suspended 7-tab bottom dock with FAB, command palette (`Ctrl+K`), global search (`Ctrl+/`), ambient canvas bubbles (`ambient.js`), service worker PWA offline cache. |

---

## 🎯 Re-Creation Goals for Google Stitch

1. **Modern Component-Driven Architecture**: Replace monolithic 17,000-line DOM scripts with clean, type-safe, modular React 19 components with strict TypeScript types.
2. **Design Language & Visual Excellence**:
   - Elevated dark aquaculture theme with deep navy/charcoal glassmorphism (`#040914`, `#080f1e`).
   - Neon Teal (`#00e5f5`) and Cyan (`#38bdf8`) accents with vibrant glowing gradients.
   - Smooth 60fps micro-animations, spring transitions, and interactive floating particles.
3. **Rock-Solid State Management**:
   - Centralized Zustand store with offline persistence (IndexedDB / LocalStorage).
   - TanStack Query for optimistic updates and seamless asynchronous sync.
4. **Offline-First Resilience**:
   - Complete local offline operability for rural aquaculture farms with intermittent 4G/2G connectivity.
   - Background sync queue that automatically flushes to Supabase / Google Sheets when connectivity resumes.
5. **Accessibility & Usability**:
   - Full bilingual support (English & Hindi) with native Devanagari typography (`Noto Sans Devanagari`).
   - Sunlight High-Contrast Outdoor Mode for farmers standing by the pond in direct sunlight.
   - Large touch targets (minimum 48x48px) for wet, outdoor finger interaction.
