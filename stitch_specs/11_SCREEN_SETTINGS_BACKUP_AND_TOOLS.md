# 11 — Screen Specification: Settings, Localization & Data Management

> **Screen ID**: `pageSettings`  
> **Route / Navigation**: Bottom Nav "Settings" (`data-tab="settings"`) | Keyboard Shortcut `g` then `e`  
> **Target Component**: `<SettingsPage />`

---

## 1. Screen Objective & Mental Model

The **Settings & Configuration Screen** governs the application’s global operating parameters, display ergonomics, localized language rendering, automated reminder notifications, disaster recovery (backup/restore), and third-party webhook integrations.

Key user mental models addressed:
1. **Bilingual Rural Usability**: Seamless language switching between English and Hindi (हिंदी) with native Devanagari script typography.
2. **Outdoor Pond Ergonomics**: Sunlight High-Contrast Mode for farmers operating phones under harsh tropical sunlight on pond dykes.
3. **Disaster Recovery & Data Sovereignty**: The farm’s entire biological, feeding, and financial history must be exportable into an unencrypted, portable JSON file that can be restored on any device at any time.
4. **Developer & Trial Tools**: Generating realistic multi-pond demonstration data with a single tap for training and presentation.

---

## 2. Visual Hierarchy & Screen Structure

```
<SettingsPage>
  ├── <ScreenHeroHeader>
  │     ├── <Title> ("⚙️ Settings")
  │     ├── <HindiTitle> ("सेटिंग्स")
  │     └── <Subtitle> ("Preferences & Configuration · प्राथमिकताएं")
  │
  ├── <SectionHeader> (🌐 "Language & Display · भाषा")
  ├── <SettingsCard>
  │     ├── <LanguageRow>
  │     │     ├── <Label> ("Language · भाषा" · "App display language")
  │     │     └── <LanguageDropdown id="languageSelect"> (English | हिंदी)
  │     ├── <Divider />
  │     ├── <OutdoorModeRow>
  │     │     ├── <Label> ("Outdoor Mode · धूप मोड" · "High contrast for sunlight visibility")
  │     │     └── <ToggleSwitch id="outdoorModeToggle" />
  │     ├── <Divider />
  │     └── <TextSizeRow>
  │           ├── <Label> ("Text Size · अक्षर का आकार" · "Larger text for better readability")
  │           └── <FontSizeButtonsGroup>
  │                 ├── <SmallFontBtn id="fontSizeSmall"> ("A")
  │                 └── <LargeFontBtn id="fontSizeLarge"> ("A+")
  │
  ├── <SectionHeader> (💾 "Data Backup & Restore · बैकअप")
  ├── <SettingsCard>
  │     ├── <BackupDescription> ("Download all your data as a single JSON file. Keep it safe.")
  │     ├── <ExportButtonsRow>
  │     │     ├── <ExportJsonBtn id="aqExportJsonBtn"> ("📥 Export JSON Backup")
  │     │     └── <ExportCsvBtn id="aqExportCsvBtn"> ("📊 Export Feed CSV")
  │     ├── <Divider />
  │     ├── <RestoreSection>
  │     │     ├── <RestoreWarningLabel> ("Restore from Backup · Replaces all current data")
  │     │     ├── <HiddenFileInput id="aqImportFileInput" accept=".json" />
  │     │     ├── <RestoreButton id="aqImportBtn"> ("📤 Choose Backup File to Restore…")
  │     │     └── <RestoreStatusBox id="aqRestoreStatus" />
  │     └── <FactoryResetRow> (🗑 "Reset All Data" ──> triggers high-risk confirm modal)
  │
  ├── <SectionHeader> (🔔 "Notifications & Reminders · सूचना")
  ├── <SettingsCard>
  │     ├── <NotifRow FeedReminders> ("Feed Time Reminders · 7 AM, 11 AM, 4 PM, 7 PM")
  │     ├── <Divider />
  │     ├── <NotifRow LowStock> ("Low Stock Alerts · Warn when inventory runs low")
  │     ├── <Divider />
  │     ├── <NotifRow SamplingDue> ("Sampling Due Reminders · Remind when batch sampling due")
  │     ├── <Divider />
  │     ├── <TestNotificationBtn id="aqNotifTestBtn"> ("🔔 Send Test Notification")
  │     └── <BlockedPermissionNote id="aqNotifPermissionNote"> ("⚠️ Browser notifications blocked")
  │
  ├── <SectionHeader> (🛠 "Developer Tools")
  ├── <SettingsCard devMode>
  │     ├── <DevWarningBanner> ("⚠️ Developer tools are intended for testing only.")
  │     └── <LoadDemoDataBtn id="settingsLoadDemoBtn"> ("🚀 Load Demo Data")
  │
  └── <VersionFooter>
        ├── <AppName> ("🦐 AquaLog")
        └── <AppVersion> ("Shrimp Feed Intelligence · v2.1")
```

---

## 3. UI Specifications & Styling Tokens

- **Settings Card Surface (`.settings-card`)**:
  - Background: Deep navy glass (`rgba(255,255,255,0.03); border: 1px solid var(--border); border-radius: 18px; padding: 16px; margin: 0 16px 14px`).
- **Section Headers (`.settings-section-header`)**:
  - Icon font-size $1.1\text{rem}$, Title uppercase tracking $0.6\text{px}$, color `--teal: #00e5f5`.
- **Toggle Switches (`.settings-toggle`)**:
  - Track: $52\text{px} \times 28\text{px}$, border-radius $14\text{px}$, off-state `#334155`, on-state `--teal: #00e5f5`.
  - Thumb: $22\text{px} \times 22\text{px}$ white circle with spring physics translation (`transform: translateX(24px)`).
- **Developer Warning Box (`.settings-dev-warning`)**:
  - Background: `rgba(251,191,36,0.1)`, border `1px solid rgba(251,191,36,0.3)`, text `--amber: #fbbf24`.

---

## 4. Detailed Functional Logic & Algorithmic Rules

### 4.1 Bilingual Localization Engine (English & Hindi)
1. Supported Locales: `'en'` (English) and `'hi'` (Hindi).
2. Persisted Key: `localStorage.getItem('al_language') || 'en'`.
3. When `#languageSelect` is changed to `'hi'`:
   - Sets document attribute `lang="hi"`.
   - Enforces Hindi font family: `'Noto Sans Devanagari', sans-serif` on all text nodes.
   - Updates all bilingual labels across all screens:
     - Dashboard: *"नमस्ते किसान भाई!"*
     - Log Feed: *"खाना दर्ज करें"*
     - Manage: *"तालाब प्रबंधन"*
     - Inventory: *"सामग्री प्रबंधन"*
     - Finance: *"लाभ और लागत"*
     - Reports: *"रिपोर्ट और इतिहास"*

### 4.2 Sunlight High-Contrast Outdoor Mode
Pond dykes have zero shade. Direct sunlight washes out subtle glassmorphic UI.
1. When `#outdoorModeToggle` is checked:
   - Sets body class `outdoor-mode`.
   - Persists state: `al_outdoor_mode = 'true'`.
   - CSS Transformations:
     - `--bg`: Shifts from `#040914` to pure jet black `#000000`.
     - `--surface`: Shifts from translucent 3% white to opaque solid charcoal `#121826`.
     - Text colors: Shift from muted slate to $100\%$ high-contrast pure white `#ffffff`.
     - Borders: Boosted from $1\text{px}$ translucent to $2\text{px}$ solid white/teal.
     - Canvas ambient bubbles are paused to maximize readability and conserve battery.

### 4.3 Dynamic Font Size Scaling
- Button `#fontSizeSmall` (A): Standard base font size ($16\text{px}$).
- Button `#fontSizeLarge` (A+): Accessibility enlarged base font size ($18.5\text{px}$ with proportional $1.25\times$ rem scaling across all inputs, badges, and labels).

### 4.4 Full Atomic JSON Backup & Export Engine (`#aqExportJsonBtn`)
Serializes the entire farm operating system into an atomic JSON object:
```typescript
function exportFullBackup() {
  const backup = {
    version: "2.1",
    timestamp: new Date().toISOString(),
    appName: "AquaLog",
    data: {
      sites: JSON.parse(localStorage.getItem('al_sites') || '[]'),
      ponds: JSON.parse(localStorage.getItem('al_ponds') || '[]'),
      batches: JSON.parse(localStorage.getItem('al_batches') || '[]'),
      records: JSON.parse(localStorage.getItem('al_records') || '[]'),
      sampling: JSON.parse(localStorage.getItem('al_sampling') || '[]'),
      hapa: JSON.parse(localStorage.getItem('al_hapa') || '[]'),
      growth: JSON.parse(localStorage.getItem('al_growth') || '[]'),
      biomass: JSON.parse(localStorage.getItem('al_biomass') || '[]'),
      inventory: JSON.parse(localStorage.getItem('al_inventory') || '[]'),
      expenses: JSON.parse(localStorage.getItem('al_finance_expenses') || '[]'),
      revenue: JSON.parse(localStorage.getItem('al_finance_revenue') || '[]'),
      prices: JSON.parse(localStorage.getItem('al_finance_prices') || '[]'),
      thresholds: JSON.parse(localStorage.getItem('al_thresholds') || '{}'),
      settings: {
        language: localStorage.getItem('al_language') || 'en',
        outdoorMode: localStorage.getItem('al_outdoor_mode') || 'false',
        sheetsUrl: localStorage.getItem('al_sheets_url') || '',
        apiUrl: localStorage.getItem('al_api_url') || ''
      }
    }
  };

  const jsonStr = JSON.stringify(backup, null, 2);
  const blob = new Blob([jsonStr], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `AquaLog_Full_Backup_${todayStr()}.json`;
  link.click();
}
```

### 4.5 Restore Engine from Backup (`#aqImportBtn`)
1. User selects a `.json` file via `#aqImportFileInput`.
2. File is read via `FileReader.readAsText()`.
3. **Integrity Validation**:
   - Parses JSON safely inside `try/catch`.
   - Validates schema: Checks for existence of `data.ponds` and `data.records`.
   - If invalid format, renders error in `#aqRestoreStatus`: *"Invalid backup file format. Missing required data arrays."*
4. **Atomic Restoration**:
   - Prompts confirmation modal: *"Restore from Backup? This will replace all current data on this device. Cannot be undone."*
   - On confirm: Overwrites all 18+ keys in LocalStorage / IndexedDB.
   - Renders success status: *"✓ Restored successfully: X ponds, Y batches, Z feed records. Reloading..."*
   - Reloads application after $1.5\text{ seconds}$ to re-initialize all in-memory stores.

### 4.6 Demo Data Generator (`#settingsLoadDemoBtn`)
Generates an extensive, realistic aquaculture test environment:
- **Sites**: 1 farm site ("Coastal Estuary Site 1").
- **Ponds**: 5 commercial ponds (Pond 1 North to Pond 5 Research).
- **Completed Batches**: 4 historical crops with complete harvest metrics, FCR ($1.22 - 1.34$), survival ($88\% - 94\%$), and realized profits.
- **Active Batches**:
  - Pond 1: Batch #3 at DOC 72 (*L. vannamei*, 120k pcs, ABW $18.5\text{g}$).
  - Pond 2: Batch #2 at DOC 35 (*L. vannamei*, 100k pcs, ABW $6.2\text{g}$).
- **Feed Records**: 200+ realistic feed sessions with meal mixes and check-tray observations.
- **Sampling & Hapa**: Cast net samplings every 7 days establishing clean ADG growth curves.
- **Inventory**: 12 SKUs stocked across feeds, probiotics, minerals, and diesel fuel.
- **Finance**: Seed expenses, power bills, labor, and revenue transactions.

### 4.7 Notification Scheduling & Reminders
1. Uses Web Notifications API (`Notification.requestPermission()`).
2. If permission is denied, displays warning banner `#aqNotifPermissionNote`.
3. If permission granted:
   - Registers scheduled timers for feed times: `07:00`, `11:00`, `16:00`, `19:00`.
   - Checks daily for batches where $\text{DOC} \ge 7$ without sampling.
   - Checks daily for inventory items where `currentStock <= lowStockThreshold`.
   - Dispatches native system notification with shrimp icon `🦐` and audio chime.

---

## 5. Google Stitch Re-Creation Recommendations

1. **Cloud Sync Provider Connectors**: Add direct 1-tap Google Drive / Dropbox backup sync buttons alongside manual JSON download.
2. **Biometric App Lock**: Add a toggle in Settings for Fingerprint / FaceID authentication via WebAuthn to protect sensitive financial records on shared farm devices.
3. **Sound Effects Toggle**: Include a toggle for audible feedback upon successful feed logging (satisfying water drop chime).
