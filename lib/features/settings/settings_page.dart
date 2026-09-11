import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/legacy_import_service.dart';
import '../../core/services/demo_data_service.dart';
import '../../app/theme/color_schemes.dart';
import '../../core/config/app_config.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isLoading = false;

  Future<void> _handleExportBackup(BuildContext context, AppDatabase db) async {
    setState(() => _isLoading = true);
    try {
      final backupJson = await BackupService(db).exportToJson();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.download_done_rounded, color: AquaColors.statusOptimal, size: 36),
          title: const Text('Backup Snapshot Ready'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete atomic JSON backup snapshot generated (${(backupJson.length / 1024).toStringAsFixed(1)} KB).',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Includes all ponds, batches, feed records, samplings, and inventory data.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: backupJson));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backup JSON copied to clipboard!'),
                    backgroundColor: AquaColors.statusOptimal,
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AquaColors.statusAlert),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestoreBackup(BuildContext context, AppDatabase db) async {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from JSON Backup'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste the AquaLog JSON backup contents below. Restoring will replace existing local data.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{\n  "schemaVersion": 1,\n  "data": { ... }\n}',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AquaColors.statusAlert),
            onPressed: () async {
              final jsonStr = textController.text.trim();
              if (jsonStr.isEmpty) return;
              Navigator.pop(ctx);

              setState(() => _isLoading = true);
              try {
                final summary = await BackupService(db).restoreFromJson(jsonStr);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Restored successfully: ${summary['ponds']} ponds, ${summary['batches']} batches, ${summary['feedRecords']} feed records.',
                      ),
                      backgroundColor: AquaColors.statusOptimal,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Restore failed: $e'),
                      backgroundColor: AquaColors.statusAlert,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Validate & Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLegacyImport(BuildContext context, AppDatabase db) async {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Legacy Web App Data'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste the export JSON from your previous web application (al_ponds, al_records, etc.).',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{\n  "al_ponds": [...],\n  "al_records": [...]\n}',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final jsonStr = textController.text.trim();
              if (jsonStr.isEmpty) return;
              Navigator.pop(ctx);

              setState(() => _isLoading = true);
              try {
                final result = await LegacyImportService(db).importLegacyJson(jsonStr);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Imported: ${result.pondsImported} ponds, ${result.batchesImported} batches, ${result.recordsImported} records. Errors: ${result.errorsCount}',
                      ),
                      backgroundColor: result.errorsCount == 0 ? AquaColors.statusOptimal : AquaColors.statusWarning,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Legacy import failed: $e'),
                      backgroundColor: AquaColors.statusAlert,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Import Legacy Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLoadDemoData(BuildContext context, AppDatabase db) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF006876), size: 36),
        title: const Text('Load Demo Farm Data?'),
        content: const Text(
          'This will populate comprehensive commercial aquaculture data: 2 Farm Sites, 6 Ponds (including 1 Archived Eco-Fallow Pond), 3 Active Batches with diverse DOCs (DOC 73, DOC 46, DOC 19), 2 Completed Batches with full harvest & revenue records, 14 days of multi-feed sessions, complete sampling curves, and inventory supplies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load Demo Farm'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await DemoDataService(db).loadDemoData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demo farm data loaded successfully!'),
              backgroundColor: AquaColors.statusOptimal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading demo data: $e'), backgroundColor: AquaColors.statusAlert),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFactoryReset(BuildContext context, AppDatabase db) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AquaColors.statusAlert, size: 36),
        title: const Text('Wipe All Farm Data?'),
        content: const Text(
          'WARNING: This will permanently delete all ponds, batches, feed records, inventory items, and financial records from this device. This action cannot be undone unless you have a backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AquaColors.statusAlert),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Wipe Everything'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await db.transaction(() async {
          await db.delete(db.inventoryTransactions).go();
          await db.delete(db.treatmentRecords).go();
          await db.delete(db.machineRuns).go();
          await db.delete(db.expenses).go();
          await db.delete(db.revenues).go();
          await db.delete(db.marketPrices).go();
          await db.delete(db.feedRecords).go();
          await db.delete(db.samplingEntries).go();
          await db.delete(db.hapaChecks).go();
          await db.delete(db.growthRecords).go();
          await db.delete(db.biomassSnapshots).go();
          await db.delete(db.inventoryItems).go();
          await db.delete(db.batches).go();
          await db.delete(db.ponds).go();
          await db.delete(db.farmSites).go();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All farm data has been wiped.'),
              backgroundColor: AquaColors.statusAlert,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reset failed: $e'), backgroundColor: AquaColors.statusAlert),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Page Header
              Text(
                settings.tr('settings_title'),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                settings.tr('settings_sub'),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // 1. Language & Display
              _buildSectionCard(
                theme,
                title: 'Language & Display / भाषा और डिस्प्ले',
                icon: Icons.translate_rounded,
                children: [
                  // Language Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Language / भाषा', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          Text('English or हिंदी (Devanagari)', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'en', label: Text('English')),
                          ButtonSegment(value: 'hi', label: Text('हिंदी')),
                        ],
                        selected: {settings.language},
                        onSelectionChanged: (val) {
                          settingsNotifier.setLanguage(val.first);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Outdoor Sunlight Mode
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.wb_sunny_rounded,
                      color: settings.outdoorMode ? const Color(0xFFE65100) : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(settings.tr('outdoor_mode'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(settings.tr('outdoor_mode_desc'), style: const TextStyle(fontSize: 12)),
                    value: settings.outdoorMode,
                    onChanged: (val) {
                      settingsNotifier.setOutdoorMode(val);
                    },
                  ),
                  const Divider(height: 24),

                  // Theme Mode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('System, Light, or Dark', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 16)),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 16)),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined, size: 16)),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (val) {
                          settingsNotifier.setThemeMode(val.first);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Font Scale
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Text Sizing', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            settings.fontScale == 1.0 ? 'Default (1.0x)' : '${settings.fontScale}x magnification',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 1.0, label: Text('Normal')),
                          ButtonSegment(value: 1.15, label: Text('Large')),
                          ButtonSegment(value: 1.3, label: Text('X-Large')),
                        ],
                        selected: {settings.fontScale},
                        onSelectionChanged: (val) {
                          settingsNotifier.setFontScale(val.first);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Data Portability & Disaster Recovery
              _buildSectionCard(
                theme,
                title: 'Data Portability & Disaster Recovery',
                icon: Icons.shield_rounded,
                children: [
                  const Text(
                    'AquaLog operates 100% locally on your device with SQLite persistence. Create regular atomic backup snapshots to safeguard your farm data.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export JSON Backup'),
                        onPressed: () => _handleExportBackup(context, db),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Restore from Backup'),
                        onPressed: () => _handleRestoreBackup(context, db),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_shared_outlined),
                        label: const Text('Import Legacy Web App'),
                        onPressed: () => _handleLegacyImport(context, db),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: const Text('Load Demo Farm Data'),
                        onPressed: () => _handleLoadDemoData(context, db),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever_rounded, color: AquaColors.statusAlert),
                    title: const Text('Factory Reset & Clear All Data', style: TextStyle(color: AquaColors.statusAlert, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Erase all ponds, batches, feed logs, and transactions from this device.', style: TextStyle(fontSize: 12)),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AquaColors.statusAlert),
                      onPressed: () => _handleFactoryReset(context, db),
                      child: const Text('Wipe Data'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. System & Engine Diagnostics
              _buildSectionCard(
                theme,
                title: 'System & Engine Architecture',
                icon: Icons.info_outline_rounded,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        height: 110,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDiagRow(theme, 'Application', '${AppConfig.appName} v${AppConfig.appVersion} (Build ${AppConfig.buildNumber})'),
                  _buildDiagRow(theme, 'Version Release', 'v${AppConfig.appVersion} · Release Channel'),
                  _buildDiagRow(theme, 'Persistence Engine', 'Drift 2.24 + SQLite (Local Relational Database)'),
                  _buildDiagRow(theme, 'Network Requirement', '100% Offline Capable · Zero Cloud Lag'),
                  _buildDiagRow(theme, 'Design System', 'Material 3 (Aquatic Teal Scheme, 48dp Touch Targets)'),
                  _buildDiagRow(theme, 'Calculation Engines', '15 Pure Dart Biological & Economic Units Verified'),
                ],
              ),
              const SizedBox(height: 16),

              // 5. Commemorative Tribute Plaque
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6B4E07),
                      Color(0xFFAA771C),
                      Color(0xFFF7E690),
                      Color(0xFFDAA520),
                      Color(0xFF9E7216),
                      Color(0xFF5A3E05),
                    ],
                    stops: [0.0, 0.25, 0.50, 0.72, 0.88, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A3506).withOpacity(0.35),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFFF0A6),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF5A3E05).withOpacity(0.2),
                        border: Border.all(color: const Color(0xFFFFF5B8).withOpacity(0.6)),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF3B2902),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'COMMEMORATIVE TRIBUTE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF382502).withOpacity(0.85),
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 1,
                            color: Color(0xFFFFF8D6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Engraved Golden Lettering for 07-09-2026
                    Text(
                      AppConfig.creationDate,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        fontFamily: 'serif',
                        color: Color(0xFF261800),
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1.2),
                            blurRadius: 1,
                            color: Color(0xFFFFF7C2),
                          ),
                          Shadow(
                            offset: Offset(0, -1.2),
                            blurRadius: 1.5,
                            color: Color(0x66000000),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'In Everlasting Memory & Deep Gratitude',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF3A2703).withOpacity(0.8),
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 1,
                            color: Color(0xFFFFF8D6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Small heart at middle bottom area
                    const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Color(0xFF422802),
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 1,
                          color: Color(0xFFFFF8D6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDiagRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
